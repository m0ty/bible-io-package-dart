import 'dart:convert';
import 'dart:math' as math;

import 'package:bible_io_references/bible_io_references.dart';

import 'bible_loader_stub.dart'
    if (dart.library.io) 'bible_loader_io.dart'
    as bible_loader;
import 'book.dart';
import 'chapter.dart';
import 'errors.dart';
import 'location.dart';
import 'result.dart';
import 'search.dart';
import 'source.dart';
import 'verse.dart';

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
  final BibleMetadata metadata;
  final Map<String, List<Verse>>? searchIndex;

  BibleInitializationData(
    List<Book> books,
    this.language, {
    BibleMetadata? metadata,
    this.searchIndex,
  }) : books = List.unmodifiable(books),
       metadata = metadata ?? BibleMetadata(languageName: language.name);
}

/// In-memory representation of a Bible with indexing and search helpers.
class Bible {
  static final RegExp _unicodeTermPattern = RegExp(
    r'[\p{L}\p{M}\p{N}]+',
    unicode: true,
  );
  static final Map<BibleLanguageEnum, ReferenceParser>
  _referenceParsersByPreferredLanguage = {};

  final List<Book> books;
  final BibleLanguageEnum language;
  final BibleMetadata metadata;
  late final Map<BibleBookEnum, Book> _booksByEnum;
  late final Map<String, List<Verse>> _searchIndex;
  late final ReferenceParser referenceParser;
  late final PassageParser passageParser;
  final DateTime _createdAt = DateTime.now();
  Duration? _loadTime;

  DateTime get createdAt => _createdAt;

  Bible._(
    List<Book> books,
    this.language, {
    BibleMetadata? metadata,
    Map<String, List<Verse>>? searchIndex,
  }) : books = List.unmodifiable(books),
       metadata = metadata ?? BibleMetadata(languageName: language.name) {
    _booksByEnum = {for (final book in books) book.bookEnum: book};
    if (_booksByEnum.length != books.length) {
      throw ArgumentError('Bible books must have unique book identifiers.');
    }

    final aliases = {
      for (final book in books)
        if (book.name.trim().toLowerCase() !=
            book.bookEnum.fullName.toLowerCase())
          book.name: book.bookEnum,
    };
    final hasConcreteLanguage = language != BibleLanguageEnum.auto;
    if (aliases.isEmpty) {
      referenceParser = hasConcreteLanguage
          ? _referenceParsersByPreferredLanguage.putIfAbsent(
              language,
              () => ReferenceParser(preferredLanguages: [language]),
            )
          : ReferenceParser.standard;
    } else {
      referenceParser = ReferenceParser(
        aliases: hasConcreteLanguage ? const {} : aliases,
        aliasesByLanguage: hasConcreteLanguage ? {language: aliases} : const {},
        preferredLanguages: hasConcreteLanguage ? [language] : const [],
      );
    }
    passageParser = PassageParser(referenceParser: referenceParser);
    _searchIndex = searchIndex ?? _buildSearchIndex();
  }

  BibleSource? get source => metadata.source;

  String? get languageName => metadata.languageName;

  String? get languageCode => metadata.languageCode;

  String? get translationName => metadata.translationName;

  String? get abbreviation => metadata.abbreviation;

  int? get year => metadata.year;

  TextDirectionHint get textDirection => metadata.direction;

  String? get sourceName => metadata.sourceName;

  String? get copyright => metadata.copyright;

  String? get license => metadata.license;

  String? get canon => metadata.canon;

  DateTime? get versionDate => metadata.versionDate;

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
    BibleSource? source,
  }) async {
    final stopwatch = Stopwatch()..start();
    final jsonString = await bible_loader.loadBibleJson(
      path,
      onProgress: onProgress,
    );
    final bible = Bible.fromJson(jsonString, source: source);

    bible._loadTime = stopwatch.elapsed;
    return bible;
  }

  /// Load Bible data from a Flutter-style asset bundle.
  ///
  /// The asset bundle is intentionally typed as dynamic so the core package
  /// does not need to import Flutter. Pass `rootBundle` or another object with
  /// a compatible `loadString(String key)` method.
  static Future<Bible> loadAsset(
    dynamic assetBundle,
    String key, {
    BibleSource? source,
  }) async {
    final stopwatch = Stopwatch()..start();
    final jsonString = await assetBundle.loadString(key) as String;
    final bible = Bible.fromJson(jsonString, source: source);
    bible._loadTime = stopwatch.elapsed;
    return bible;
  }

  /// Load the Bible data from UTF-8 encoded JSON bytes.
  factory Bible.fromUtf8Bytes(List<int> bytes, {BibleSource? source}) {
    return Bible.fromJson(utf8.decode(bytes), source: source);
  }

  /// Load the Bible data from an already-decoded JSON map.
  factory Bible.fromDecodedJson(
    Map<String, dynamic> data, {
    BibleSource? source,
  }) {
    final initializationData = _loadFromJson(data, source: source);
    return Bible._fromData(initializationData);
  }

  /// Load the Bible data from a JSON string.
  factory Bible.fromJson(String jsonString, {BibleSource? source}) {
    final data = json.decode(jsonString) as Map<String, dynamic>;
    return Bible.fromDecodedJson(data, source: source);
  }

  /// Create a Bible from a list of books directly.
  factory Bible.fromBooks(
    List<Book> books, {
    BibleLanguageEnum language = BibleLanguageEnum.english,
    BibleMetadata? metadata,
    BibleSource? source,
  }) {
    return Bible._(
      books,
      language,
      metadata:
          metadata ??
          BibleMetadata(
            source: source,
            languageName: source?.languageName ?? language.name,
            languageCode: source?.languageCode,
            translationName: source?.translationName,
            abbreviation: source?.abbreviation,
            year: source?.year,
            direction: source?.direction ?? TextDirectionHint.auto,
            sourceName: source?.sourceName,
            copyright: source?.copyright,
            license: source?.license,
            canon: source?.canon,
            versionDate: source?.versionDate,
          ),
    );
  }

  /// Create a Bible from initialization data.
  factory Bible._fromData(BibleInitializationData data) {
    return Bible._(
      data.books,
      data.language,
      metadata: data.metadata,
      searchIndex: data.searchIndex,
    );
  }

  static BibleInitializationData _loadFromJson(
    Map<String, dynamic> data, {
    BibleSource? source,
  }) {
    final metadata = BibleMetadata.fromDecodedJson(data, source: source);
    final language = _resolveBibleLanguage(data['language'], metadata);

    final booksData = data['books'] as Map<String, dynamic>;
    final books = <Book>[];
    for (final entry in booksData.entries) {
      final bookAbbr = entry.key;
      final bookData = entry.value as Map<String, dynamic>;

      final bookEnum = _parseBibleBookIdentifier(bookAbbr);

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
        }

        chapters.add(Chapter(bookEnum, chapterNumber, verses));
      }

      final bookName = bookData['name'] as String?;
      books.add(Book(bookEnum, chapters, name: bookName));
    }

    return BibleInitializationData(books, language, metadata: metadata);
  }

  static BibleBookEnum _parseBibleBookIdentifier(String identifier) {
    try {
      return BibleBookEnum.fromStr(identifier);
    } on ParseBibleBookError {
      // Try the interoperable identifiers added by bible_io_references 1.1.
    }

    for (final book in BibleBookEnum.values) {
      if (book.fullName.toLowerCase() == identifier.trim().toLowerCase()) {
        return book;
      }
    }

    try {
      return bibleBookFromOsisIdentifier(identifier);
    } on ArgumentError {
      // Continue with USFM before reporting one format-neutral error.
    }
    try {
      return bibleBookFromUsfmIdentifier(identifier);
    } on ArgumentError {
      throw ArgumentError.value(
        identifier,
        'books',
        'Unsupported Bible book identifier.',
      );
    }
  }

  static BibleLanguageEnum _resolveBibleLanguage(
    Object? rawLanguage,
    BibleMetadata metadata,
  ) {
    if (rawLanguage != null && rawLanguage is! String) {
      throw ArgumentError.value(
        rawLanguage,
        'language',
        'Bible language must be a string.',
      );
    }

    final candidates = <String?>[
      rawLanguage as String?,
      metadata.languageCode,
      metadata.languageName,
    ];
    for (final candidate in candidates) {
      if (candidate == null || candidate.trim().isEmpty) {
        continue;
      }
      try {
        return BibleLanguageEnum.fromStr(candidate);
      } on ArgumentError {
        // Keep trying richer metadata before falling back to auto-detection.
      }
    }
    return BibleLanguageEnum.auto;
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

  /// Convenient access with `bible[book]`, `bible[(book, chapter)]`, or
  /// `bible[(book, chapter, verse)]`.
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

  /// Parse a verse reference using this edition's language and book names as
  /// auto-detection preferences.
  ///
  /// Pass a concrete [inputLanguage] to restrict parsing to that language.
  /// Omitting it (or passing [BibleLanguageEnum.auto]) keeps multilingual
  /// detection enabled.
  ParseResult<Reference> parseReference(
    String input, {
    BibleLanguageEnum? inputLanguage,
  }) {
    return referenceParser.parseResult(input, language: inputLanguage);
  }

  /// Parse a rich passage expression without throwing.
  ParseResult<Passage> parsePassage(
    String input, {
    BibleLanguageEnum? inputLanguage,
  }) {
    return passageParser.parseResult(input, language: inputLanguage);
  }

  /// Resolve a typed single-verse reference against this edition.
  Verse resolveVerseReference(VerseRef reference) {
    return getVerse(reference.book, reference.chapter, reference.verse);
  }

  /// Resolve a typed reference into verses from this edition.
  ///
  /// Cross-book ranges follow the order of [books], allowing editions with a
  /// canon order that differs from the dependency's default enum order.
  List<Verse> resolveReference(Reference reference) {
    if (reference is VerseRef) {
      return List.unmodifiable([resolveVerseReference(reference)]);
    }
    if (reference is VerseRangeRef) {
      return _resolveVerseRange(reference);
    }
    throw ArgumentError.value(reference, 'reference', 'Unsupported reference');
  }

  /// Retrieve a single verse by VerseRef or reference string.
  Verse getVerseByRef(dynamic verseRef, {BibleLanguageEnum? inputLanguage}) {
    if (verseRef is String) {
      verseRef = referenceParser.parse(verseRef, language: inputLanguage);
    }
    if (verseRef is! VerseRef) {
      throw ArgumentError('verseRef must be a VerseRef or string.');
    }
    return resolveVerseReference(verseRef);
  }

  /// Retrieve a contiguous range of verses by VerseRangeRef or text.
  List<Verse> getVerseRangeByRef(
    dynamic verseRangeRef, {
    BibleLanguageEnum? inputLanguage,
  }) {
    if (verseRangeRef is String) {
      verseRangeRef = referenceParser.parse(
        verseRangeRef,
        language: inputLanguage,
      );
    }
    if (verseRangeRef is! VerseRangeRef) {
      throw ArgumentError('verseRangeRef must be a VerseRangeRef or string.');
    }

    return _resolveVerseRange(verseRangeRef);
  }

  List<Verse> _resolveVerseRange(VerseRangeRef verseRangeRef) {
    final start = verseRangeRef.start;
    final end = verseRangeRef.end;
    final startBookIndex = _bookIndexOf(start.book);
    final endBookIndex = _bookIndexOf(end.book);

    // Validate both endpoints before collecting any partial result.
    resolveVerseReference(start);
    resolveVerseReference(end);

    if (startBookIndex > endBookIndex ||
        (startBookIndex == endBookIndex &&
            ((start.chapter > end.chapter) ||
                (start.chapter == end.chapter && start.verse > end.verse)))) {
      throw ArgumentError('Verse range start must come before the end.');
    }

    final verses = <Verse>[];
    for (
      var bookIndex = startBookIndex;
      bookIndex <= endBookIndex;
      bookIndex++
    ) {
      final book = books[bookIndex];
      for (final chapter in book.chapters) {
        for (final verse in chapter.verses) {
          final beforeStart =
              bookIndex == startBookIndex &&
              (chapter.chapterNumber < start.chapter ||
                  (chapter.chapterNumber == start.chapter &&
                      verse.verseNumber < start.verse));
          final afterEnd =
              bookIndex == endBookIndex &&
              (chapter.chapterNumber > end.chapter ||
                  (chapter.chapterNumber == end.chapter &&
                      verse.verseNumber > end.verse));
          if (!beforeStart && !afterEnd) {
            verses.add(verse);
          }
        }
      }
    }

    return List.unmodifiable(verses);
  }

  /// Retrieve either a verse or verse range from a ref object or string.
  dynamic getByRef(dynamic verseRef, {BibleLanguageEnum? inputLanguage}) {
    if (verseRef is String) {
      verseRef = referenceParser.parse(verseRef, language: inputLanguage);
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

  /// Resolve a rich [Passage] value into an immutable, source-ordered list.
  ///
  /// Passage sequences and overlapping selections preserve duplicates because
  /// they can carry meaning for callers presenting each requested segment.
  List<Verse> resolvePassage(Passage passage) {
    final verses = <Verse>[];
    if (passage is BookPassage) {
      final book = getBook(passage.book);
      for (final chapter in book.chapters) {
        verses.addAll(chapter.verses);
      }
    } else if (passage is ChapterPassage) {
      final endChapter = passage.endChapter ?? passage.startChapter;
      for (
        var chapterNumber = passage.startChapter;
        chapterNumber <= endChapter;
        chapterNumber++
      ) {
        verses.addAll(getChapter(passage.book, chapterNumber).verses);
      }
    } else if (passage is VersePassage) {
      for (final selection in passage.selections) {
        verses.addAll(resolveReference(selection));
      }
    } else if (passage is PassageSequence) {
      for (final child in passage.passages) {
        verses.addAll(resolvePassage(child));
      }
    } else {
      throw UnsupportedError(
        'Unsupported passage type: ${passage.runtimeType}',
      );
    }
    return List.unmodifiable(verses);
  }

  /// Parse and resolve a rich passage string, or resolve a typed passage or
  /// narrow reference directly.
  List<Verse> getPassage(Object passage, {BibleLanguageEnum? inputLanguage}) {
    if (passage is String) {
      return resolvePassage(
        passageParser.parse(passage, language: inputLanguage),
      );
    }
    if (passage is Passage) {
      return resolvePassage(passage);
    }
    if (passage is Reference) {
      return resolveReference(passage);
    }
    throw ArgumentError.value(
      passage,
      'passage',
      'Must be a Passage, Reference, or reference string.',
    );
  }

  /// Retrieve a single chapter by book and chapter number.
  Chapter getChapter(BibleBookEnum bibleBook, int chapterNumber) {
    final book = getBook(bibleBook);
    return book.getChapter(chapterNumber);
  }

  /// Retrieve the chapter identified by a stable Bible location.
  Chapter getChapterAt(BibleLocation location) {
    return getChapter(location.book, location.chapter);
  }

  /// Retrieve the verse identified by a stable Bible location.
  Verse getVerseAt(BibleLocation location) {
    final verseNumber = location.verse;
    if (verseNumber == null) {
      throw ArgumentError('BibleLocation.verse is required.');
    }
    return getVerse(location.book, location.chapter, verseNumber);
  }

  /// Whether this Bible contains the requested chapter or verse location.
  bool containsReference(BibleLocation location) {
    try {
      if (location.verse == null) {
        getChapterAt(location);
      } else {
        getVerseAt(location);
      }
      return true;
    } on BibleError {
      return false;
    } on ArgumentError {
      return false;
    }
  }

  /// Return the next chapter location, or null when already at the end.
  BibleLocation? nextChapter(BibleLocation current) {
    final bookIndex = _bookIndexOf(current.book);
    final book = books[bookIndex];
    final chapterIndex = book.chapters.indexWhere(
      (chapter) => chapter.chapterNumber == current.chapter,
    );
    if (chapterIndex == -1) {
      throw ChapterNotFoundError(current.book, current.chapter);
    }

    if (chapterIndex + 1 < book.chapters.length) {
      return BibleLocation(
        book: current.book,
        chapter: book.chapters[chapterIndex + 1].chapterNumber,
      );
    }

    for (
      var nextBookIndex = bookIndex + 1;
      nextBookIndex < books.length;
      nextBookIndex++
    ) {
      final nextBook = books[nextBookIndex];
      if (nextBook.chapters.isNotEmpty) {
        return BibleLocation(
          book: nextBook.bookEnum,
          chapter: nextBook.chapters.first.chapterNumber,
        );
      }
    }
    return null;
  }

  /// Return the previous chapter location, or null when already at the start.
  BibleLocation? previousChapter(BibleLocation current) {
    final bookIndex = _bookIndexOf(current.book);
    final book = books[bookIndex];
    final chapterIndex = book.chapters.indexWhere(
      (chapter) => chapter.chapterNumber == current.chapter,
    );
    if (chapterIndex == -1) {
      throw ChapterNotFoundError(current.book, current.chapter);
    }

    if (chapterIndex > 0) {
      return BibleLocation(
        book: current.book,
        chapter: book.chapters[chapterIndex - 1].chapterNumber,
      );
    }

    for (
      var previousBookIndex = bookIndex - 1;
      previousBookIndex >= 0;
      previousBookIndex--
    ) {
      final previousBook = books[previousBookIndex];
      if (previousBook.chapters.isNotEmpty) {
        return BibleLocation(
          book: previousBook.bookEnum,
          chapter: previousBook.chapters.last.chapterNumber,
        );
      }
    }
    return null;
  }

  bool hasNextChapter(BibleLocation current) => nextChapter(current) != null;

  bool hasPreviousChapter(BibleLocation current) {
    return previousChapter(current) != null;
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
    final verses = _collectResults(matches, options.maxResults);
    final hits = verses
        .map((verse) => _buildSearchHit(verse, text, options, hasText: hasText))
        .toList(growable: false);

    return SearchResults.fromHits(text, hits);
  }

  /// Fetch a book by enumeration identifier (Result-based).
  Result<Book> getBookResult(BibleBookEnum book) {
    try {
      return Result.success(getBook(book));
    } catch (e) {
      return Result.failure(_resultErrorMessage(e));
    }
  }

  /// Fetch a book by its 1-based index position (Result-based).
  Result<Book> getBookByIdResult(int bookNumber) {
    try {
      return Result.success(getBookById(bookNumber));
    } catch (e) {
      return Result.failure(_resultErrorMessage(e));
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
      return Result.failure(_resultErrorMessage(e));
    }
  }

  /// Retrieve a single verse by reference (Result-based).
  Result<Verse> getVerseByRefResult(
    dynamic verseRef, {
    BibleLanguageEnum? inputLanguage,
  }) {
    try {
      return Result.success(
        getVerseByRef(verseRef, inputLanguage: inputLanguage),
      );
    } catch (e) {
      return Result.failure(_resultErrorMessage(e));
    }
  }

  /// Retrieve verses by range (Result-based).
  Result<List<Verse>> getVerseRangeByRefResult(
    dynamic verseRangeRef, {
    BibleLanguageEnum? inputLanguage,
  }) {
    try {
      return Result.success(
        getVerseRangeByRef(verseRangeRef, inputLanguage: inputLanguage),
      );
    } catch (e) {
      return Result.failure(_resultErrorMessage(e));
    }
  }

  /// Parse or resolve a rich passage without throwing (Result-based).
  Result<List<Verse>> getPassageResult(
    Object passage, {
    BibleLanguageEnum? inputLanguage,
  }) {
    try {
      return Result.success(getPassage(passage, inputLanguage: inputLanguage));
    } catch (e) {
      return Result.failure(_resultErrorMessage(e));
    }
  }

  static String _resultErrorMessage(Object error) {
    return error is BibleError ? error.message : error.toString();
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

  int _bookIndexOf(BibleBookEnum book) {
    final index = books.indexWhere((candidate) => candidate.bookEnum == book);
    if (index == -1) {
      throw BookNotFoundError(book, stackTrace: StackTrace.current);
    }
    return index;
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
      Chapter? matchingChapter;
      for (final chapter in book.chapters) {
        if (chapter.chapterNumber == chapterNumber) {
          matchingChapter = chapter;
          break;
        }
      }
      if (matchingChapter == null) {
        return;
      }
      if (verseNumber != null) {
        for (final verse in matchingChapter.verses) {
          if (verse.verseNumber == verseNumber) {
            yield verse;
            break;
          }
        }
        return;
      }
      yield* matchingChapter.verses;
      return;
    }

    for (final chapter in book.chapters) {
      if (verseNumber != null) {
        for (final verse in chapter.verses) {
          if (verse.verseNumber == verseNumber) {
            yield verse;
            break;
          }
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

        final pattern = RegExp(
          RegExp.escape(text),
          caseSensitive: options.caseSensitive,
          unicode: true,
        );
        return (verse) => pattern.hasMatch(verse.text);
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

  SearchHit _buildSearchHit(
    Verse verse,
    String query,
    SearchOptions options, {
    required bool hasText,
  }) {
    final ranges = hasText
        ? _buildMatchRanges(verse.text, query, options)
        : const <TextRange>[];
    return SearchHit(
      verse: verse,
      book: getBook(verse.book),
      matchRanges: ranges,
      snippet: _buildSnippet(verse.text, ranges),
    );
  }

  static List<TextRange> _buildMatchRanges(
    String text,
    String query,
    SearchOptions options,
  ) {
    switch (options.mode) {
      case SearchMode.exact:
        if (options.wholeWords) {
          return _wholeWordPhraseRanges(text, query, options.caseSensitive);
        }
        return _substringRanges(text, query, options.caseSensitive);
      case SearchMode.all:
      case SearchMode.any:
        return _tokenRanges(text, query, options.caseSensitive);
    }
  }

  static List<TextRange> _substringRanges(
    String text,
    String query,
    bool caseSensitive,
  ) {
    if (query.isEmpty) {
      return const [];
    }

    final pattern = RegExp(
      RegExp.escape(query),
      caseSensitive: caseSensitive,
      unicode: true,
    );
    return pattern
        .allMatches(text)
        .map((match) => TextRange(start: match.start, end: match.end))
        .toList(growable: false);
  }

  static List<TextRange> _wholeWordPhraseRanges(
    String text,
    String query,
    bool caseSensitive,
  ) {
    final queryTokens = _tokenizeText(query, caseSensitive: caseSensitive);
    if (queryTokens.isEmpty) {
      return const [];
    }

    final textTokens = _tokenizeTextWithRanges(
      text,
      caseSensitive: caseSensitive,
    );
    if (queryTokens.length > textTokens.length) {
      return const [];
    }

    final ranges = <TextRange>[];
    for (var i = 0; i <= textTokens.length - queryTokens.length; i++) {
      var matches = true;
      for (var j = 0; j < queryTokens.length; j++) {
        if (textTokens[i + j].token != queryTokens[j]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        ranges.add(
          TextRange(
            start: textTokens[i].start,
            end: textTokens[i + queryTokens.length - 1].end,
          ),
        );
      }
    }
    return ranges;
  }

  static List<TextRange> _tokenRanges(
    String text,
    String query,
    bool caseSensitive,
  ) {
    final queryTokens = _tokenizeText(
      query,
      caseSensitive: caseSensitive,
    ).toSet();
    if (queryTokens.isEmpty) {
      return const [];
    }

    return _tokenizeTextWithRanges(text, caseSensitive: caseSensitive)
        .where((token) => queryTokens.contains(token.token))
        .map((token) => TextRange(start: token.start, end: token.end))
        .toList(growable: false);
  }

  static List<_TokenMatch> _tokenizeTextWithRanges(
    String text, {
    bool caseSensitive = false,
  }) {
    return _unicodeTermPattern
        .allMatches(text)
        .map((match) {
          final rawToken = match.group(0)!;
          return _TokenMatch(
            caseSensitive ? rawToken : rawToken.toLowerCase(),
            match.start,
            match.end,
          );
        })
        .where((token) => token.token.isNotEmpty)
        .toList(growable: false);
  }

  static String _buildSnippet(String text, List<TextRange> ranges) {
    if (ranges.isEmpty) {
      if (text.length <= 160) {
        return text;
      }
      return '${text.substring(0, 157)}...';
    }
    if (text.length <= 160) {
      return text;
    }

    final first = ranges.first;
    final start = math.max(0, first.start - 48);
    final end = math.min(text.length, first.end + 48);
    final prefix = start > 0 ? '...' : '';
    final suffix = end < text.length ? '...' : '';
    return '$prefix${text.substring(start, end).trim()}$suffix';
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

    return json.encode({
      'language': language.name,
      'metadata': metadata.toJson(),
      'books': booksData,
    });
  }
}

class _TokenMatch {
  final String token;
  final int start;
  final int end;

  const _TokenMatch(this.token, this.start, this.end);
}
