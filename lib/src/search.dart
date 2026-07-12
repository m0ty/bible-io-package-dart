import 'dart:math' as math;

import 'package:bible_io_references/bible_io_references.dart';
import 'package:characters/characters.dart';

import 'book.dart';
import 'json_value.dart';
import 'verse.dart';

/// Search mode for advanced text queries.
enum SearchMode {
  /// Match any of the tokenized terms.
  any,

  /// Match all of the tokenized terms.
  all,

  /// Match the exact phrase.
  exact,
}

const Object _notProvided = Object();

/// Options controlling advanced Bible search behavior.
///
/// Canonical Unicode normalization is enabled by default so canonically
/// equivalent text, such as NFC `é` and NFD `e` + combining acute, compares
/// consistently. Diacritics remain significant unless [ignoreDiacritics] is
/// enabled explicitly.
class SearchOptions {
  final SearchMode mode;
  final bool caseSensitive;
  final bool wholeWords;
  final int? maxResults;
  final int offset;
  final BibleBookEnum? book;
  final int? chapter;
  final int? verse;
  final bool normalizeUnicode;
  final bool ignoreDiacritics;

  const SearchOptions({
    this.mode = SearchMode.exact,
    this.caseSensitive = false,
    this.wholeWords = false,
    this.maxResults,
    this.offset = 0,
    this.book,
    this.chapter,
    this.verse,
    this.normalizeUnicode = true,
    this.ignoreDiacritics = false,
  })  : assert(maxResults == null || maxResults >= 0),
        assert(offset >= 0),
        assert(chapter == null || chapter > 0),
        assert(verse == null || verse > 0);

  /// Construct options with runtime validation in every build mode.
  factory SearchOptions.checked({
    SearchMode mode = SearchMode.exact,
    bool caseSensitive = false,
    bool wholeWords = false,
    int? maxResults,
    int offset = 0,
    BibleBookEnum? book,
    int? chapter,
    int? verse,
    bool normalizeUnicode = true,
    bool ignoreDiacritics = false,
  }) {
    _validateSearchOptionValues(
      maxResults: maxResults,
      offset: offset,
      chapter: chapter,
      verse: verse,
    );
    return SearchOptions(
      mode: mode,
      caseSensitive: caseSensitive,
      wholeWords: wholeWords,
      maxResults: maxResults,
      offset: offset,
      book: book,
      chapter: chapter,
      verse: verse,
      normalizeUnicode: normalizeUnicode,
      ignoreDiacritics: ignoreDiacritics,
    ).validate();
  }

  /// Validate options before executing a search.
  SearchOptions validate() {
    _validateSearchOptionValues(
      maxResults: maxResults,
      offset: offset,
      chapter: chapter,
      verse: verse,
    );
    return this;
  }

  /// Return a copy with the supplied fields replaced.
  ///
  /// Passing `null` explicitly clears nullable filters and limits. Omitting a
  /// parameter preserves its current value.
  SearchOptions copyWith({
    SearchMode? mode,
    bool? caseSensitive,
    bool? wholeWords,
    Object? maxResults = _notProvided,
    int? offset,
    Object? book = _notProvided,
    Object? chapter = _notProvided,
    Object? verse = _notProvided,
    bool? normalizeUnicode,
    bool? ignoreDiacritics,
  }) {
    return SearchOptions.checked(
      mode: mode ?? this.mode,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      wholeWords: wholeWords ?? this.wholeWords,
      maxResults: _nullableCopy<int>(maxResults, this.maxResults, 'maxResults'),
      offset: offset ?? this.offset,
      book: _nullableCopy<BibleBookEnum>(book, this.book, 'book'),
      chapter: _nullableCopy<int>(chapter, this.chapter, 'chapter'),
      verse: _nullableCopy<int>(verse, this.verse, 'verse'),
      normalizeUnicode: normalizeUnicode ?? this.normalizeUnicode,
      ignoreDiacritics: ignoreDiacritics ?? this.ignoreDiacritics,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SearchOptions &&
            other.mode == mode &&
            other.caseSensitive == caseSensitive &&
            other.wholeWords == wholeWords &&
            other.maxResults == maxResults &&
            other.offset == offset &&
            other.book == book &&
            other.chapter == chapter &&
            other.verse == verse &&
            other.normalizeUnicode == normalizeUnicode &&
            other.ignoreDiacritics == ignoreDiacritics;
  }

  @override
  int get hashCode => Object.hash(
        mode,
        caseSensitive,
        wholeWords,
        maxResults,
        offset,
        book,
        chapter,
        verse,
        normalizeUnicode,
        ignoreDiacritics,
      );

  @override
  String toString() {
    return 'SearchOptions('
        'mode: $mode, '
        'caseSensitive: $caseSensitive, '
        'wholeWords: $wholeWords, '
        'maxResults: $maxResults, '
        'offset: $offset, '
        'book: $book, '
        'chapter: $chapter, '
        'verse: $verse, '
        'normalizeUnicode: $normalizeUnicode, '
        'ignoreDiacritics: $ignoreDiacritics)';
  }
}

void _validateSearchOptionValues({
  required int? maxResults,
  required int offset,
  required int? chapter,
  required int? verse,
}) {
  if (maxResults != null && maxResults < 0) {
    throw ArgumentError.value(
      maxResults,
      'maxResults',
      'must be null or non-negative',
    );
  }
  if (offset < 0) {
    throw ArgumentError.value(offset, 'offset', 'must be non-negative');
  }
  if (chapter != null && chapter < 1) {
    throw ArgumentError.value(chapter, 'chapter', 'must be positive');
  }
  if (verse != null && verse < 1) {
    throw ArgumentError.value(verse, 'verse', 'must be positive');
  }
}

T? _nullableCopy<T>(Object? replacement, T? current, String parameterName) {
  if (identical(replacement, _notProvided)) {
    return current;
  }
  if (replacement == null || replacement is T) {
    return replacement as T?;
  }
  throw ArgumentError.value(
    replacement,
    parameterName,
    'must be ${T.toString()} or null',
  );
}

/// UTF-16 code-unit range with an inclusive start and exclusive end.
class TextRange {
  final int start;
  final int end;

  factory TextRange({required int start, required int end}) {
    return TextRange.checked(start: start, end: end);
  }

  /// Construct a range with runtime validation in every build mode.
  factory TextRange.checked({required int start, required int end}) {
    if (start < 0) {
      throw ArgumentError.value(start, 'start', 'must be non-negative');
    }
    if (end < start) {
      throw ArgumentError.value(end, 'end', 'must not be before start');
    }
    return TextRange._(start, end);
  }

  const TextRange._(this.start, this.end);

  int get length => end - start;

  bool contains(int offset) => offset >= start && offset < end;

  @override
  String toString() => 'TextRange($start, $end)';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TextRange && other.start == start && other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

/// Display-ready metadata for one matched verse.
///
/// [matchRanges] are offsets in [Verse.text]. [snippetMatchRanges] are the
/// corresponding clipped offsets in [snippet], which is always an exact slice
/// of the verse from [snippetStart] (inclusive) to [snippetEnd] (exclusive).
/// UIs can use [hasLeadingOmission] and [hasTrailingOmission] to decorate a
/// cropped snippet without invalidating its offsets.
class SearchHit {
  final Verse verse;
  final Book book;
  final String reference;
  final List<TextRange> matchRanges;
  final String snippet;
  final int snippetStart;
  final int snippetEnd;
  final List<TextRange> snippetMatchRanges;

  factory SearchHit({
    required Verse verse,
    required Book book,
    String? reference,
    List<TextRange> matchRanges = const [],
    String? snippet,
    int? snippetStart,
    int? snippetEnd,
  }) {
    _validateBookContainsVerse(book, verse);
    final immutableRanges = List<TextRange>.unmodifiable(matchRanges);
    _validateMatchRanges(immutableRanges, verse.text.length);

    late final int effectiveStart;
    late final int effectiveEnd;
    if (snippetStart == null && snippetEnd == null && snippet != null) {
      effectiveStart = verse.text.indexOf(snippet);
      if (effectiveStart == -1) {
        throw ArgumentError.value(
          snippet,
          'snippet',
          'must be an exact substring of the verse text',
        );
      }
      effectiveEnd = effectiveStart + snippet.length;
    } else {
      effectiveStart = snippetStart ?? 0;
      effectiveEnd = snippetEnd ??
          (snippet == null
              ? verse.text.length
              : effectiveStart + snippet.length);
    }

    _validateSnippetBounds(effectiveStart, effectiveEnd, verse.text.length);
    final expectedSnippet = verse.text.substring(effectiveStart, effectiveEnd);
    if (snippet != null && snippet != expectedSnippet) {
      throw ArgumentError.value(
        snippet,
        'snippet',
        'must equal verse.text.substring(snippetStart, snippetEnd)',
      );
    }

    final relativeRanges = <TextRange>[];
    for (final range in immutableRanges) {
      final clippedStart = math.max(range.start, effectiveStart);
      final clippedEnd = math.min(range.end, effectiveEnd);
      if (clippedStart < clippedEnd) {
        relativeRanges.add(
          TextRange(
            start: clippedStart - effectiveStart,
            end: clippedEnd - effectiveStart,
          ),
        );
      }
    }

    return SearchHit._(
      verse: verse,
      book: book,
      reference: reference ??
          '${book.name} ${verse.chapterNumber}:${verse.verseNumber}',
      matchRanges: immutableRanges,
      snippet: expectedSnippet,
      snippetStart: effectiveStart,
      snippetEnd: effectiveEnd,
      snippetMatchRanges: List<TextRange>.unmodifiable(relativeRanges),
    );
  }

  /// Create a hit with a grapheme-safe context window around the first match.
  factory SearchHit.withContext({
    required Verse verse,
    required Book book,
    String? reference,
    List<TextRange> matchRanges = const [],
    int maxSnippetLength = 160,
  }) {
    if (maxSnippetLength < 1) {
      throw ArgumentError.value(
        maxSnippetLength,
        'maxSnippetLength',
        'must be positive',
      );
    }
    final bounds = _contextBounds(verse.text, matchRanges, maxSnippetLength);
    return SearchHit(
      verse: verse,
      book: book,
      reference: reference,
      matchRanges: matchRanges,
      snippetStart: bounds.start,
      snippetEnd: bounds.end,
    );
  }

  const SearchHit._({
    required this.verse,
    required this.book,
    required this.reference,
    required this.matchRanges,
    required this.snippet,
    required this.snippetStart,
    required this.snippetEnd,
    required this.snippetMatchRanges,
  });

  bool get hasLeadingOmission => snippetStart > 0;
  bool get hasTrailingOmission => snippetEnd < verse.text.length;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SearchHit &&
            _sameVerseValue(other.verse, verse) &&
            other.book.bookEnum == book.bookEnum &&
            other.book.name == book.name &&
            jsonValueEquals(other.book.annotations, book.annotations) &&
            other.reference == reference &&
            _sameList(other.matchRanges, matchRanges) &&
            other.snippet == snippet &&
            other.snippetStart == snippetStart &&
            other.snippetEnd == snippetEnd &&
            _sameList(other.snippetMatchRanges, snippetMatchRanges);
  }

  @override
  int get hashCode => Object.hash(
        _verseValueHash(verse),
        book.bookEnum,
        book.name,
        jsonValueHash(book.annotations),
        reference,
        Object.hashAll(matchRanges),
        snippet,
        snippetStart,
        snippetEnd,
        Object.hashAll(snippetMatchRanges),
      );

  @override
  String toString() =>
      'SearchHit(reference: $reference, matches: $matchRanges)';
}

void _validateBookContainsVerse(Book book, Verse verse) {
  if (book.bookEnum != verse.book) {
    throw ArgumentError.value(
      book,
      'book',
      'must have the same book identifier as the matched verse',
    );
  }
  final containsVerse = book.chapters.any(
    (chapter) =>
        chapter.chapterNumber == verse.chapterNumber &&
        chapter.verses.any((candidate) => candidate == verse),
  );
  if (!containsVerse) {
    throw ArgumentError.value(
      book,
      'book',
      'must contain the matched verse value',
    );
  }
}

void _validateMatchRanges(List<TextRange> ranges, int textLength) {
  var previousEnd = 0;
  for (var index = 0; index < ranges.length; index++) {
    final range = ranges[index];
    if (range.start < 0 || range.end < range.start) {
      throw ArgumentError.value(
        ranges,
        'matchRanges',
        'must contain valid non-negative ranges',
      );
    }
    if (range.length == 0) {
      throw ArgumentError.value(
        ranges,
        'matchRanges',
        'must not contain empty ranges',
      );
    }
    if (range.end > textLength) {
      throw ArgumentError.value(
        ranges,
        'matchRanges',
        'must stay within the verse text',
      );
    }
    if (index > 0 && range.start < previousEnd) {
      throw ArgumentError.value(
        ranges,
        'matchRanges',
        'must be sorted and non-overlapping',
      );
    }
    previousEnd = range.end;
  }
}

void _validateSnippetBounds(int start, int end, int textLength) {
  if (start < 0 || start > textLength) {
    throw ArgumentError.value(
      start,
      'snippetStart',
      'must be within the verse text',
    );
  }
  if (end < start || end > textLength) {
    throw ArgumentError.value(
      end,
      'snippetEnd',
      'must follow snippetStart and stay within the verse text',
    );
  }
}

TextRange _contextBounds(String text, List<TextRange> ranges, int maxLength) {
  if (text.length <= maxLength) {
    return TextRange(start: 0, end: text.length);
  }

  final firstMatch = ranges.isEmpty ? null : ranges.first;
  final matchStart = firstMatch?.start ?? 0;
  final matchEnd = firstMatch?.end ?? 0;
  final desiredLength = math.max(maxLength, matchEnd - matchStart);
  var desiredStart = firstMatch == null
      ? 0
      : matchStart - ((desiredLength - (matchEnd - matchStart)) ~/ 2);
  desiredStart = desiredStart.clamp(
    0,
    math.max(0, text.length - desiredLength),
  );
  final desiredEnd = math.min(text.length, desiredStart + desiredLength);

  final boundaries = <int>[0];
  var offset = 0;
  for (final grapheme in text.characters) {
    offset += grapheme.length;
    boundaries.add(offset);
  }

  var safeStart = 0;
  var safeEnd = text.length;
  for (final boundary in boundaries) {
    if (boundary <= desiredStart) {
      safeStart = boundary;
    }
    if (boundary >= desiredEnd) {
      safeEnd = boundary;
      break;
    }
  }
  return TextRange(start: safeStart, end: safeEnd);
}

/// Search results with matched verses and display metadata.
class SearchResults {
  final String query;
  final List<Verse> verses;
  final List<SearchHit> hits;

  /// Zero-based result offset represented by this page.
  final int offset;

  /// Requested page size, or `null` when results were not limited.
  final int? limit;

  /// Total matching verses when it was computed by the search implementation.
  final int? totalCount;

  /// Whether at least one result exists after this page.
  final bool hasMore;

  /// Compatibility constructor for callers that only have verses.
  ///
  /// Prefer [SearchResults.fromHits] when match metadata is available.
  SearchResults(
    this.query,
    List<Verse> verses, {
    List<SearchHit>? hits,
    this.offset = 0,
    this.limit,
    this.totalCount,
    bool? hasMore,
  })  : verses = List<Verse>.unmodifiable(verses),
        hits = List<SearchHit>.unmodifiable(hits ?? const []),
        hasMore = _resolveHasMore(
          offset: offset,
          count: verses.length,
          totalCount: totalCount,
          supplied: hasMore,
        ) {
    _validatePagination(
      offset: offset,
      limit: limit,
      count: this.verses.length,
      totalCount: totalCount,
      hasMore: this.hasMore,
    );
    _validateUniqueVerses(this.verses);
    if (hits != null &&
        (hits.length != this.verses.length ||
            !_sameVerseValues(this.verses, hits.map((hit) => hit.verse)))) {
      throw ArgumentError.value(
        hits,
        'hits',
        'must correspond to verses in the same order',
      );
    }
  }

  SearchResults.fromHits(
    String query,
    List<SearchHit> hits, {
    int offset = 0,
    int? limit,
    int? totalCount,
    bool? hasMore,
  }) : this(
          query,
          hits.map((hit) => hit.verse).toList(growable: false),
          hits: hits,
          offset: offset,
          limit: limit,
          totalCount: totalCount,
          hasMore: hasMore,
        );

  int get count => verses.length;

  bool get isEmpty => verses.isEmpty;
  bool get isNotEmpty => verses.isNotEmpty;
  bool get hasPrevious => offset > 0 && (totalCount == null || totalCount! > 0);

  /// Offset for the next page, or `null` when no non-empty next page is known.
  int? get nextOffset => hasMore && count > 0 ? offset + count : null;

  /// Group results by book.
  Map<BibleBookEnum, List<Verse>> get byBook {
    final grouped = <BibleBookEnum, List<Verse>>{};
    for (final verse in verses) {
      grouped.putIfAbsent(verse.book, () => []).add(verse);
    }
    return Map.unmodifiable({
      for (final entry in grouped.entries)
        entry.key: List<Verse>.unmodifiable(entry.value),
    });
  }

  /// Group results by chapter.
  Map<String, List<Verse>> get byChapter {
    final grouped = <String, List<Verse>>{};
    for (final verse in verses) {
      final key = '${verse.book.fullName} ${verse.chapterNumber}';
      grouped.putIfAbsent(key, () => []).add(verse);
    }
    return Map.unmodifiable({
      for (final entry in grouped.entries)
        entry.key: List<Verse>.unmodifiable(entry.value),
    });
  }

  /// Group results by stable, language-neutral chapter identity.
  Map<(BibleBookEnum, int), List<Verse>> get byChapterLocation {
    final grouped = <(BibleBookEnum, int), List<Verse>>{};
    for (final verse in verses) {
      final key = (verse.book, verse.chapterNumber);
      grouped.putIfAbsent(key, () => []).add(verse);
    }
    return Map.unmodifiable({
      for (final entry in grouped.entries)
        entry.key: List<Verse>.unmodifiable(entry.value),
    });
  }

  /// Group UI-ready hits by their loaded/localized chapter label.
  ///
  /// Results created by the compatibility constructor without [hits] fall
  /// back to canonical English book names.
  Map<String, List<Verse>> get byDisplayChapter {
    final names = {
      for (final hit in hits) hit.verse.book: hit.book.name,
    };
    final grouped = <String, List<Verse>>{};
    for (final verse in verses) {
      final name = names[verse.book] ?? verse.book.fullName;
      final key = '$name ${verse.chapterNumber}';
      grouped.putIfAbsent(key, () => []).add(verse);
    }
    return Map.unmodifiable({
      for (final entry in grouped.entries)
        entry.key: List<Verse>.unmodifiable(entry.value),
    });
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SearchResults &&
            other.query == query &&
            other.offset == offset &&
            other.limit == limit &&
            other.totalCount == totalCount &&
            other.hasMore == hasMore &&
            _sameVerseValues(other.verses, verses) &&
            _sameList(other.hits, hits);
  }

  @override
  int get hashCode => Object.hash(
        query,
        Object.hashAll(verses.map(_verseValueHash)),
        Object.hashAll(hits),
        offset,
        limit,
        totalCount,
        hasMore,
      );

  @override
  String toString() {
    return 'SearchResults('
        'query: "$query", '
        'count: $count, '
        'offset: $offset, '
        'hasMore: $hasMore)';
  }
}

bool _resolveHasMore({
  required int offset,
  required int count,
  required int? totalCount,
  required bool? supplied,
}) {
  return supplied ?? (totalCount != null && offset + count < totalCount);
}

void _validatePagination({
  required int offset,
  required int? limit,
  required int count,
  required int? totalCount,
  required bool hasMore,
}) {
  if (offset < 0) {
    throw ArgumentError.value(offset, 'offset', 'must be non-negative');
  }
  if (limit != null && limit < 0) {
    throw ArgumentError.value(limit, 'limit', 'must be null or non-negative');
  }
  if (limit != null && count > limit) {
    throw ArgumentError.value(
      count,
      'verses',
      'must not exceed the requested result limit',
    );
  }
  if (totalCount != null) {
    if (totalCount < 0 || totalCount < count) {
      throw ArgumentError.value(
        totalCount,
        'totalCount',
        'must be non-negative and at least the returned count',
      );
    }
    if (count > 0 && offset + count > totalCount) {
      throw ArgumentError.value(
        totalCount,
        'totalCount',
        'must include the non-empty page window',
      );
    }
    final expectedHasMore = offset + count < totalCount;
    if (hasMore != expectedHasMore) {
      throw ArgumentError.value(
        hasMore,
        'hasMore',
        'must agree with offset, count, and totalCount',
      );
    }
  }
}

void _validateUniqueVerses(List<Verse> verses) {
  final locations = <(BibleBookEnum, int, int)>{};
  for (final verse in verses) {
    final location = (verse.book, verse.chapterNumber, verse.verseNumber);
    if (!locations.add(location)) {
      throw ArgumentError.value(
        verses,
        'verses',
        'must not contain duplicate verse locations',
      );
    }
  }
}

bool _sameVerseValues(Iterable<Verse> first, Iterable<Verse> second) {
  final firstIterator = first.iterator;
  final secondIterator = second.iterator;
  while (firstIterator.moveNext()) {
    if (!secondIterator.moveNext() ||
        !_sameVerseValue(firstIterator.current, secondIterator.current)) {
      return false;
    }
  }
  return !secondIterator.moveNext();
}

bool _sameVerseValue(Verse first, Verse second) {
  return first == second;
}

int _verseValueHash(Verse verse) => verse.hashCode;

bool _sameList<T>(List<T> first, List<T> second) {
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}
