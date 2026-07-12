import 'dart:math' as math;

import 'package:characters/characters.dart';

import 'search.dart';
import 'text_normalization.dart';

export 'text_normalization.dart';

/// A normalized Unicode search token and its offsets in the original text.
class SearchTextToken {
  final String raw;
  final String normalized;
  final int start;
  final int end;

  const SearchTextToken({
    required this.raw,
    required this.normalized,
    required this.start,
    required this.end,
  });

  TextRange get range => TextRange(start: start, end: end);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SearchTextToken &&
            other.raw == raw &&
            other.normalized == normalized &&
            other.start == start &&
            other.end == end;
  }

  @override
  int get hashCode => Object.hash(raw, normalized, start, end);

  @override
  String toString() => 'SearchTextToken("$raw", $start, $end)';
}

/// Extract Unicode letter/mark/number tokens with original UTF-16 offsets.
List<SearchTextToken> tokenizeSearchTextWithRanges(
  String text, {
  bool caseSensitive = false,
  bool normalizeUnicode = true,
  bool ignoreDiacritics = false,
}) {
  final tokens = <SearchTextToken>[];
  for (final match in unicodeTermPattern.allMatches(text)) {
    final raw = match.group(0)!;
    final normalized = normalizeSearchText(
      raw,
      caseSensitive: caseSensitive,
      normalizeUnicode: normalizeUnicode,
      ignoreDiacritics: ignoreDiacritics,
    );
    if (normalized.isNotEmpty) {
      tokens.add(
        SearchTextToken(
          raw: raw,
          normalized: normalized,
          start: match.start,
          end: match.end,
        ),
      );
    }
  }
  return List<SearchTextToken>.unmodifiable(tokens);
}

/// Whether a normalized content token matches a normalized query token.
///
/// Scripts that commonly omit spaces (Han, Japanese kana, Thai, Lao, Khmer,
/// and Myanmar) use substring semantics unless [wholeWords] is requested.
bool matchesSearchToken(
  String contentToken,
  String queryToken, {
  bool wholeWords = false,
}) {
  if (contentToken == queryToken) {
    return true;
  }
  return !wholeWords &&
      usesUnspacedWordBoundaries(queryToken) &&
      contentToken.contains(queryToken);
}

/// Test a text query with the same normalization and token semantics as search.
bool matchesSearchText(String text, String query, SearchOptions options) {
  switch (options.mode) {
    case SearchMode.exact:
      if (!options.wholeWords) {
        return containsNormalizedText(
          text,
          query,
          caseSensitive: options.caseSensitive,
          normalizeUnicode: options.normalizeUnicode,
          ignoreDiacritics: options.ignoreDiacritics,
        );
      }
      return _containsTokenSequence(
        tokenizeSearchText(
          text,
          caseSensitive: options.caseSensitive,
          normalizeUnicode: options.normalizeUnicode,
          ignoreDiacritics: options.ignoreDiacritics,
        ),
        tokenizeSearchText(
          query,
          caseSensitive: options.caseSensitive,
          normalizeUnicode: options.normalizeUnicode,
          ignoreDiacritics: options.ignoreDiacritics,
        ),
      );
    case SearchMode.all:
    case SearchMode.any:
      final contentTokens = tokenizeSearchText(
        text,
        caseSensitive: options.caseSensitive,
        normalizeUnicode: options.normalizeUnicode,
        ignoreDiacritics: options.ignoreDiacritics,
      );
      final queryTokens = tokenizeSearchText(
        query,
        caseSensitive: options.caseSensitive,
        normalizeUnicode: options.normalizeUnicode,
        ignoreDiacritics: options.ignoreDiacritics,
      ).toSet();
      if (queryTokens.isEmpty) {
        return false;
      }
      bool tokenMatches(String queryToken) => contentTokens.any(
            (contentToken) => matchesSearchToken(
              contentToken,
              queryToken,
              wholeWords: options.wholeWords,
            ),
          );
      return options.mode == SearchMode.all
          ? queryTokens.every(tokenMatches)
          : queryTokens.any(tokenMatches);
  }
}

/// Whether [options] use the normalization profile of the retained index.
///
/// A case-sensitive, raw-Unicode, or diacritic-folded query must scan its
/// selected scope unless the caller maintains a separate matching index.
bool canUseDefaultSearchIndex(SearchOptions options) {
  return !options.caseSensitive &&
      options.normalizeUnicode &&
      !options.ignoreDiacritics;
}

bool _containsTokenSequence(List<String> tokens, List<String> sequence) {
  if (sequence.isEmpty || sequence.length > tokens.length) {
    return false;
  }
  for (var index = 0; index <= tokens.length - sequence.length; index++) {
    var matches = true;
    for (var sequenceIndex = 0;
        sequenceIndex < sequence.length;
        sequenceIndex++) {
      if (tokens[index + sequenceIndex] != sequence[sequenceIndex]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return true;
    }
  }
  return false;
}

/// Build exact and short n-gram keys for the case-insensitive search index.
///
/// N-grams are emitted only for scripts that commonly omit spaces. This keeps
/// an English-style index compact while allowing a query such as `创造` to
/// retrieve a verse tokenized as `神创造天地`.
Set<String> buildSearchIndexTerms(
  String text, {
  bool normalizeUnicode = true,
  bool ignoreDiacritics = false,
  int maxNGramLength = 3,
}) {
  if (maxNGramLength < 1) {
    throw ArgumentError.value(
      maxNGramLength,
      'maxNGramLength',
      'must be positive',
    );
  }
  final terms = <String>{};
  final tokens = tokenizeSearchText(
    text,
    normalizeUnicode: normalizeUnicode,
    ignoreDiacritics: ignoreDiacritics,
  );
  for (final token in tokens) {
    terms.add(token);
    if (!usesUnspacedWordBoundaries(token)) {
      continue;
    }
    final runes = token.runes.toList(growable: false);
    final largestGram = math.min(maxNGramLength, runes.length);
    for (var gramLength = 1; gramLength <= largestGram; gramLength++) {
      for (var start = 0; start <= runes.length - gramLength; start++) {
        terms.add(String.fromCharCodes(runes, start, start + gramLength));
      }
    }
  }
  return terms;
}

/// Select a key guaranteed to exist in an index built by
/// [buildSearchIndexTerms] when an unspaced-script token contains [queryToken].
String searchIndexLookupKey(String queryToken, {int maxNGramLength = 3}) {
  if (maxNGramLength < 1) {
    throw ArgumentError.value(
      maxNGramLength,
      'maxNGramLength',
      'must be positive',
    );
  }
  if (!usesUnspacedWordBoundaries(queryToken)) {
    return queryToken;
  }
  final runes = queryToken.runes.toList(growable: false);
  if (runes.length <= maxNGramLength) {
    return queryToken;
  }
  return String.fromCharCodes(runes, 0, maxNGramLength);
}

/// Find normalized substring matches and map them to original UTF-16 offsets.
List<TextRange> findNormalizedSubstringRanges(
  String text,
  String query, {
  bool caseSensitive = false,
  bool normalizeUnicode = true,
  bool ignoreDiacritics = false,
}) {
  final normalizedQuery = normalizeSearchText(
    query,
    caseSensitive: caseSensitive,
    normalizeUnicode: normalizeUnicode,
    ignoreDiacritics: ignoreDiacritics,
  );
  if (normalizedQuery.isEmpty) {
    return const [];
  }
  final mapped = _normalizeWithSourceMapping(
    text,
    caseSensitive: caseSensitive,
    normalizeUnicode: normalizeUnicode,
    ignoreDiacritics: ignoreDiacritics,
  );
  final matches = <TextRange>[];
  var searchFrom = 0;
  while (searchFrom <= mapped.text.length - normalizedQuery.length) {
    final matchStart = mapped.text.indexOf(normalizedQuery, searchFrom);
    if (matchStart == -1) {
      break;
    }
    final matchEnd = matchStart + normalizedQuery.length;
    matches.add(
      TextRange(
        start: mapped.sourceStarts[matchStart],
        end: mapped.sourceEnds[matchEnd - 1],
      ),
    );
    searchFrom = matchEnd;
  }
  return List<TextRange>.unmodifiable(matches);
}

/// Build source ranges for a query using the package's search semantics.
List<TextRange> findSearchMatchRanges(
  String text,
  String query,
  SearchOptions options,
) {
  if (options.mode == SearchMode.exact && !options.wholeWords) {
    return findNormalizedSubstringRanges(
      text,
      query,
      caseSensitive: options.caseSensitive,
      normalizeUnicode: options.normalizeUnicode,
      ignoreDiacritics: options.ignoreDiacritics,
    );
  }

  final queryTokens = tokenizeSearchText(
    query,
    caseSensitive: options.caseSensitive,
    normalizeUnicode: options.normalizeUnicode,
    ignoreDiacritics: options.ignoreDiacritics,
  );
  if (queryTokens.isEmpty) {
    return const [];
  }
  final contentTokens = tokenizeSearchTextWithRanges(
    text,
    caseSensitive: options.caseSensitive,
    normalizeUnicode: options.normalizeUnicode,
    ignoreDiacritics: options.ignoreDiacritics,
  );

  if (options.mode == SearchMode.exact) {
    final ranges = <TextRange>[];
    for (var index = 0;
        index <= contentTokens.length - queryTokens.length;
        index++) {
      var matches = true;
      for (var queryIndex = 0; queryIndex < queryTokens.length; queryIndex++) {
        if (contentTokens[index + queryIndex].normalized !=
            queryTokens[queryIndex]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        ranges.add(
          TextRange(
            start: contentTokens[index].start,
            end: contentTokens[index + queryTokens.length - 1].end,
          ),
        );
      }
    }
    return List<TextRange>.unmodifiable(ranges);
  }

  final uniqueQueryTokens = queryTokens.toSet();
  final ranges = <TextRange>[];
  for (final contentToken in contentTokens) {
    for (final queryToken in uniqueQueryTokens) {
      if (contentToken.normalized == queryToken) {
        ranges.add(contentToken.range);
      } else if (!options.wholeWords &&
          usesUnspacedWordBoundaries(queryToken) &&
          contentToken.normalized.contains(queryToken)) {
        ranges.addAll(
          findNormalizedSubstringRanges(
            contentToken.raw,
            queryToken,
            caseSensitive: options.caseSensitive,
            normalizeUnicode: options.normalizeUnicode,
            ignoreDiacritics: options.ignoreDiacritics,
          ).map(
            (range) => TextRange(
              start: contentToken.start + range.start,
              end: contentToken.start + range.end,
            ),
          ),
        );
      }
    }
  }
  return _mergeRanges(ranges);
}

List<TextRange> _mergeRanges(List<TextRange> ranges) {
  if (ranges.isEmpty) {
    return const [];
  }
  ranges.sort((first, second) {
    final startComparison = first.start.compareTo(second.start);
    return startComparison != 0
        ? startComparison
        : first.end.compareTo(second.end);
  });
  final merged = <TextRange>[];
  var current = ranges.first;
  for (final next in ranges.skip(1)) {
    if (next.start <= current.end) {
      current = TextRange(
        start: current.start,
        end: math.max(current.end, next.end),
      );
    } else {
      merged.add(current);
      current = next;
    }
  }
  merged.add(current);
  return List<TextRange>.unmodifiable(merged);
}

_MappedSearchText _normalizeWithSourceMapping(
  String source, {
  required bool caseSensitive,
  required bool normalizeUnicode,
  required bool ignoreDiacritics,
}) {
  final normalized = StringBuffer();
  final starts = <int>[];
  final ends = <int>[];
  var sourceOffset = 0;
  for (final grapheme in source.characters) {
    final normalizedGrapheme = normalizeSearchText(
      grapheme,
      caseSensitive: caseSensitive,
      normalizeUnicode: normalizeUnicode,
      ignoreDiacritics: ignoreDiacritics,
    );
    normalized.write(normalizedGrapheme);
    for (var index = 0; index < normalizedGrapheme.length; index++) {
      starts.add(sourceOffset);
      ends.add(sourceOffset + grapheme.length);
    }
    sourceOffset += grapheme.length;
  }
  return _MappedSearchText(normalized.toString(), starts, ends);
}

class _MappedSearchText {
  final String text;
  final List<int> sourceStarts;
  final List<int> sourceEnds;

  const _MappedSearchText(this.text, this.sourceStarts, this.sourceEnds);
}

/// Whether two strings are within a bounded Unicode-scalar Levenshtein
/// distance.
bool isWithinLevenshteinDistance(String first, String second, int maxDistance) {
  return areRuneSequencesWithinLevenshteinDistance(
    first.runes.toList(growable: false),
    second.runes.toList(growable: false),
    maxDistance,
  );
}

/// Bounded two-row Levenshtein test with banding and row-level early exit.
///
/// This uses O(min(n, m)) memory and allocates no objects inside the DP cell
/// loop. Inputs are Unicode scalar values rather than UTF-16 code units.
bool areRuneSequencesWithinLevenshteinDistance(
  List<int> first,
  List<int> second,
  int maxDistance,
) {
  if (maxDistance < 0) {
    throw ArgumentError.value(
      maxDistance,
      'maxDistance',
      'must be non-negative',
    );
  }
  if ((first.length - second.length).abs() > maxDistance) {
    return false;
  }
  if (first.isEmpty) {
    return second.length <= maxDistance;
  }
  if (second.isEmpty) {
    return first.length <= maxDistance;
  }

  var rows = first;
  var columns = second;
  if (columns.length > rows.length) {
    final temporary = rows;
    rows = columns;
    columns = temporary;
  }

  final sentinel = maxDistance + 1;
  var previous = List<int>.filled(columns.length + 1, sentinel);
  var current = List<int>.filled(columns.length + 1, sentinel);
  for (var column = 0;
      column <= math.min(columns.length, maxDistance);
      column++) {
    previous[column] = column;
  }

  for (var row = 1; row <= rows.length; row++) {
    final firstColumn = math.max(1, row - maxDistance);
    final lastColumn = math.min(columns.length, row + maxDistance);
    current[0] = row <= maxDistance ? row : sentinel;
    if (firstColumn > 1) {
      current[firstColumn - 1] = sentinel;
    }
    if (lastColumn < columns.length) {
      current[lastColumn + 1] = sentinel;
    }

    var rowMinimum = sentinel;
    for (var column = firstColumn; column <= lastColumn; column++) {
      final substitutionCost = rows[row - 1] == columns[column - 1] ? 0 : 1;
      final deletion = previous[column] + 1;
      final insertion = current[column - 1] + 1;
      final substitution = previous[column - 1] + substitutionCost;
      var distance = deletion < insertion ? deletion : insertion;
      if (substitution < distance) {
        distance = substitution;
      }
      current[column] = distance;
      if (distance < rowMinimum) {
        rowMinimum = distance;
      }
    }
    if (rowMinimum > maxDistance) {
      return false;
    }

    final temporary = previous;
    previous = current;
    current = temporary;
  }
  return previous[columns.length] <= maxDistance;
}
