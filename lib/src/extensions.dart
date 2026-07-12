import 'package:bible_io_references/bible_io_references.dart';

import 'bible.dart';
import 'book.dart';
import 'chapter.dart';
import 'errors.dart';
import 'search.dart';
import 'text_search.dart';
import 'verse.dart';

/// Extension methods for more fluent Bible API usage.
extension BibleExtensions on Bible {
  /// Get a verse by reference string with null safety.
  Verse? verseOrNull(String reference) {
    try {
      return getVerseByRef(reference);
    } on BibleError {
      return null;
    } on ParseVerseRefError {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// Get verses by range with null safety.
  List<Verse>? versesOrNull(String reference) {
    try {
      return getVerseRangeByRef(reference);
    } on BibleError {
      return null;
    } on ParseVerseRefError {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// Fuzzy search with bounded Unicode-scalar Levenshtein distance.
  ///
  /// [SearchMode.all] requires every distinct query term to match a verse
  /// token, [SearchMode.any] requires one term, and [SearchMode.exact]
  /// requires the fuzzy terms to occur consecutively in query order.
  /// Canonically equivalent Unicode forms match by default. Diacritic folding
  /// is opt-in because marks can be meaningful in Hebrew and Arabic.
  SearchResults fuzzySearch(
    String query, {
    int maxDistance = 2,
    int maxResults = 50,
    int offset = 0,
    SearchMode mode = SearchMode.all,
    bool caseSensitive = false,
    bool normalizeUnicode = true,
    bool ignoreDiacritics = false,
  }) {
    if (maxDistance < 0) {
      throw ArgumentError.value(
        maxDistance,
        'maxDistance',
        'must be non-negative',
      );
    }
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'must be non-negative');
    }
    if (maxResults < 0) {
      throw ArgumentError.value(
        maxResults,
        'maxResults',
        'must be non-negative',
      );
    }

    final hits = <SearchHit>[];
    final queryTokens = tokenizeSearchText(
      query,
      caseSensitive: caseSensitive,
      normalizeUnicode: normalizeUnicode,
      ignoreDiacritics: ignoreDiacritics,
    )
        .map(
          (token) => _FuzzyTerm(token, token.runes.toList(growable: false)),
        )
        .toList(growable: false);
    if (queryTokens.isEmpty) {
      return SearchResults.fromHits(
        query,
        hits,
        offset: offset,
        limit: maxResults,
        totalCount: 0,
      );
    }

    var skipped = 0;
    var hasMore = false;
    for (final verse in allVerses) {
      final verseTokens = tokenizeSearchTextWithRanges(
        verse.text,
        caseSensitive: caseSensitive,
        normalizeUnicode: normalizeUnicode,
        ignoreDiacritics: ignoreDiacritics,
      )
          .map(
            (token) => _FuzzyVerseToken(
              token,
              token.normalized.runes.toList(growable: false),
            ),
          )
          .toList(growable: false);
      final ranges = _fuzzyMatchRanges(
        verseTokens,
        queryTokens,
        mode,
        maxDistance,
      );
      if (ranges == null) {
        continue;
      }
      if (skipped < offset) {
        skipped++;
        continue;
      }
      if (hits.length >= maxResults) {
        hasMore = true;
        break;
      }
      hits.add(
        SearchHit.withContext(
          verse: verse,
          book: getBook(verse.book),
          matchRanges: ranges,
        ),
      );
    }

    return SearchResults.fromHits(
      query,
      hits,
      offset: offset,
      limit: maxResults,
      totalCount: hasMore ? null : skipped + hits.length,
      hasMore: hasMore,
    );
  }

  /// Get all verses in a book.
  Iterable<Verse> get allVerses sync* {
    for (final book in books) {
      for (final chapter in book.chapters) {
        yield* chapter.verses;
      }
    }
  }

  /// Get books as an iterable with index.
  Iterable<(int, Book)> get booksWithIndex => books.indexed;

  /// Find books containing a specific word.
  List<Book> booksContaining(String word) {
    return List<Book>.unmodifiable(
      books.where(
        (book) => book.allVerses.any((verse) => verse.containsWord(word)),
      ),
    );
  }

  /// Get statistics about the Bible.
  BibleStats get stats => BibleStats._(this);
}

class _FuzzyTerm {
  final String text;
  final List<int> runes;

  const _FuzzyTerm(this.text, this.runes);
}

class _FuzzyVerseToken {
  final SearchTextToken token;
  final List<int> runes;

  const _FuzzyVerseToken(this.token, this.runes);
}

List<TextRange>? _fuzzyMatchRanges(
  List<_FuzzyVerseToken> verseTokens,
  List<_FuzzyTerm> queryTerms,
  SearchMode mode,
  int maxDistance,
) {
  if (verseTokens.isEmpty || queryTerms.isEmpty) {
    return null;
  }

  bool isMatch(_FuzzyVerseToken verseToken, _FuzzyTerm queryTerm) {
    if (areRuneSequencesWithinLevenshteinDistance(
      verseToken.runes,
      queryTerm.runes,
      maxDistance,
    )) {
      return true;
    }
    if (!usesUnspacedWordBoundaries(queryTerm.text) ||
        verseToken.runes.length <= queryTerm.runes.length) {
      return false;
    }

    final minimumWindow = queryTerm.runes.length > maxDistance
        ? queryTerm.runes.length - maxDistance
        : 1;
    final maximumWindow = queryTerm.runes.length + maxDistance;
    for (var windowLength = minimumWindow;
        windowLength <= maximumWindow &&
            windowLength <= verseToken.runes.length;
        windowLength++) {
      for (var start = 0;
          start <= verseToken.runes.length - windowLength;
          start++) {
        if (areRuneSequencesWithinLevenshteinDistance(
          verseToken.runes.sublist(start, start + windowLength),
          queryTerm.runes,
          maxDistance,
        )) {
          return true;
        }
      }
    }
    return false;
  }

  switch (mode) {
    case SearchMode.any:
      final ranges = <TextRange>[];
      for (final verseToken in verseTokens) {
        if (queryTerms.any((queryTerm) => isMatch(verseToken, queryTerm))) {
          ranges.add(verseToken.token.range);
        }
      }
      return ranges.isEmpty ? null : _mergeFuzzyRanges(ranges);
    case SearchMode.all:
      final ranges = <TextRange>[];
      final uniqueTerms = <String, _FuzzyTerm>{
        for (final queryTerm in queryTerms) queryTerm.text: queryTerm,
      };
      for (final queryTerm in uniqueTerms.values) {
        _FuzzyVerseToken? matchingToken;
        for (final verseToken in verseTokens) {
          if (isMatch(verseToken, queryTerm)) {
            matchingToken = verseToken;
            break;
          }
        }
        if (matchingToken == null) {
          return null;
        }
        ranges.add(matchingToken.token.range);
      }
      return _mergeFuzzyRanges(ranges);
    case SearchMode.exact:
      if (queryTerms.length > verseTokens.length) {
        return null;
      }
      final ranges = <TextRange>[];
      for (var start = 0;
          start <= verseTokens.length - queryTerms.length;
          start++) {
        var matches = true;
        for (var index = 0; index < queryTerms.length; index++) {
          if (!isMatch(verseTokens[start + index], queryTerms[index])) {
            matches = false;
            break;
          }
        }
        if (matches) {
          ranges.add(
            TextRange(
              start: verseTokens[start].token.start,
              end: verseTokens[start + queryTerms.length - 1].token.end,
            ),
          );
        }
      }
      return ranges.isEmpty ? null : _mergeFuzzyRanges(ranges);
  }
}

List<TextRange> _mergeFuzzyRanges(List<TextRange> ranges) {
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
        end: next.end > current.end ? next.end : current.end,
      );
    } else {
      merged.add(current);
      current = next;
    }
  }
  merged.add(current);
  return List<TextRange>.unmodifiable(merged);
}

/// Extension methods for Book class.
extension BookExtensions on Book {
  /// Get the number of verses in this book.
  int get verseCount =>
      chapters.fold(0, (sum, chapter) => sum + chapter.verses.length);

  /// Get all verses in this book.
  Iterable<Verse> get allVerses sync* {
    for (final chapter in chapters) {
      yield* chapter.verses;
    }
  }

  /// Find chapters containing a specific word.
  List<Chapter> chaptersContaining(String word) {
    return List<Chapter>.unmodifiable(
      chapters.where((chapter) => chapter.containsWord(word)),
    );
  }

  /// Get book statistics.
  BookStats get stats => BookStats._(this);
}

/// Extension methods for Chapter class.
extension ChapterExtensions on Chapter {
  /// Check if chapter contains a word.
  bool containsWord(String word) {
    return verses.any((verse) => verse.containsWord(word));
  }

  /// Get verses containing a specific word.
  List<Verse> versesContaining(String word) {
    return List<Verse>.unmodifiable(
      verses.where((verse) => verse.containsWord(word)),
    );
  }

  /// Get the reference string for this chapter.
  String get reference => '${book.fullName} $chapterNumber';

  /// Get chapter statistics.
  ChapterStats get stats => ChapterStats._(this);
}

/// Extension methods for Verse class.
extension VerseExtensions on Verse {
  /// Get the full reference string.
  String get reference => '${book.fullName} $chapterNumber:$verseNumber';

  /// Get the short reference string.
  String get shortReference =>
      '${book.abbreviation}$chapterNumber:$verseNumber';

  /// Check if verse contains any of the words.
  bool containsAny(List<String> words) {
    return words.any(containsWord);
  }

  /// Check if verse contains all of the words.
  bool containsAll(List<String> words) {
    return words.every(containsWord);
  }

  /// Get Unicode letter, mark, and number tokens in the verse.
  List<String> get words => extractUnicodeWords(text);

  /// Get the length of the verse text.
  int get length => text.length;

  /// Get verse statistics.
  VerseStats get stats => VerseStats._(this);
}

/// Statistics about a Bible.
class BibleStats {
  final Bible bible;

  BibleStats._(this.bible);

  int get bookCount => bible.books.length;
  int get chapterCount =>
      bible.books.fold(0, (sum, book) => sum + book.chapters.length);
  int get verseCount => bible.allVerses.length;
  int get totalWords =>
      bible.allVerses.fold(0, (sum, verse) => sum + verse.words.length);
  int get averageVerseLength => verseCount > 0
      ? (bible.allVerses.fold(0, (sum, verse) => sum + verse.length) /
              verseCount)
          .round()
      : 0;

  Map<BibleBookEnum, int> get versesPerBook => {
        for (final book in bible.books) book.bookEnum: book.verseCount,
      };

  @override
  String toString() =>
      'BibleStats(books: $bookCount, chapters: $chapterCount, verses: $verseCount, words: $totalWords)';
}

/// Statistics about a Book.
class BookStats {
  final Book book;

  BookStats._(this.book);

  int get chapterCount => book.chapters.length;
  int get verseCount => book.verseCount;
  int get totalWords =>
      book.allVerses.fold(0, (sum, verse) => sum + verse.words.length);
  double get averageVersesPerChapter =>
      chapterCount > 0 ? verseCount / chapterCount : 0;

  @override
  String toString() =>
      'BookStats(chapters: $chapterCount, verses: $verseCount, words: $totalWords)';
}

/// Statistics about a Chapter.
class ChapterStats {
  final Chapter chapter;

  ChapterStats._(this.chapter);

  int get verseCount => chapter.verses.length;
  int get totalWords =>
      chapter.verses.fold(0, (sum, verse) => sum + verse.words.length);
  int get averageVerseLength => verseCount > 0
      ? (chapter.verses.fold(0, (sum, verse) => sum + verse.length) /
              verseCount)
          .round()
      : 0;

  @override
  String toString() => 'ChapterStats(verses: $verseCount, words: $totalWords)';
}

/// Statistics about a Verse.
class VerseStats {
  final Verse verse;

  VerseStats._(this.verse);

  int get wordCount => verse.words.length;
  int get characterCount => verse.length;
  double get averageWordLength {
    final words = verse.words;
    if (words.isEmpty) return 0;

    final characterCount = words.fold<int>(
      0,
      (sum, word) => sum + word.runes.length,
    );
    return characterCount / words.length;
  }

  @override
  String toString() =>
      'VerseStats(words: $wordCount, characters: $characterCount)';
}
