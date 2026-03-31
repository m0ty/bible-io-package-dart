import 'dart:convert';
import 'dart:io';

import 'package:bible_io_references/package.dart';

import 'book.dart';
import 'chapter.dart';
import 'errors.dart';
import 'extensions.dart';
import 'result.dart';
import 'verse.dart';

/// Search mode for multi-term queries.
enum SearchMode {
  /// Match any of the terms.
  any,

  /// Match all of the terms.
  all,

  /// Match the exact phrase.
  exact,
}

/// Performance metrics for Bible operations.
class BiblePerformanceMetrics {
  final Duration loadTime;
  final int searchIndexSize;
  final int memoryUsage;

  const BiblePerformanceMetrics({
    required this.loadTime,
    required this.searchIndexSize,
    required this.memoryUsage,
  });

  @override
  String toString() => 'BiblePerformanceMetrics('
      'loadTime: $loadTime, '
      'searchIndexSize: $searchIndexSize, '
      'memoryUsage: ${memoryUsage}KB)';
}

/// Bundle of books and an optional search index used to seed Bible instances.
class BibleInitializationData {
  final List<Book> books;
  final BibleLanguageEnum language;
  final Map<String, List<Verse>>? searchIndex;

  BibleInitializationData(this.books, this.language, {this.searchIndex});
}

/// In-memory representation of a Bible with indexing and search helpers.
class Bible {
  final List<Book> books;
  final BibleLanguageEnum language;
  late final Map<BibleBookEnum, Book> _booksByEnum;
  late final Map<String, List<Verse>> _searchIndex;
  final DateTime _createdAt = DateTime.now();
  Duration? _loadTime;

  Bible._(this.books, this.language) {
    _booksByEnum = {for (final book in books) book.bookEnum: book};
    _searchIndex = _buildSearchIndex();
  }

  /// Get performance metrics for this Bible instance.
  BiblePerformanceMetrics get performanceMetrics => BiblePerformanceMetrics(
        loadTime: _loadTime ?? Duration.zero,
        searchIndexSize: _searchIndex.length,
        memoryUsage: _estimateMemoryUsage(),
      );

  /// Estimate memory usage in KB.
  int _estimateMemoryUsage() {
    int total = 0;
    // Rough estimation: each verse ~200 bytes, index entries ~50 bytes each
    total += allVerses.length * 200;
    total += _searchIndex.length * 50;
    return total ~/ 1024; // Convert to KB
  }

  /// Load the Bible data from a JSON file asynchronously with progress callback.
  static Future<Bible> load(
    String path, {
    void Function(double progress)? onProgress,
  }) async {
    final startTime = DateTime.now();

    final file = File(path);
    final fileSize = await file.length();
    final stream = file.openRead();

    final buffer = StringBuffer();
    int bytesRead = 0;

    await for (final chunk in stream) {
      buffer.write(String.fromCharCodes(chunk));
      bytesRead += chunk.length;
      onProgress?.call(bytesRead / fileSize);
    }

    final jsonString = buffer.toString();
    onProgress?.call(1.0); // Complete

    final data = json.decode(jsonString) as Map<String, dynamic>;
    final initializationData = _loadFromJson(data);
    final bible = Bible._fromData(initializationData);

    bible._loadTime = DateTime.now().difference(startTime);
    return bible;
  }

  /// Load the Bible data from a JSON string.
  factory Bible.fromJson(String jsonString) {
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final initializationData = _loadFromJson(data);
    return Bible._fromData(initializationData);
  }

  /// Create a Bible from a list of books directly.
  factory Bible.fromBooks(List<Book> books, {BibleLanguageEnum language = BibleLanguageEnum.english}) {
    return Bible._(books, language);
  }

  /// Create a Bible from initialization data.
  factory Bible._fromData(BibleInitializationData data) {
    final bible = Bible._(data.books, data.language);
    if (data.searchIndex != null) {
      bible._searchIndex.clear();
      bible._searchIndex.addAll(data.searchIndex!);
    }
    return bible;
  }

  static BibleInitializationData _loadFromJson(Map<String, dynamic> data) {
    final rawLanguage = data['language'] as String?;
    final language = rawLanguage != null
        ? BibleLanguageEnum.fromStr(rawLanguage)
        : BibleLanguageEnum.auto;

    final booksData = data['books'] as Map<String, dynamic>;
    final books = <Book>[];
    final searchIndex = <String, List<Verse>>{};

    for (final entry in booksData.entries) {
      final bookAbbr = entry.key;
      final bookData = entry.value as Map<String, dynamic>;

      BibleBookEnum? bookEnum;
      try {
        bookEnum = BibleBookEnum.fromStr(bookAbbr);
      } catch (e) {
        throw ArgumentError('Unsupported Bible book abbreviation \'$bookAbbr\'');
      }

      final chaptersData = bookData['chapters'] as Map<String, dynamic>;
      final chapters = <Chapter>[];

      for (final chapterEntry in chaptersData.entries) {
        final chapterNumber = int.parse(chapterEntry.key);
        final versesData = chapterEntry.value as Map<String, dynamic>;
        final verses = <Verse>[];

        for (final verseEntry in versesData.entries) {
          final verseNumber = int.parse(verseEntry.key);
          final verseText = verseEntry.value as String;
          final verse = Verse(bookEnum, chapterNumber, verseNumber, verseText);
          verses.add(verse);

          final tokens = _tokenizeText(verseText);
          for (final token in tokens.toSet()) {
            searchIndex.putIfAbsent(token, () => []).add(verse);
          }
        }

        chapters.add(Chapter(bookEnum, chapterNumber, verses));
      }

      final bookName = bookData['name'] as String?;
      books.add(Book(bookEnum, chapters, name: bookName));
    }

    return BibleInitializationData(books, language, searchIndex: searchIndex);
  }

  /// Fetch a book by enumeration identifier.
  Book getBook(BibleBookEnum book) {
    final result = _booksByEnum[book];
    if (result == null) {
      throw BookNotFoundError(book, stackTrace: StackTrace.current);
    }
    return result;
  }

  /// Fetch a book by its 1-based index position.
  Book getBookById(int bookNumber) {
    if (bookNumber < 1 || bookNumber > books.length) {
      throw BookNotFoundError(bookNumber, stackTrace: StackTrace.current);
    }
    return books[bookNumber - 1];
  }

  /// Convenient access using index operator: bible[book] or bible[(book, chapter)] or bible[(book, chapter, verse)]
  dynamic operator [](dynamic key) {
    if (key is BibleBookEnum) {
      return getBook(key);
    }
    if (key is (BibleBookEnum, int)) {
      final (book, chapter) = key;
      return getChapter(book, chapter);
    }
    if (key is (BibleBookEnum, int, int)) {
      final (book, chapter, verse) = key;
      return getVerse(book, chapter, verse);
    }
    throw ArgumentError('Invalid index format. Use bible[book], bible[(book, chapter)], or bible[(book, chapter, verse)]');
  }

  /// Get all verses in the Bible as an iterable.
  Iterable<Verse> get allVerses sync* {
    for (final book in books) {
      for (final chapter in book.chapters) {
        for (final verse in chapter.verses) {
          yield verse;
        }
      }
    }
  }

  /// Retrieve all verses for a specific chapter.
  List<Verse> getVerses(BibleBookEnum bibleBook, int chapterNumber) {
    final book = getBook(bibleBook);
    return book.getVerses(chapterNumber);
  }

  /// Retrieve a single verse identified by book, chapter, and verse.
  Verse getVerse(BibleBookEnum bibleBook, int chapterNumber, int verseNumber) {
    final book = getBook(bibleBook);
    return book.getVerse(chapterNumber, verseNumber);
  }

  /// Retrieve a single verse by VerseRef or reference string.
  Verse getVerseByRef(dynamic verseRef) {
    if (verseRef is String) {
      verseRef = Reference.parse(verseRef, language: language);
    }
    if (verseRef is! VerseRef) {
      throw ArgumentError('verseRef must be a VerseRef or string.');
    }
    return getVerse(verseRef.book, verseRef.chapter, verseRef.verse);
  }

  /// Retrieve a contiguous range of verses by VerseRangeRef or text.
  List<Verse> getVerseRangeByRef(dynamic verseRangeRef) {
    if (verseRangeRef is String) {
      verseRangeRef = Reference.parse(verseRangeRef, language: language);
    }
    if (verseRangeRef is! VerseRangeRef) {
      throw ArgumentError('verseRangeRef must be a VerseRangeRef or string.');
    }

    final start = verseRangeRef.start;
    final end = verseRangeRef.end;

    if (start.book != end.book) {
      throw ArgumentError('Verse ranges must stay within a single book.');
    }
    if ((start.chapter > end.chapter) ||
        (start.chapter == end.chapter && start.verse > end.verse)) {
      throw ArgumentError('Verse range start must come before the end.');
    }

    final book = getBook(start.book);
    if (start.chapter == end.chapter) {
      final chapterVerses = book.getVerses(start.chapter);
      if (start.verse < 1 || start.verse > chapterVerses.length) {
        throw VerseNotFoundError(start.book, start.chapter, start.verse);
      }
      if (end.verse < 1 || end.verse > chapterVerses.length) {
        throw VerseNotFoundError(end.book, end.chapter, end.verse);
      }
      return chapterVerses.sublist(start.verse - 1, end.verse);
    }

    final verses = <Verse>[];
    final startChapterVerses = book.getVerses(start.chapter);
    if (start.verse < 1 || start.verse > startChapterVerses.length) {
      throw VerseNotFoundError(start.book, start.chapter, start.verse);
    }
    // Add verses from start.verse to end of start.chapter
    verses.addAll(startChapterVerses.sublist(start.verse - 1));

    // Add all verses from complete chapters in between
    for (var chapterNumber = start.chapter + 1; chapterNumber < end.chapter; chapterNumber++) {
      verses.addAll(book.getVerses(chapterNumber));
    }

    // Add verses from beginning of end.chapter up to end.verse
    final endChapterVerses = book.getVerses(end.chapter);
    if (end.verse < 1 || end.verse > endChapterVerses.length) {
      throw VerseNotFoundError(end.book, end.chapter, end.verse);
    }
    verses.addAll(endChapterVerses.sublist(0, end.verse));

    return verses;
  }

  /// Retrieve either a verse or verse range from a ref object or string.
  dynamic getByRef(dynamic verseRef) {
    if (verseRef is String) {
      verseRef = Reference.parse(verseRef, language: language);
    }

    if (verseRef is VerseRef) {
      return getVerseByRef(verseRef);
    }
    if (verseRef is VerseRangeRef) {
      return getVerseRangeByRef(verseRef);
    }

    throw ArgumentError('verseRef must be a VerseRef, VerseRangeRef, or reference string.');
  }

  /// Retrieve a single chapter by book and chapter number.
  Chapter getChapter(BibleBookEnum bibleBook, int chapterNumber) {
    final book = getBook(bibleBook);
    if (chapterNumber < 1 || chapterNumber > book.chapters.length) {
      throw ChapterNotFoundError(book.bookEnum, chapterNumber);
    }
    return book.chapters[chapterNumber - 1];
  }

  /// Search for verses containing any of the provided words.
  List<Verse> search(String word) {
    final tokens = _tokenizeText(word);
    if (tokens.isEmpty) {
      return [];
    }

    if (tokens.length == 1) {
      // Single word search
      return _searchIndex[tokens.first]?.toList() ?? [];
    }

    // Multi-word search: find verses containing ALL words
    final tokenSets = tokens.map((token) => _searchIndex[token]?.toSet() ?? <Verse>{}).toList();
    if (tokenSets.any((set) => set.isEmpty)) {
      return []; // If any token has no matches, no verse can contain all tokens
    }

    // Find intersection of all token result sets
    var intersection = tokenSets.first;
    for (var i = 1; i < tokenSets.length; i++) {
      intersection = intersection.intersection(tokenSets[i]);
    }

    return intersection.toList();
  }

  /// Mark the cached search index as stale so it will be rebuilt on demand.
  void invalidateSearchIndex() {
    _searchIndex.clear();
    _searchIndex.addAll(_buildSearchIndex());
  }

  /// Search for verses with advanced filtering options.
  SearchResults searchAdvanced({
    String? text,
    BibleBookEnum? book,
    int? chapter,
    int? verse,
    bool caseSensitive = false,
    bool wholeWords = false,
    int? maxResults,
  }) {
    var results = allVerses;

    // Filter by book
    if (book != null) {
      results = results.where((v) => v.book == book);
    }

    // Filter by chapter
    if (chapter != null) {
      results = results.where((v) => v.chapterNumber == chapter);
    }

    // Filter by verse number
    if (verse != null) {
      results = results.where((v) => v.verseNumber == verse);
    }

    // Filter by text content
    if (text != null && text.isNotEmpty) {
      final searchText = caseSensitive ? text : text.toLowerCase();
      results = results.where((v) {
        final verseText = caseSensitive ? v.text : v.text.toLowerCase();
        if (wholeWords) {
          final pattern = RegExp(r'\b' + RegExp.escape(searchText) + r'\b', caseSensitive: caseSensitive);
          return pattern.hasMatch(verseText);
        } else {
          return verseText.contains(searchText);
        }
      });
    }

    final finalResults = results.toList();
    final limitedResults = maxResults != null ? finalResults.take(maxResults).toList() : finalResults;
    return SearchResults(text ?? '', limitedResults);
  }

  /// Fetch a book by enumeration identifier (Result-based).
  Result<Book> getBookResult(BibleBookEnum book) {
    try {
      return Result.success(getBook(book));
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  /// Fetch a book by its 1-based index position (Result-based).
  Result<Book> getBookByIdResult(int bookNumber) {
    try {
      return Result.success(getBookById(bookNumber));
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  /// Retrieve a single verse (Result-based).
  Result<Verse> getVerseResult(BibleBookEnum bibleBook, int chapterNumber, int verseNumber) {
    try {
      return Result.success(getVerse(bibleBook, chapterNumber, verseNumber));
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  /// Retrieve a single verse by reference (Result-based).
  Result<Verse> getVerseByRefResult(dynamic verseRef) {
    try {
      return Result.success(getVerseByRef(verseRef));
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  /// Retrieve verses by range (Result-based).
  Result<List<Verse>> getVerseRangeByRefResult(dynamic verseRangeRef) {
    try {
      return Result.success(getVerseRangeByRef(verseRangeRef));
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  Map<String, List<Verse>> _buildSearchIndex() {
    final index = <String, List<Verse>>{};
    for (final book in books) {
      for (final chapter in book.chapters) {
        for (final verse in chapter.verses) {
          final tokens = _tokenizeText(verse.text);
          for (final token in tokens.toSet()) {
            index.putIfAbsent(token, () => []).add(verse);
          }
        }
      }
    }
    return index;
  }

  static List<String> _tokenizeText(String text) {
    final normalized = _normalizeText(text);
    if (normalized.isEmpty) {
      return [];
    }
    return normalized.split(' ');
  }

  static String _normalizeText(String text) {
    // Remove punctuation and normalize
    final cleaned = text.replaceAll(RegExp(r'[^\w\s]'), ' ').toLowerCase();
    return cleaned.split(' ').where((s) => s.isNotEmpty).join(' ');
  }

  /// Export the Bible data to JSON string.
  String toJson() {
    final booksData = <String, dynamic>{};

    for (final book in books) {
      final chaptersData = <String, dynamic>{};

      for (final chapter in book.chapters) {
        final versesData = <String, dynamic>{};

        for (final verse in chapter.verses) {
          versesData[verse.verseNumber.toString()] = verse.text;
        }

        chaptersData[chapter.chapterNumber.toString()] = versesData;
      }

      booksData[book.bookEnum.abbreviation] = {
        'name': book.name,
        'chapters': chaptersData,
      };
    }

    return json.encode({
      'language': language.name,
      'books': booksData,
    });
  }
}