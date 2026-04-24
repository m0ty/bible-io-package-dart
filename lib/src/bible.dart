import 'dart:convert';
import 'dart:io';

import 'package:bible_io_references/package.dart';

import 'book.dart';
import 'chapter.dart';
import 'errors.dart';
import 'extensions.dart';
import 'result.dart';
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

/// Options controlling advanced Bible search behavior.
class SearchOptions {
  final SearchMode mode;
  final bool caseSensitive;
  final bool wholeWords;
  final int? maxResults;
  final BibleBookEnum? book;
  final int? chapter;
  final int? verse;

  const SearchOptions({
    this.mode = SearchMode.exact,
    this.caseSensitive = false,
    this.wholeWords = false,
    this.maxResults,
    this.book,
    this.chapter,
    this.verse,
  });
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
  String toString() =>
      'BiblePerformanceMetrics('
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
  static final RegExp _unicodeTermPattern = RegExp(
    r'[\p{L}\p{M}\p{N}]+',
    unicode: true,
  );

  final List<Book> books;
  final BibleLanguageEnum language;
  late final Map<BibleBookEnum, Book> _booksByEnum;
  late final Map<String, List<Verse>> _searchIndex;
  final DateTime _createdAt = DateTime.now();
  Duration? _loadTime;

  DateTime get createdAt => _createdAt;

  Bible._(this.books, this.language, {Map<String, List<Verse>>? searchIndex}) {
    _booksByEnum = {for (final book in books) book.bookEnum: book};
    _searchIndex = searchIndex ?? _buildSearchIndex();
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
    final buffer = StringBuffer();
    final stringSink = StringConversionSink.withCallback(
      (decoded) => buffer.write(decoded),
    );
    final byteSink = utf8.decoder.startChunkedConversion(stringSink);
    int bytesRead = 0;

    await for (final chunk in file.openRead()) {
      byteSink.add(chunk);
      bytesRead += chunk.length;
      onProgress?.call(fileSize == 0 ? 1.0 : bytesRead / fileSize);
    }
    byteSink.close();

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
  factory Bible.fromBooks(
    List<Book> books, {
    BibleLanguageEnum language = BibleLanguageEnum.english,
  }) {
    return Bible._(books, language);
  }

  /// Create a Bible from initialization data.
  factory Bible._fromData(BibleInitializationData data) {
    return Bible._(data.books, data.language, searchIndex: data.searchIndex);
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
        throw ArgumentError(
          'Unsupported Bible book abbreviation \'$bookAbbr\'',
        );
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
    throw ArgumentError(
      'Invalid index format. Use bible[book], bible[(book, chapter)], or bible[(book, chapter, verse)]',
    );
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
    for (
      var chapterNumber = start.chapter + 1;
      chapterNumber < end.chapter;
      chapterNumber++
    ) {
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

    throw ArgumentError(
      'verseRef must be a VerseRef, VerseRangeRef, or reference string.',
    );
  }

  /// Retrieve a single chapter by book and chapter number.
  Chapter getChapter(BibleBookEnum bibleBook, int chapterNumber) {
    final book = getBook(bibleBook);
    if (chapterNumber < 1 || chapterNumber > book.chapters.length) {
      throw ChapterNotFoundError(book.bookEnum, chapterNumber);
    }
    return book.chapters[chapterNumber - 1];
  }

  /// Search for verses containing all tokenized terms in [query].
  ///
  /// This is a term search, not an exact phrase search. For phrase matching,
  /// use [searchAdvanced] with [SearchMode.exact].
  List<Verse> search(String query) {
    final tokens = _tokenizeText(query);
    if (tokens.isEmpty) {
      return [];
    }

    return searchWithOptions(
      query,
      const SearchOptions(mode: SearchMode.all),
    ).verses;
  }

  /// Mark the cached search index as stale so it will be rebuilt on demand.
  void invalidateSearchIndex() {
    _searchIndex.clear();
    _searchIndex.addAll(_buildSearchIndex());
  }

  /// Search for verses with advanced filtering options.
  SearchResults searchAdvanced({
    String? text,
    SearchMode mode = SearchMode.exact,
    BibleBookEnum? book,
    int? chapter,
    int? verse,
    bool caseSensitive = false,
    bool wholeWords = false,
    int? maxResults,
  }) {
    return searchWithOptions(
      text ?? '',
      SearchOptions(
        mode: mode,
        caseSensitive: caseSensitive,
        wholeWords: wholeWords,
        maxResults: maxResults,
        book: book,
        chapter: chapter,
        verse: verse,
      ),
    );
  }

  /// Search using a reusable options object.
  SearchResults searchWithOptions(String text, SearchOptions options) {
    final hasText = text.trim().isNotEmpty;
    final candidates = hasText
        ? _searchCandidates(text, options)
        : _versesForScope(options);
    final matches = hasText
        ? candidates.where(_buildTextMatcher(text, options))
        : candidates;

    return SearchResults(text, _collectResults(matches, options.maxResults));
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
  Result<Verse> getVerseResult(
    BibleBookEnum bibleBook,
    int chapterNumber,
    int verseNumber,
  ) {
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

  Iterable<Verse> _searchCandidates(String text, SearchOptions options) {
    switch (options.mode) {
      case SearchMode.exact:
        final candidates = _exactPhraseCandidates(text, options);
        return candidates ?? _versesForScope(options);
      case SearchMode.all:
        return _indexedTermCandidates(text, options, requireAllTerms: true);
      case SearchMode.any:
        return _indexedTermCandidates(text, options, requireAllTerms: false);
    }
  }

  Iterable<Verse>? _exactPhraseCandidates(String text, SearchOptions options) {
    if (!options.wholeWords) {
      return null;
    }

    final tokens = _tokenizeText(text);
    if (tokens.isEmpty) {
      return const <Verse>[];
    }

    final uniqueTokens = tokens.toSet();
    for (final token in uniqueTokens) {
      if (!_searchIndex.containsKey(token)) {
        return const <Verse>[];
      }
    }

    String? rarestToken;
    for (final token in uniqueTokens) {
      final matches = _searchIndex[token];
      if (matches == null) {
        continue;
      }
      if (rarestToken == null ||
          matches.length < _searchIndex[rarestToken]!.length) {
        rarestToken = token;
      }
    }

    if (rarestToken == null) {
      return null;
    }

    return _searchIndex[rarestToken]!.where(
      (verse) => _matchesScope(verse, options),
    );
  }

  Iterable<Verse> _indexedTermCandidates(
    String text,
    SearchOptions options, {
    required bool requireAllTerms,
  }) {
    final tokens = _tokenizeText(text).toSet();
    if (tokens.isEmpty) {
      return const <Verse>[];
    }

    if (requireAllTerms) {
      final tokenMatchesByToken = <String, List<Verse>>{};
      String? rarestToken;
      for (final token in tokens) {
        final tokenMatches = _searchIndex[token];
        if (tokenMatches == null) {
          return const <Verse>[];
        }
        tokenMatchesByToken[token] = tokenMatches;
        if (rarestToken == null ||
            tokenMatches.length < tokenMatchesByToken[rarestToken]!.length) {
          rarestToken = token;
        }
      }

      final otherTokenSets = <Set<Verse>>[
        for (final entry in tokenMatchesByToken.entries)
          if (entry.key != rarestToken) entry.value.toSet(),
      ];

      final rarestMatches = tokenMatchesByToken[rarestToken]!;
      return rarestMatches.where((verse) {
        if (!_matchesScope(verse, options)) {
          return false;
        }
        for (final tokenSet in otherTokenSets) {
          if (!tokenSet.contains(verse)) {
            return false;
          }
        }
        return true;
      });
    }

    final matches = <Verse>{};
    for (final token in tokens) {
      matches.addAll(_searchIndex[token] ?? const <Verse>[]);
    }
    if (matches.isEmpty) {
      return const <Verse>[];
    }
    return _versesForScope(options).where(matches.contains);
  }

  bool _matchesScope(Verse verse, SearchOptions options) {
    if (options.book != null && verse.book != options.book) {
      return false;
    }
    if (options.chapter != null && verse.chapterNumber != options.chapter) {
      return false;
    }
    if (options.verse != null && verse.verseNumber != options.verse) {
      return false;
    }
    return true;
  }

  Iterable<Verse> _versesForScope(SearchOptions options) sync* {
    final bookFilter = options.book;
    if (bookFilter != null) {
      final book = _booksByEnum[bookFilter];
      if (book == null) {
        return;
      }
      yield* _versesInBookScope(book, options.chapter, options.verse);
      return;
    }

    for (final book in books) {
      yield* _versesInBookScope(book, options.chapter, options.verse);
    }
  }

  Iterable<Verse> _versesInBookScope(
    Book book,
    int? chapterNumber,
    int? verseNumber,
  ) sync* {
    if (chapterNumber != null) {
      if (chapterNumber < 1 || chapterNumber > book.chapters.length) {
        return;
      }
      final chapter = book.chapters[chapterNumber - 1];
      if (verseNumber != null) {
        if (verseNumber < 1 || verseNumber > chapter.verses.length) {
          return;
        }
        yield chapter.verses[verseNumber - 1];
        return;
      }
      yield* chapter.verses;
      return;
    }

    for (final chapter in book.chapters) {
      if (verseNumber != null) {
        if (verseNumber >= 1 && verseNumber <= chapter.verses.length) {
          yield chapter.verses[verseNumber - 1];
        }
      } else {
        yield* chapter.verses;
      }
    }
  }

  bool Function(Verse verse) _buildTextMatcher(
    String text,
    SearchOptions options,
  ) {
    switch (options.mode) {
      case SearchMode.exact:
        if (options.wholeWords) {
          final queryTokens = _tokenizeText(
            text,
            caseSensitive: options.caseSensitive,
          );
          return (verse) => _containsTokenSequence(
            _tokenizeText(verse.text, caseSensitive: options.caseSensitive),
            queryTokens,
          );
        }

        final needle = options.caseSensitive ? text : text.toLowerCase();
        return (verse) {
          final haystack = options.caseSensitive
              ? verse.text
              : verse.text.toLowerCase();
          return haystack.contains(needle);
        };
      case SearchMode.all:
        final queryTokens = _tokenizeText(
          text,
          caseSensitive: options.caseSensitive,
        ).toSet();
        return (verse) {
          final verseTokens = _tokenizeText(
            verse.text,
            caseSensitive: options.caseSensitive,
          ).toSet();
          return queryTokens.every(verseTokens.contains);
        };
      case SearchMode.any:
        final queryTokens = _tokenizeText(
          text,
          caseSensitive: options.caseSensitive,
        ).toSet();
        return (verse) {
          final verseTokens = _tokenizeText(
            verse.text,
            caseSensitive: options.caseSensitive,
          ).toSet();
          return queryTokens.any(verseTokens.contains);
        };
    }
  }

  static bool _containsTokenSequence(
    List<String> tokens,
    List<String> sequence,
  ) {
    if (sequence.isEmpty || sequence.length > tokens.length) {
      return false;
    }

    for (var i = 0; i <= tokens.length - sequence.length; i++) {
      var matches = true;
      for (var j = 0; j < sequence.length; j++) {
        if (tokens[i + j] != sequence[j]) {
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

  static List<Verse> _collectResults(Iterable<Verse> matches, int? maxResults) {
    if (maxResults != null && maxResults <= 0) {
      return [];
    }

    final results = <Verse>[];
    for (final match in matches) {
      results.add(match);
      if (maxResults != null && results.length >= maxResults) {
        break;
      }
    }
    return results;
  }

  static List<String> _tokenizeText(String text, {bool caseSensitive = false}) {
    final normalized = _normalizeText(text, caseSensitive: caseSensitive);
    if (normalized.isEmpty) {
      return [];
    }
    return normalized.split(' ');
  }

  static String _normalizeText(String text, {bool caseSensitive = false}) {
    final source = caseSensitive ? text : text.toLowerCase();
    final tokens = _unicodeTermPattern
        .allMatches(source)
        .map((match) => match.group(0)!)
        .where((token) => token.isNotEmpty);
    return tokens.join(' ');
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

    return json.encode({'language': language.name, 'books': booksData});
  }
}
