import 'dart:convert';

import 'package:bible_io_references/bible_io_references.dart';

import 'background_runner_stub.dart'
    if (dart.library.io) 'background_runner_io.dart' as background_runner;
import 'bible_loader_stub.dart' if (dart.library.io) 'bible_loader_io.dart'
    as bible_loader;
import 'book.dart';
import 'chapter.dart';
import 'errors.dart';
import 'json_value.dart';
import 'loading.dart';
import 'location.dart';
import 'result.dart';
import 'search.dart';
import 'source.dart';
import 'text_search.dart';
import 'verse.dart';

/// Current version of the serialized Bible content contract.
const int currentBibleSchemaVersion = 1;

/// Performance metrics for Bible operations.
class BiblePerformanceMetrics {
  final Duration loadTime;

  /// Number of distinct normalized terms in the retained index.
  final int searchIndexSize;

  /// Approximate retained model and index memory, in KiB.
  final int memoryUsage;

  final bool searchIndexBuilt;
  final int verseCount;
  final int postingCount;
  final int textCodeUnits;

  const BiblePerformanceMetrics({
    required this.loadTime,
    required this.searchIndexSize,
    required this.memoryUsage,
    this.searchIndexBuilt = true,
    this.verseCount = 0,
    this.postingCount = 0,
    this.textCodeUnits = 0,
  });

  @override
  String toString() => 'BiblePerformanceMetrics('
      'loadTime: $loadTime, '
      'searchIndexSize: $searchIndexSize, '
      'searchIndexBuilt: $searchIndexBuilt, '
      'verseCount: $verseCount, '
      'postingCount: $postingCount, '
      'memoryUsage: ${memoryUsage}KB)';
}

/// Bundle of books and an optional search index used to seed Bible instances.
class BibleInitializationData {
  final List<Book> books;
  final BibleLanguageEnum language;
  final BibleMetadata metadata;
  final Map<String, List<Verse>>? searchIndex;
  final int schemaVersion;
  final Map<String, Object?> annotations;
  final SearchIndexMode searchIndexMode;

  BibleInitializationData(
    List<Book> books,
    this.language, {
    BibleMetadata? metadata,
    Map<String, List<Verse>>? searchIndex,
    this.schemaVersion = currentBibleSchemaVersion,
    Map<String, Object?> annotations = const {},
    this.searchIndexMode = SearchIndexMode.eager,
  })  : books = List.unmodifiable(books),
        metadata = metadata ?? BibleMetadata(languageName: language.name),
        searchIndex = searchIndex == null
            ? null
            : _freezeInitializationSearchIndex(searchIndex),
        annotations = freezeJsonMap(
          annotations,
          reservedKeys: _rootDocumentFields,
          parameterName: 'annotations',
        );
}

/// In-memory representation of a Bible with indexing and search helpers.
class Bible {
  static final Map<BibleLanguageEnum, ReferenceParser>
      _referenceParsersByPreferredLanguage = {};

  final List<Book> books;
  final BibleLanguageEnum language;
  final BibleMetadata metadata;
  final int schemaVersion;
  final Map<String, Object?> annotations;
  final SearchIndexMode searchIndexMode;
  late final Map<BibleBookEnum, Book> _booksByEnum;
  Map<String, List<Verse>>? _searchIndex;
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
    this.schemaVersion = currentBibleSchemaVersion,
    Map<String, Object?> annotations = const {},
    this.searchIndexMode = SearchIndexMode.eager,
  })  : books = List.unmodifiable(books),
        metadata = metadata ?? BibleMetadata(languageName: language.name),
        annotations = freezeJsonMap(
          annotations,
          reservedKeys: _rootDocumentFields,
          parameterName: 'annotations',
        ) {
    if (schemaVersion != currentBibleSchemaVersion) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'Only schema version $currentBibleSchemaVersion is supported.',
      );
    }
    _booksByEnum = {for (final book in books) book.bookEnum: book};
    if (_booksByEnum.length != books.length) {
      throw ArgumentError('Bible books must have unique book identifiers.');
    }
    _validateBookAliases(books);

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
    if (searchIndexMode != SearchIndexMode.disabled && searchIndex != null) {
      _searchIndex = _freezeSearchIndex(searchIndex);
    } else if (searchIndexMode == SearchIndexMode.eager) {
      _searchIndex = _buildSearchIndex();
    }
  }

  BibleSource? get source => metadata.source;

  /// Stable edition identifier used for persisted UI state.
  String? get id => metadata.id;

  String? get description => metadata.description;

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

  /// Whether an indexed-search cache is currently retained.
  bool get hasSearchIndex => _searchIndex != null;

  /// Get performance metrics for this Bible instance.
  BiblePerformanceMetrics get performanceMetrics {
    final verses = allVerses.toList(growable: false);
    final index = _searchIndex;
    return BiblePerformanceMetrics(
      loadTime: _loadTime ?? Duration.zero,
      searchIndexSize: index?.length ?? 0,
      memoryUsage: _estimateMemoryUsage(verses),
      searchIndexBuilt: index != null,
      verseCount: verses.length,
      postingCount:
          index?.values.fold<int>(0, (sum, values) => sum + values.length) ?? 0,
      textCodeUnits: verses.fold(0, (sum, verse) => sum + verse.text.length),
    );
  }

  /// Estimate retained model and index memory in KiB.
  int _estimateMemoryUsage(List<Verse> verses) {
    // UTF-16 text plus conservative object/reference overhead. This remains an
    // estimate, but it scales with the actual content and posting counts.
    var totalBytes = 0;
    for (final verse in verses) {
      totalBytes += 64 + verse.text.length * 2;
    }
    for (final book in books) {
      totalBytes += 96 + book.name.length * 2;
      totalBytes += book.chapters.length * 72;
    }
    final index = _searchIndex;
    if (index != null) {
      for (final entry in index.entries) {
        totalBytes += 64 + entry.key.length * 2 + entry.value.length * 8;
      }
    }
    return (totalBytes / 1024).ceil();
  }

  /// Load the Bible data from a JSON file asynchronously with progress callback.
  static Future<Bible> load(
    String path, {
    void Function(double progress)? onProgress,
    BibleLoadProgressCallback? onLoadProgress,
    BibleSource? source,
    BibleLoadOptions options = const BibleLoadOptions(),
  }) async {
    final stopwatch = Stopwatch()..start();
    late final String jsonString;
    try {
      jsonString = await bible_loader.loadBibleJson(
        path,
        onProgress: (readingFraction) {
          final fraction = readingFraction * 0.65;
          onProgress?.call(fraction);
          onLoadProgress?.call(
            BibleLoadProgress(
              phase: BibleLoadPhase.reading,
              fraction: fraction,
              phaseFraction: readingFraction,
            ),
          );
        },
      );
    } on FormatException catch (error, stackTrace) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidJson,
        path: r'$',
        message: 'Bible file must contain valid UTF-8 JSON.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    onLoadProgress?.call(
      BibleLoadProgress(
        phase: BibleLoadPhase.processing,
        fraction: 0.65,
        phaseFraction: 0,
      ),
    );
    final bible = await Bible.fromJsonAsync(
      jsonString,
      source: source,
      options: options,
    );

    bible._loadTime = stopwatch.elapsed;
    onLoadProgress?.call(
      BibleLoadProgress(
        phase: BibleLoadPhase.processing,
        fraction: 1,
        phaseFraction: 1,
      ),
    );
    onProgress?.call(1);
    onLoadProgress?.call(
      BibleLoadProgress(
        phase: BibleLoadPhase.complete,
        fraction: 1,
        phaseFraction: 1,
      ),
    );
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
    BibleLoadOptions options = const BibleLoadOptions(),
    BibleLoadProgressCallback? onLoadProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    onLoadProgress?.call(
      BibleLoadProgress(
        phase: BibleLoadPhase.reading,
        fraction: 0,
        phaseFraction: 0,
      ),
    );
    final loadedAsset = await assetBundle.loadString(key);
    if (loadedAsset is! String) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: r'$',
        message: 'Asset bundle loadString must return a String.',
        value: loadedAsset,
      );
    }
    final jsonString = loadedAsset;
    onLoadProgress?.call(
      BibleLoadProgress(
        phase: BibleLoadPhase.reading,
        fraction: 0.65,
        phaseFraction: 1,
      ),
    );
    onLoadProgress?.call(
      BibleLoadProgress(
        phase: BibleLoadPhase.processing,
        fraction: 0.65,
        phaseFraction: 0,
      ),
    );
    final bible = await Bible.fromJsonAsync(
      jsonString,
      source: source,
      options: options,
    );
    bible._loadTime = stopwatch.elapsed;
    onLoadProgress?.call(
      BibleLoadProgress(
        phase: BibleLoadPhase.processing,
        fraction: 1,
        phaseFraction: 1,
      ),
    );
    onLoadProgress?.call(
      BibleLoadProgress(
        phase: BibleLoadPhase.complete,
        fraction: 1,
        phaseFraction: 1,
      ),
    );
    return bible;
  }

  /// Load the Bible data from UTF-8 encoded JSON bytes.
  factory Bible.fromUtf8Bytes(
    List<int> bytes, {
    BibleSource? source,
    BibleLoadOptions options = const BibleLoadOptions(),
  }) {
    try {
      return Bible.fromJson(
        utf8.decode(bytes),
        source: source,
        options: options,
      );
    } on BibleDataFormatError {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidJson,
        path: r'$',
        message: 'Bible bytes must contain valid UTF-8 JSON.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Load the Bible data from an already-decoded JSON map.
  factory Bible.fromDecodedJson(
    Map<String, dynamic> data, {
    BibleSource? source,
    BibleLoadOptions options = const BibleLoadOptions(),
  }) {
    final initializationData = _loadFromJson(
      data,
      source: source,
      options: options,
    );
    return Bible._fromData(initializationData);
  }

  /// Load the Bible data from a JSON string.
  factory Bible.fromJson(
    String jsonString, {
    BibleSource? source,
    BibleLoadOptions options = const BibleLoadOptions(),
  }) {
    Object? decoded;
    try {
      decoded = json.decode(jsonString);
    } on FormatException catch (error, stackTrace) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidJson,
        path: r'$',
        message: 'Bible content is not valid JSON.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (decoded is! Map) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: r'$',
        message: 'Bible JSON must have an object at its root.',
        value: decoded,
      );
    }
    final data = _stringKeyedMap(decoded, r'$');
    return Bible.fromDecodedJson(data, source: source, options: options);
  }

  /// Parses and initializes a Bible without blocking the caller isolate when
  /// the active platform supports isolates.
  static Future<Bible> fromJsonAsync(
    String jsonString, {
    BibleSource? source,
    BibleLoadOptions options = const BibleLoadOptions(),
  }) {
    if (!options.parseInBackground) {
      return Future.value(
        Bible.fromJson(jsonString, source: source, options: options),
      );
    }
    return background_runner.runBibleTask(
      () => Bible.fromJson(
        jsonString,
        source: source,
        options: options.copyWith(parseInBackground: false),
      ),
    );
  }

  /// Create a Bible from a list of books directly.
  factory Bible.fromBooks(
    List<Book> books, {
    BibleLanguageEnum language = BibleLanguageEnum.english,
    BibleMetadata? metadata,
    BibleSource? source,
    int schemaVersion = currentBibleSchemaVersion,
    Map<String, Object?> annotations = const {},
    SearchIndexMode searchIndexMode = SearchIndexMode.eager,
  }) {
    return Bible._(
      books,
      language,
      metadata: mergeBibleMetadata(
        metadata: metadata,
        source: source,
        fallbackLanguageName: language.name,
        fallbackLanguageCode:
            language == BibleLanguageEnum.auto ? null : language.code,
      ),
      schemaVersion: schemaVersion,
      annotations: annotations,
      searchIndexMode: searchIndexMode,
    );
  }

  /// Create a Bible from initialization data.
  factory Bible._fromData(BibleInitializationData data) {
    return Bible._(
      data.books,
      data.language,
      metadata: data.metadata,
      searchIndex: data.searchIndex,
      schemaVersion: data.schemaVersion,
      annotations: data.annotations,
      searchIndexMode: data.searchIndexMode,
    );
  }

  /// Derive a new immutable Bible value.
  ///
  /// The retained index is reused only when content and index policy are
  /// unchanged; otherwise the new value follows its selected index policy.
  Bible copyWith({
    List<Book>? books,
    BibleLanguageEnum? language,
    BibleMetadata? metadata,
    Map<String, Object?>? annotations,
    SearchIndexMode? searchIndexMode,
  }) {
    final nextBooks = books ?? this.books;
    final nextMode = searchIndexMode ?? this.searchIndexMode;
    final canReuseIndex = identical(nextBooks, this.books) &&
        nextMode == this.searchIndexMode &&
        nextMode != SearchIndexMode.disabled;
    return Bible._(
      nextBooks,
      language ?? this.language,
      metadata: metadata ?? this.metadata,
      searchIndex: canReuseIndex ? _searchIndex : null,
      schemaVersion: schemaVersion,
      annotations: annotations ?? this.annotations,
      searchIndexMode: nextMode,
    );
  }

  static BibleInitializationData _loadFromJson(
    Map<String, dynamic> data, {
    BibleSource? source,
    required BibleLoadOptions options,
  }) {
    final schemaVersion = _readSchemaVersion(data);
    final metadata = _readMetadata(data, source);
    final language = _resolveBibleLanguage(data['language'], metadata);
    final validation = options.validation;

    final hasBooks = data.containsKey('books');
    final rawBooks = data['books'];
    if (!hasBooks) {
      if (validation.requireBooks) {
        throw BibleDataFormatError(
          code: BibleDataFormatErrorCode.missingField,
          path: r'$.books',
          message: 'Bible content must declare a books object.',
        );
      }
    } else if (rawBooks is! Map) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: r'$.books',
        message: 'Bible books must be an object.',
        value: rawBooks,
      );
    }

    final booksData = !hasBooks
        ? <String, dynamic>{}
        : _stringKeyedMap(rawBooks as Map, r'$.books');
    if (validation.requireBooks && booksData.isEmpty) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: r'$.books',
        message: 'Bible content must contain at least one book.',
        value: rawBooks,
      );
    }

    final parsedBooks = <BibleBookEnum, Book>{};
    for (final entry in booksData.entries) {
      final bookPath = _jsonPropertyPath(r'$.books', entry.key);
      final bookEnum = _readBookIdentifier(entry.key, bookPath);
      if (parsedBooks.containsKey(bookEnum)) {
        throw BibleDataFormatError(
          code: BibleDataFormatErrorCode.invalidValue,
          path: bookPath,
          message: 'The same Bible book is declared more than once.',
          value: entry.key,
        );
      }
      parsedBooks[bookEnum] = _readBook(
        bookEnum,
        entry.value,
        bookPath,
        validation,
      );
    }

    final orderedBookEnums = _readBookOrder(
      data['bookOrder'],
      parsedBooks,
      isPresent: data.containsKey('bookOrder'),
    );
    final books = [for (final book in orderedBookEnums) parsedBooks[book]!];
    try {
      _validateBookAliases(books);
    } on ArgumentError catch (error, stackTrace) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: r'$.books',
        message: 'Loaded book names create an ambiguous reference alias.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    final rootAnnotations = _readAdditionalFields(
      data,
      _rootDocumentFields,
      r'$',
    );

    return BibleInitializationData(
      books,
      language,
      metadata: metadata,
      schemaVersion: schemaVersion,
      annotations: rootAnnotations,
      searchIndexMode: options.searchIndexMode,
    );
  }

  static int _readSchemaVersion(Map<String, dynamic> data) {
    if (!data.containsKey('schemaVersion')) return currentBibleSchemaVersion;
    final rawVersion = data['schemaVersion'];
    if (rawVersion is! int) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: r'$.schemaVersion',
        message: 'schemaVersion must be an integer.',
        value: rawVersion,
      );
    }
    if (rawVersion != currentBibleSchemaVersion) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: r'$.schemaVersion',
        message:
            'Unsupported Bible schema version $rawVersion; supported version: '
            '$currentBibleSchemaVersion.',
        value: rawVersion,
      );
    }
    return rawVersion;
  }

  static BibleMetadata _readMetadata(
    Map<String, dynamic> data,
    BibleSource? source,
  ) {
    try {
      final metadata = BibleMetadata.fromDecodedJson(data, source: source);
      if (metadata.additional.isEmpty) return metadata;

      // BibleMetadata also accepts legacy metadata fields at the document
      // root. Keep truly root-level extensions on Bible.annotations so their
      // serialized location is not silently changed to `metadata`.
      final rawMetadata = data['metadata'] is Map
          ? _stringKeyedMap(data['metadata'] as Map, r'$.metadata')
          : const <String, dynamic>{};
      final rawSource = rawMetadata['source'] is Map
          ? _stringKeyedMap(rawMetadata['source'] as Map, r'$.metadata.source')
          : data['source'] is Map
              ? _stringKeyedMap(data['source'] as Map, r'$.source')
              : const <String, dynamic>{};
      final nestedAdditional = <String, Object?>{
        for (final entry in metadata.additional.entries)
          if (rawMetadata.containsKey(entry.key) ||
              rawSource.containsKey(entry.key))
            entry.key: entry.value,
      };
      return metadata.copyWith(additional: nestedAdditional);
    } on BibleDataFormatError {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: r'$.metadata',
        message: 'Bible metadata is malformed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Book _readBook(
    BibleBookEnum book,
    Object? rawBook,
    String path,
    BibleDataValidationOptions validation,
  ) {
    if (rawBook is! Map) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: path,
        message: 'A Bible book must be an object.',
        value: rawBook,
      );
    }
    final bookData = _stringKeyedMap(rawBook, path);
    final rawName = bookData['name'];
    if (rawName != null && (rawName is! String || rawName.trim().isEmpty)) {
      throw BibleDataFormatError(
        code: rawName is String
            ? BibleDataFormatErrorCode.invalidValue
            : BibleDataFormatErrorCode.invalidType,
        path: '$path.name',
        message: 'Book name must be a non-blank string.',
        value: rawName,
      );
    }

    final hasChapters = bookData.containsKey('chapters');
    final rawChapters = bookData['chapters'];
    if (!hasChapters && validation.requireChapters) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.missingField,
        path: '$path.chapters',
        message: 'A Bible book must declare chapters.',
      );
    }
    if (hasChapters && rawChapters is! Map) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: '$path.chapters',
        message: 'Book chapters must be an object.',
        value: rawChapters,
      );
    }
    final chaptersData = !hasChapters
        ? <String, dynamic>{}
        : _stringKeyedMap(rawChapters as Map, '$path.chapters');
    if (validation.requireChapters && chaptersData.isEmpty) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: '$path.chapters',
        message: 'A Bible book must contain at least one chapter.',
        value: rawChapters,
      );
    }

    final seenChapterNumbers = <int>{};
    final chapters = <Chapter>[];
    for (final entry in chaptersData.entries) {
      final chapterPath = _jsonPropertyPath('$path.chapters', entry.key);
      final chapterNumber = _readPositiveMapKey(entry.key, chapterPath);
      if (!seenChapterNumbers.add(chapterNumber)) {
        throw BibleDataFormatError(
          code: BibleDataFormatErrorCode.invalidValue,
          path: chapterPath,
          message: 'Duplicate numeric chapter number $chapterNumber.',
          value: entry.key,
        );
      }
      chapters.add(
        _readChapter(book, chapterNumber, entry.value, chapterPath, validation),
      );
    }

    final annotations = _readAdditionalFields(
        bookData,
        const {
          'name',
          'chapters',
        },
        path);
    try {
      return Book(
        book,
        chapters,
        name: rawName as String?,
        annotations: annotations,
      );
    } on Object catch (error, stackTrace) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: path,
        message: 'Bible book data violates model invariants.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Chapter _readChapter(
    BibleBookEnum book,
    int chapterNumber,
    Object? rawChapter,
    String path,
    BibleDataValidationOptions validation,
  ) {
    if (rawChapter is! Map) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: path,
        message: 'A Bible chapter must be an object.',
        value: rawChapter,
      );
    }
    final chapterData = _stringKeyedMap(rawChapter, path);
    final isStructured = chapterData.containsKey('verses');
    final rawVerses = isStructured ? chapterData['verses'] : chapterData;
    if (rawVerses is! Map) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: isStructured ? '$path.verses' : path,
        message: 'Chapter verses must be an object.',
        value: rawVerses,
      );
    }
    final versesPath = isStructured ? '$path.verses' : path;
    final versesData = _stringKeyedMap(rawVerses, versesPath);
    if (validation.requireVerses && versesData.isEmpty) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: versesPath,
        message: 'A Bible chapter must contain at least one verse.',
        value: rawVerses,
      );
    }

    final seenVerseNumbers = <int>{};
    final verses = <Verse>[];
    for (final entry in versesData.entries) {
      final versePath = _jsonPropertyPath(versesPath, entry.key);
      final verseNumber = _readPositiveMapKey(entry.key, versePath);
      if (!seenVerseNumbers.add(verseNumber)) {
        throw BibleDataFormatError(
          code: BibleDataFormatErrorCode.invalidValue,
          path: versePath,
          message: 'Duplicate numeric verse number $verseNumber.',
          value: entry.key,
        );
      }
      verses.add(
        _readVerse(
          book,
          chapterNumber,
          verseNumber,
          entry.value,
          versePath,
          validation,
        ),
      );
    }

    final annotations = isStructured
        ? _readAdditionalFields(chapterData, const {'verses'}, path)
        : const <String, Object?>{};
    try {
      return Chapter(book, chapterNumber, verses, annotations: annotations);
    } on Object catch (error, stackTrace) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: path,
        message: 'Bible chapter data violates model invariants.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Verse _readVerse(
    BibleBookEnum book,
    int chapterNumber,
    int verseNumber,
    Object? rawVerse,
    String path,
    BibleDataValidationOptions validation,
  ) {
    late final String text;
    Map<String, Object?> annotations = const {};
    if (rawVerse is String) {
      text = rawVerse;
    } else if (rawVerse is Map) {
      final verseData = _stringKeyedMap(rawVerse, path);
      if (!verseData.containsKey('text')) {
        throw BibleDataFormatError(
          code: BibleDataFormatErrorCode.missingField,
          path: '$path.text',
          message: 'An annotated verse must declare text.',
        );
      }
      final rawText = verseData['text'];
      if (rawText is! String) {
        throw BibleDataFormatError(
          code: BibleDataFormatErrorCode.invalidType,
          path: '$path.text',
          message: 'Verse text must be a string.',
          value: rawText,
        );
      }
      text = rawText;
      annotations = _readAdditionalFields(verseData, const {'text'}, path);
    } else {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: path,
        message: 'A verse must be a string or an object containing text.',
        value: rawVerse,
      );
    }
    if (validation.requireVerseText && text.trim().isEmpty) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: rawVerse is Map ? '$path.text' : path,
        message: 'Verse text must not be blank.',
        value: text,
      );
    }
    try {
      return Verse.checked(
        book,
        chapterNumber,
        verseNumber,
        text,
        annotations: annotations,
      );
    } on Object catch (error, stackTrace) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: path,
        message: 'Bible verse data violates model invariants.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  static List<BibleBookEnum> _readBookOrder(
    Object? rawOrder,
    Map<BibleBookEnum, Book> books, {
    required bool isPresent,
  }) {
    if (!isPresent) {
      final order = books.keys.toList(growable: false)
        ..sort((first, second) => first.index.compareTo(second.index));
      return order;
    }
    if (rawOrder is! List) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: r'$.bookOrder',
        message: 'bookOrder must be an array of book identifiers.',
        value: rawOrder,
      );
    }
    final order = <BibleBookEnum>[];
    final seen = <BibleBookEnum>{};
    for (var index = 0; index < rawOrder.length; index++) {
      final value = rawOrder[index];
      final path = '\$.bookOrder[$index]';
      if (value is! String || value.trim().isEmpty) {
        throw BibleDataFormatError(
          code: value is String
              ? BibleDataFormatErrorCode.invalidValue
              : BibleDataFormatErrorCode.invalidType,
          path: path,
          message: 'Each bookOrder item must be a non-blank string.',
          value: value,
        );
      }
      final book = _readBookIdentifier(value, path);
      if (!books.containsKey(book)) {
        throw BibleDataFormatError(
          code: BibleDataFormatErrorCode.invalidValue,
          path: path,
          message: 'bookOrder references a book that is not loaded.',
          value: value,
        );
      }
      if (!seen.add(book)) {
        throw BibleDataFormatError(
          code: BibleDataFormatErrorCode.invalidValue,
          path: path,
          message: 'bookOrder contains a duplicate book.',
          value: value,
        );
      }
      order.add(book);
    }
    if (order.length != books.length) {
      final missing = books.keys
          .where((book) => !seen.contains(book))
          .map((book) => book.abbreviation)
          .toList(growable: false);
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: r'$.bookOrder',
        message: 'bookOrder must list every loaded book exactly once.',
        value: missing,
      );
    }
    return order;
  }

  static BibleBookEnum _readBookIdentifier(String value, String path) {
    if (value.trim().isEmpty) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: path,
        message: 'Bible book identifiers must not be blank.',
        value: value,
      );
    }
    try {
      return _parseBibleBookIdentifier(value);
    } on Object catch (error, stackTrace) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: path,
        message: 'Unsupported Bible book identifier.',
        value: value,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  static int _readPositiveMapKey(String value, String path) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 1) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: path,
        message: 'Chapter and verse keys must be positive integers.',
        value: value,
      );
    }
    return parsed;
  }

  static Map<String, Object?> _readAdditionalFields(
    Map<String, dynamic> data,
    Set<String> structuralFields,
    String path,
  ) {
    try {
      return freezeJsonMap({
        for (final entry in data.entries)
          if (!structuralFields.contains(entry.key)) entry.key: entry.value,
      });
    } on Object catch (error, stackTrace) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.nonJsonValue,
        path: path,
        message: 'Additional content fields must be JSON-compatible.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
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

  static void _validateBookAliases(List<Book> books) {
    final owners = <String, BibleBookEnum>{};
    for (final book in books) {
      final terms = {
        book.bookEnum.fullName,
        book.bookEnum.abbreviation,
        book.name,
      };
      for (final term in terms) {
        final normalized =
            term.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        final existing = owners[normalized];
        if (existing != null && existing != book.bookEnum) {
          throw ArgumentError.value(
            term,
            'books',
            'Reference alias conflicts between ${existing.fullName} and '
                '${book.bookEnum.fullName}.',
          );
        }
        owners[normalized] = book.bookEnum;
      }
    }
  }

  static BibleLanguageEnum _resolveBibleLanguage(
    Object? rawLanguage,
    BibleMetadata metadata,
  ) {
    if (rawLanguage != null && rawLanguage is! String) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: r'$.language',
        message: 'Bible language must be a string.',
        value: rawLanguage,
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
    final result = referenceParser.parseResult(
      input,
      language: inputLanguage,
    );
    if (result case ParseFailure<Reference>(error: final error)) {
      final fallback = _tryParseEditionOrderedRange(
        input,
        error,
        inputLanguage,
      );
      if (fallback != null) return ParseSuccess<Reference>(fallback);
    }
    return result;
  }

  /// Parse a rich passage expression without throwing.
  ParseResult<Passage> parsePassage(
    String input, {
    BibleLanguageEnum? inputLanguage,
  }) {
    final result = passageParser.parseResult(input, language: inputLanguage);
    if (result case ParseFailure<Passage>(error: final error)) {
      final fallback = _tryParseEditionOrderedRange(
        input,
        error,
        inputLanguage,
      );
      if (fallback != null) {
        return ParseSuccess<Passage>(VersePassage([fallback]));
      }
    }
    return result;
  }

  VerseRangeRef? _tryParseEditionOrderedRange(
    String input,
    ParseVerseRefError error,
    BibleLanguageEnum? inputLanguage,
  ) {
    if (error.errorCode != ReferenceParseErrorCode.crossBookRangeNotAscending) {
      return null;
    }
    for (final separator in _rangeSeparatorPattern.allMatches(input)) {
      final left = input.substring(0, separator.start).trim();
      final right = input.substring(separator.end).trim();
      if (left.isEmpty || right.isEmpty) continue;
      try {
        final start = referenceParser.parseVerse(
          left,
          language: inputLanguage,
        );
        final end = referenceParser.parseVerse(
          right,
          language: inputLanguage,
        );
        if (start.book != end.book &&
            _bookIndexOf(start.book) < _bookIndexOf(end.book)) {
          return VerseRangeRef(start: start, end: end);
        }
      } on Object {
        // A hyphen may be part of a custom book alias. Try the next one.
      }
    }
    return null;
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
      final parsed = parseReference(
        verseRangeRef,
        inputLanguage: inputLanguage,
      );
      if (parsed case ParseSuccess<Reference>(value: final reference)) {
        verseRangeRef = reference;
      } else if (parsed case ParseFailure<Reference>(error: final error)) {
        throw error;
      }
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
    for (var bookIndex = startBookIndex;
        bookIndex <= endBookIndex;
        bookIndex++) {
      final book = books[bookIndex];
      for (final chapter in book.chapters) {
        for (final verse in chapter.verses) {
          final beforeStart = bookIndex == startBookIndex &&
              (chapter.chapterNumber < start.chapter ||
                  (chapter.chapterNumber == start.chapter &&
                      verse.verseNumber < start.verse));
          final afterEnd = bookIndex == endBookIndex &&
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
      final parsed = parseReference(verseRef, inputLanguage: inputLanguage);
      if (parsed case ParseSuccess<Reference>(value: final reference)) {
        verseRef = reference;
      } else if (parsed case ParseFailure<Reference>(error: final error)) {
        throw error;
      }
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
      for (var chapterNumber = passage.startChapter;
          chapterNumber <= endChapter;
          chapterNumber++) {
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
      final parsed = parsePassage(passage, inputLanguage: inputLanguage);
      if (parsed case ParseSuccess<Passage>(value: final value)) {
        return resolvePassage(value);
      }
      throw (parsed as ParseFailure<Passage>).error;
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

  /// Create an edition-aware persisted-state key for a loaded verse.
  BibleVerseKey keyForVerse(Verse verse) {
    final editionId = id;
    if (editionId == null || editionId.trim().isEmpty) {
      throw StateError(
        'Bible metadata must define an id before creating persisted keys.',
      );
    }
    final loadedVerse = getVerse(
      verse.book,
      verse.chapterNumber,
      verse.verseNumber,
    );
    if (loadedVerse != verse) {
      throw ArgumentError.value(
        verse,
        'verse',
        'must be the verse value loaded by this Bible edition',
      );
    }
    return BibleVerseKey.fromVerse(editionId, verse);
  }

  /// Create an edition-aware persisted-state key for a verse location.
  BibleVerseKey keyForLocation(BibleLocation location) {
    final verse = getVerseAt(location);
    return keyForVerse(verse);
  }

  /// Format a loaded chapter or verse using this edition's book name by
  /// default, with localized reference-package names available as a fallback.
  String formatLocation(
    BibleLocation location, {
    BibleLanguageEnum? outputLanguage,
    ReferenceBookNameStyle bookNameStyle = ReferenceBookNameStyle.long,
    bool preferEditionBookName = true,
  }) {
    if (location.verse == null) {
      getChapterAt(location);
    } else {
      getVerseAt(location);
    }
    final bookName =
        preferEditionBookName && bookNameStyle == ReferenceBookNameStyle.long
            ? getBook(location.book).name
            : ReferenceFormatter(
                language: outputLanguage ?? language,
                bookNameStyle: bookNameStyle,
              ).formatBookName(location.book);
    final verseNumber = location.verse;
    return verseNumber == null
        ? '$bookName ${location.chapter}'
        : '$bookName ${location.chapter}:$verseNumber';
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

    for (var nextBookIndex = bookIndex + 1;
        nextBookIndex < books.length;
        nextBookIndex++) {
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

    for (var previousBookIndex = bookIndex - 1;
        previousBookIndex >= 0;
        previousBookIndex--) {
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

  /// Return the next declared verse location, including across sparse chapter
  /// and book boundaries, or null at the end of the edition.
  BibleLocation? nextVerse(BibleLocation current) {
    final currentVerse = getVerseAt(current);
    final bookIndex = _bookIndexOf(current.book);
    final chapter = getChapterAt(current);
    final verseIndex = chapter.verses.indexOf(currentVerse);
    if (verseIndex + 1 < chapter.verses.length) {
      return chapter.verses[verseIndex + 1].location;
    }

    final chapterIndex = books[bookIndex].chapters.indexOf(chapter);
    for (var index = chapterIndex + 1;
        index < books[bookIndex].chapters.length;
        index++) {
      final nextChapter = books[bookIndex].chapters[index];
      if (nextChapter.verses.isNotEmpty) {
        return nextChapter.verses.first.location;
      }
    }
    for (var index = bookIndex + 1; index < books.length; index++) {
      for (final nextChapter in books[index].chapters) {
        if (nextChapter.verses.isNotEmpty) {
          return nextChapter.verses.first.location;
        }
      }
    }
    return null;
  }

  /// Return the previous declared verse location, or null at the beginning.
  BibleLocation? previousVerse(BibleLocation current) {
    final currentVerse = getVerseAt(current);
    final bookIndex = _bookIndexOf(current.book);
    final chapter = getChapterAt(current);
    final verseIndex = chapter.verses.indexOf(currentVerse);
    if (verseIndex > 0) return chapter.verses[verseIndex - 1].location;

    final chapterIndex = books[bookIndex].chapters.indexOf(chapter);
    for (var index = chapterIndex - 1; index >= 0; index--) {
      final previousChapter = books[bookIndex].chapters[index];
      if (previousChapter.verses.isNotEmpty) {
        return previousChapter.verses.last.location;
      }
    }
    for (var index = bookIndex - 1; index >= 0; index--) {
      for (final previousChapter in books[index].chapters.reversed) {
        if (previousChapter.verses.isNotEmpty) {
          return previousChapter.verses.last.location;
        }
      }
    }
    return null;
  }

  bool hasNextVerse(BibleLocation current) => nextVerse(current) != null;

  bool hasPreviousVerse(BibleLocation current) =>
      previousVerse(current) != null;

  /// Search for verses containing all tokenized terms in [query].
  ///
  /// This is a term search, not an exact phrase search. For phrase matching,
  /// use [searchAdvanced] with [SearchMode.exact].
  List<Verse> search(String query) {
    final tokens = tokenizeSearchText(query);
    if (tokens.isEmpty) {
      return const [];
    }
    final options = SearchOptions(mode: SearchMode.all);
    final candidates = _searchCandidates(query, options);
    return List<Verse>.unmodifiable(
      candidates.where(
        (verse) => matchesSearchText(verse.text, query, options),
      ),
    );
  }

  /// Build the retained search index now when indexing is enabled.
  void prewarmSearchIndex() {
    if (searchIndexMode != SearchIndexMode.disabled) {
      _searchIndex ??= _buildSearchIndex();
    }
  }

  /// Build the retained search index outside the caller isolate when native
  /// isolates are available.
  Future<void> prewarmSearchIndexAsync() async {
    if (searchIndexMode == SearchIndexMode.disabled || _searchIndex != null) {
      return;
    }
    final index = await background_runner.runBibleTask(_buildSearchIndex);
    if (searchIndexMode != SearchIndexMode.disabled) {
      _searchIndex ??= index;
    }
  }

  /// Release the retained search index. A lazy/eager edition rebuilds it on
  /// the next index-compatible search; a disabled edition keeps scanning.
  void clearSearchIndex() {
    _searchIndex = null;
  }

  /// Rebuild the cached index immediately.
  @Deprecated(
    'Bible values are immutable; use clearSearchIndex or prewarmSearchIndex.',
  )
  void invalidateSearchIndex() {
    clearSearchIndex();
    prewarmSearchIndex();
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
    int offset = 0,
    bool normalizeUnicode = true,
    bool ignoreDiacritics = false,
  }) {
    return searchWithOptions(
      text ?? '',
      SearchOptions(
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
      ),
    );
  }

  /// Search using a reusable options object.
  SearchResults searchWithOptions(String text, SearchOptions options) {
    options.validate();
    final hasText = text.trim().isNotEmpty;
    final candidates =
        hasText ? _searchCandidates(text, options) : _versesForScope(options);
    final matches = hasText
        ? candidates.where(
            (verse) => matchesSearchText(verse.text, text, options),
          )
        : candidates;
    final page = _collectResultPage(
      matches,
      offset: options.offset,
      limit: options.maxResults,
    );
    final hits = page.verses
        .map((verse) => _buildSearchHit(verse, text, options, hasText: hasText))
        .toList(growable: false);

    return SearchResults.fromHits(
      text,
      hits,
      offset: options.offset,
      limit: options.maxResults,
      totalCount: page.totalCount,
      hasMore: page.hasMore,
    );
  }

  /// Fetch a book by enumeration identifier (Result-based).
  Result<Book> getBookResult(BibleBookEnum book) {
    try {
      return Result.success(getBook(book));
    } on Object catch (error, stackTrace) {
      return Result.failureFrom(error, stackTrace);
    }
  }

  /// Fetch a book by its 1-based index position (Result-based).
  Result<Book> getBookByIdResult(int bookNumber) {
    try {
      return Result.success(getBookById(bookNumber));
    } on Object catch (error, stackTrace) {
      return Result.failureFrom(error, stackTrace);
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
    } on Object catch (error, stackTrace) {
      return Result.failureFrom(error, stackTrace);
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
    } on Object catch (error, stackTrace) {
      return Result.failureFrom(error, stackTrace);
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
    } on Object catch (error, stackTrace) {
      return Result.failureFrom(error, stackTrace);
    }
  }

  /// Parse or resolve a rich passage without throwing (Result-based).
  Result<List<Verse>> getPassageResult(
    Object passage, {
    BibleLanguageEnum? inputLanguage,
  }) {
    try {
      return Result.success(getPassage(passage, inputLanguage: inputLanguage));
    } on Object catch (error, stackTrace) {
      return Result.failureFrom(error, stackTrace);
    }
  }

  Map<String, List<Verse>> _buildSearchIndex() {
    final index = <String, List<Verse>>{};
    for (final book in books) {
      for (final chapter in book.chapters) {
        for (final verse in chapter.verses) {
          for (final term in buildSearchIndexTerms(verse.text)) {
            index.putIfAbsent(term, () => []).add(verse);
          }
        }
      }
    }
    return _freezeSearchIndex(index);
  }

  static Map<String, List<Verse>> _freezeSearchIndex(
    Map<String, List<Verse>> index,
  ) {
    return Map<String, List<Verse>>.unmodifiable({
      for (final entry in index.entries)
        entry.key: List<Verse>.unmodifiable(entry.value),
    });
  }

  Map<String, List<Verse>>? _indexFor(SearchOptions options) {
    if (!canUseDefaultSearchIndex(options) ||
        searchIndexMode == SearchIndexMode.disabled) {
      return null;
    }
    return _searchIndex ??= _buildSearchIndex();
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

    final index = _indexFor(options);
    if (index == null) return _versesForScope(options);

    final tokens = tokenizeSearchText(text);
    if (tokens.isEmpty) {
      return const <Verse>[];
    }

    final uniqueTokens = tokens.map(searchIndexLookupKey).toSet();
    for (final token in uniqueTokens) {
      if (!index.containsKey(token)) {
        return const <Verse>[];
      }
    }

    String? rarestToken;
    for (final token in uniqueTokens) {
      final matches = index[token];
      if (matches == null) {
        continue;
      }
      if (rarestToken == null || matches.length < index[rarestToken]!.length) {
        rarestToken = token;
      }
    }

    if (rarestToken == null) {
      return null;
    }

    return index[rarestToken]!.where((verse) => _matchesScope(verse, options));
  }

  Iterable<Verse> _indexedTermCandidates(
    String text,
    SearchOptions options, {
    required bool requireAllTerms,
  }) {
    final rawTokens = tokenizeSearchText(
      text,
      caseSensitive: options.caseSensitive,
      normalizeUnicode: options.normalizeUnicode,
      ignoreDiacritics: options.ignoreDiacritics,
    ).toSet();
    final index = _indexFor(options);
    if (index == null) return _versesForScope(options);
    final tokens = rawTokens.map(searchIndexLookupKey).toSet();
    if (tokens.isEmpty) {
      return const <Verse>[];
    }

    if (requireAllTerms) {
      final tokenMatchesByToken = <String, List<Verse>>{};
      String? rarestToken;
      for (final token in tokens) {
        final tokenMatches = index[token];
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
      matches.addAll(index[token] ?? const <Verse>[]);
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

  static _SearchPage _collectResultPage(
    Iterable<Verse> matches, {
    required int offset,
    required int? limit,
  }) {
    final verses = <Verse>[];
    var matchedCount = 0;
    var skippedCount = 0;
    var hasMore = false;
    for (final match in matches) {
      matchedCount++;
      if (skippedCount < offset) {
        skippedCount++;
        continue;
      }
      if (limit != null && verses.length >= limit) {
        hasMore = true;
        break;
      }
      verses.add(match);
    }
    return _SearchPage(
      List<Verse>.unmodifiable(verses),
      hasMore: hasMore,
      totalCount: hasMore ? null : matchedCount,
    );
  }

  SearchHit _buildSearchHit(
    Verse verse,
    String query,
    SearchOptions options, {
    required bool hasText,
  }) {
    final ranges = hasText
        ? findSearchMatchRanges(verse.text, query, options)
        : const <TextRange>[];
    return SearchHit.withContext(
      verse: verse,
      book: getBook(verse.book),
      matchRanges: ranges,
    );
  }

  /// Export the Bible data to JSON string.
  String toJson() {
    return json.encode({
      ...annotations,
      'schemaVersion': schemaVersion,
      'language': language.name,
      'metadata': metadata.toJson(),
      'bookOrder': [for (final book in books) book.bookEnum.abbreviation],
      'books': {
        for (final book in books)
          book.bookEnum.abbreviation: book.toJsonValue(),
      },
    });
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Bible &&
            other.schemaVersion == schemaVersion &&
            other.language == language &&
            other.metadata == metadata &&
            jsonValueEquals(other.books, books) &&
            jsonValueEquals(other.annotations, annotations);
  }

  @override
  int get hashCode => Object.hash(
        schemaVersion,
        language,
        metadata,
        Object.hashAll(books),
        jsonValueHash(annotations),
      );
}

class _SearchPage {
  final List<Verse> verses;
  final bool hasMore;
  final int? totalCount;

  const _SearchPage(
    this.verses, {
    required this.hasMore,
    required this.totalCount,
  });
}

Map<String, List<Verse>> _freezeInitializationSearchIndex(
  Map<String, List<Verse>> index,
) {
  return Map<String, List<Verse>>.unmodifiable({
    for (final entry in index.entries)
      entry.key: List<Verse>.unmodifiable(entry.value),
  });
}

const Set<String> _rootDocumentFields = {
  'schemaVersion',
  'bookOrder',
  'books',
  'metadata',
  'source',
  'id',
  'editionId',
  'edition_id',
  'description',
  'summary',
  'language',
  'languageName',
  'language_name',
  'languageCode',
  'language_code',
  'lang',
  'translationName',
  'translation_name',
  'name',
  'title',
  'version',
  'abbreviation',
  'abbr',
  'shortName',
  'short_name',
  'year',
  'direction',
  'textDirection',
  'text_direction',
  'sourceName',
  'source_name',
  'copyright',
  'license',
  'canon',
  'versionDate',
  'version_date',
  'date',
};

final RegExp _simpleJsonPathKey = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
final RegExp _rangeSeparatorPattern = RegExp(r'[-\u2013\u2014\u2015]');

Map<String, dynamic> _stringKeyedMap(Map value, String path) {
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.nonJsonValue,
        path: path,
        message: 'JSON object keys must be strings.',
        value: key,
      );
    }
    result[key] = entry.value;
  }
  return result;
}

String _jsonPropertyPath(String base, String key) {
  if (_simpleJsonPathKey.hasMatch(key)) return '$base.$key';
  return '$base[${json.encode(key)}]';
}
