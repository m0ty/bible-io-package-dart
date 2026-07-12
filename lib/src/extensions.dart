import 'package:bible_io_references/bible_io_references.dart';

import 'bible.dart';
import 'book.dart';
import 'chapter.dart';
import 'errors.dart';
import 'search.dart';
import 'verse.dart';

final RegExp _unicodeWordPattern = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);

List<String> _tokenizeWords(String text) => _unicodeWordPattern
    .allMatches(text)
    .map((match) => match.group(0)!)
    .toList(growable: false);

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

  /// Fuzzy search with Levenshtein distance.
  SearchResults fuzzySearch(
    String query, {
    int maxDistance = 2,
    int maxResults = 50,
  }) {
    if (maxDistance < 0) {
      throw ArgumentError.value(
        maxDistance,
        'maxDistance',
        'must be non-negative',
      );
    }

    final hits = <SearchHit>[];
    final queryLower = query.trim().toLowerCase();
    if (queryLower.isEmpty || maxResults <= 0) {
      return SearchResults.fromHits(query, hits);
    }

    for (final verse in allVerses) {
      final words = _tokenizeWords(verse.text.toLowerCase());
      for (final word in words) {
        if (_levenshteinDistance(word, queryLower) <= maxDistance) {
          hits.add(SearchHit(verse: verse, book: getBook(verse.book)));
          break; // Only add verse once
        }
      }
      if (hits.length >= maxResults) break;
    }

    return SearchResults.fromHits(query, hits);
  }

  /// Calculate Levenshtein distance between two strings.
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;

    final s1Runes = s1.runes.toList(growable: false);
    final s2Runes = s2.runes.toList(growable: false);
    if (s1Runes.isEmpty) return s2Runes.length;
    if (s2Runes.isEmpty) return s1Runes.length;

    final matrix = List.generate(
      s1Runes.length + 1,
      (i) => List.filled(s2Runes.length + 1, 0),
    );

    for (var i = 0; i <= s1Runes.length; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= s2Runes.length; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= s1Runes.length; i++) {
      for (var j = 1; j <= s2Runes.length; j++) {
        final cost = s1Runes[i - 1] == s2Runes[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1Runes.length][s2Runes.length];
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
    return books
        .where(
          (book) => book.allVerses.any((verse) => verse.containsWord(word)),
        )
        .toList();
  }

  /// Get statistics about the Bible.
  BibleStats get stats => BibleStats._(this);
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
    return chapters.where((chapter) => chapter.containsWord(word)).toList();
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
    return verses.where((verse) => verse.containsWord(word)).toList();
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
  List<String> get words => _tokenizeWords(text);

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
