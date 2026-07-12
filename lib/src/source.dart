import 'dart:convert';

import 'package:bible_io_references/bible_io_references.dart';

import 'errors.dart';

const Object _unset = Object();

/// Text direction hint for Scripture text and labels.
enum TextDirectionHint {
  auto,
  ltr,
  rtl;

  static TextDirectionHint fromString(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'ltr':
      case 'left-to-right':
      case 'left_to_right':
        return TextDirectionHint.ltr;
      case 'rtl':
      case 'right-to-left':
      case 'right_to_left':
        return TextDirectionHint.rtl;
      default:
        return TextDirectionHint.auto;
    }
  }
}

/// Metadata for a Bible source that can be shown in a picker or catalog.
class BibleSource {
  final String id;
  final String assetPath;
  final String languageName;
  final String languageCode;
  final String translationName;
  final String abbreviation;
  final String? description;
  final int? year;
  final TextDirectionHint direction;
  final String? sourceName;
  final String? copyright;
  final String? license;
  final String? canon;
  final DateTime? versionDate;
  final Map<String, Object?> _additional;

  /// Unknown, JSON-compatible source fields preserved during round trips.
  Map<String, Object?> get additional => _additional;

  /// Creates a source value directly.
  ///
  /// This constructor remains const for declaration-style catalogs. Use
  /// [BibleSource.checked] or [validate] when values are produced at runtime.
  const BibleSource({
    required this.id,
    required this.assetPath,
    required this.languageName,
    required this.languageCode,
    required this.translationName,
    required this.abbreviation,
    this.description,
    this.year,
    this.direction = TextDirectionHint.auto,
    this.sourceName,
    this.copyright,
    this.license,
    this.canon,
    this.versionDate,
  }) : _additional = const {};

  const BibleSource._({
    required this.id,
    required this.assetPath,
    required this.languageName,
    required this.languageCode,
    required this.translationName,
    required this.abbreviation,
    this.description,
    this.year,
    this.direction = TextDirectionHint.auto,
    this.sourceName,
    this.copyright,
    this.license,
    this.canon,
    this.versionDate,
    required Map<String, Object?> additional,
  }) : _additional = additional;

  /// Creates and validates a source whose required strings are runtime data.
  factory BibleSource.checked({
    required String id,
    required String assetPath,
    required String languageName,
    required String languageCode,
    required String translationName,
    required String abbreviation,
    String? description,
    int? year,
    TextDirectionHint direction = TextDirectionHint.auto,
    String? sourceName,
    String? copyright,
    String? license,
    String? canon,
    DateTime? versionDate,
    Map<String, Object?> additional = const {},
    String path = r'$',
  }) {
    return BibleSource._(
      id: id,
      assetPath: assetPath,
      languageName: languageName,
      languageCode: languageCode,
      translationName: translationName,
      abbreviation: abbreviation,
      description: description,
      year: year,
      direction: direction,
      sourceName: sourceName,
      copyright: copyright,
      license: license,
      canon: canon,
      versionDate: versionDate,
      additional: _freezeAdditional(additional, path: path),
    ).validate(path: path);
  }

  factory BibleSource.fromAssetPath(
    String assetPath, {
    String? id,
    String? languageName,
    String? languageCode,
    String? translationName,
    String? abbreviation,
    int? year,
    TextDirectionHint? direction,
  }) {
    final normalizedPath = assetPath.replaceAll('\\', '/');
    final segments = normalizedPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    final fileName = segments.isEmpty ? normalizedPath : segments.last;
    final dotIndex = fileName.lastIndexOf('.');
    final fileBase =
        dotIndex == -1 ? fileName : fileName.substring(0, dotIndex);
    final inferredLanguage = languageName ??
        (segments.length > 1
            ? _labelFromSegment(segments[segments.length - 2])
            : '');
    final inferredCode =
        languageCode ?? _languageCodeForName(inferredLanguage) ?? '';
    final inferredAbbreviation = abbreviation ?? fileBase.toUpperCase();
    final inferredTranslation =
        translationName ?? _labelFromSegment(fileBase).toUpperCase();
    final inferredDirection =
        direction ?? _directionForLanguageCode(inferredCode);

    return BibleSource(
      id: id ??
          _sanitizeId(
            [
              inferredLanguage,
              inferredAbbreviation,
            ].where((part) => part.isNotEmpty).join('_'),
          ),
      assetPath: assetPath,
      languageName: inferredLanguage,
      languageCode: inferredCode,
      translationName: inferredTranslation,
      abbreviation: inferredAbbreviation,
      year: year,
      direction: inferredDirection,
    );
  }

  factory BibleSource.fromDecodedJson(
    Map<String, dynamic> json, {
    String path = r'$',
  }) {
    final assetPath = _readString(
            json,
            const [
              'assetPath',
              'asset_path',
              'path',
              'file',
              'url',
            ],
            path: path) ??
        '';
    final fallback =
        assetPath.isEmpty ? null : BibleSource.fromAssetPath(assetPath);
    final languageName = _readString(
            json,
            const [
              'languageName',
              'language_name',
              'language',
            ],
            path: path) ??
        fallback?.languageName ??
        '';
    final languageCode = _readString(
            json,
            const [
              'languageCode',
              'language_code',
              'lang',
            ],
            path: path) ??
        fallback?.languageCode ??
        _languageCodeForName(languageName) ??
        '';
    final abbreviation = _readString(
            json,
            const [
              'abbreviation',
              'abbr',
              'shortName',
              'short_name',
            ],
            path: path) ??
        fallback?.abbreviation ??
        '';
    final translationName = _readString(
            json,
            const [
              'translationName',
              'translation_name',
              'name',
              'title',
              'version',
            ],
            path: path) ??
        fallback?.translationName ??
        abbreviation;
    final direction = _readDirection(json, path: path) ??
        fallback?.direction ??
        _directionForLanguageCode(languageCode);
    final additional = <String, Object?>{};
    _addUnknownFields(additional, json, _sourceRecognizedKeys);

    return BibleSource.checked(
      id: _readIdentifier(json, const ['id', 'key'], path: path) ??
          fallback?.id ??
          _sanitizeId('${languageName}_$abbreviation'),
      assetPath: assetPath,
      languageName: languageName,
      languageCode: languageCode,
      translationName: translationName,
      abbreviation: abbreviation,
      description: _readString(
          json,
          const [
            'description',
            'summary',
          ],
          path: path),
      year: _readInt(json, const ['year'], path: path),
      direction: direction,
      sourceName: _readString(
          json,
          const [
            'sourceName',
            'source_name',
            'source',
          ],
          path: path),
      copyright: _readString(json, const ['copyright'], path: path),
      license: _readString(json, const ['license'], path: path),
      canon: _readString(json, const ['canon'], path: path),
      versionDate: _readDateTime(
          json,
          const [
            'versionDate',
            'version_date',
            'date',
          ],
          path: path),
      additional: additional,
      path: path,
    );
  }

  /// Validates all non-nullable source fields and returns this source.
  BibleSource validate({String path = r'$'}) {
    _validateRequiredString(id, 'id', path, identifier: true);
    _validateRequiredString(assetPath, 'assetPath', path);
    _validateRequiredString(languageName, 'languageName', path);
    _validateRequiredString(languageCode, 'languageCode', path);
    _validateRequiredString(translationName, 'translationName', path);
    _validateRequiredString(abbreviation, 'abbreviation', path);
    return this;
  }

  BibleSource copyWith({
    String? id,
    String? assetPath,
    String? languageName,
    String? languageCode,
    String? translationName,
    String? abbreviation,
    Object? description = _unset,
    Object? year = _unset,
    TextDirectionHint? direction,
    Object? sourceName = _unset,
    Object? copyright = _unset,
    Object? license = _unset,
    Object? canon = _unset,
    Object? versionDate = _unset,
    Map<String, Object?>? additional,
  }) {
    return BibleSource.checked(
      id: id ?? this.id,
      assetPath: assetPath ?? this.assetPath,
      languageName: languageName ?? this.languageName,
      languageCode: languageCode ?? this.languageCode,
      translationName: translationName ?? this.translationName,
      abbreviation: abbreviation ?? this.abbreviation,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      year: identical(year, _unset) ? this.year : year as int?,
      direction: direction ?? this.direction,
      sourceName: identical(sourceName, _unset)
          ? this.sourceName
          : sourceName as String?,
      copyright:
          identical(copyright, _unset) ? this.copyright : copyright as String?,
      license: identical(license, _unset) ? this.license : license as String?,
      canon: identical(canon, _unset) ? this.canon : canon as String?,
      versionDate: identical(versionDate, _unset)
          ? this.versionDate
          : versionDate as DateTime?,
      additional: additional ?? this.additional,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...additional,
      'id': id,
      'assetPath': assetPath,
      'languageName': languageName,
      'languageCode': languageCode,
      'translationName': translationName,
      'abbreviation': abbreviation,
      if (description != null) 'description': description,
      if (year != null) 'year': year,
      'direction': direction.name,
      if (sourceName != null) 'sourceName': sourceName,
      if (copyright != null) 'copyright': copyright,
      if (license != null) 'license': license,
      if (canon != null) 'canon': canon,
      if (versionDate != null) 'versionDate': versionDate!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BibleSource &&
            id == other.id &&
            assetPath == other.assetPath &&
            languageName == other.languageName &&
            languageCode == other.languageCode &&
            translationName == other.translationName &&
            abbreviation == other.abbreviation &&
            description == other.description &&
            year == other.year &&
            direction == other.direction &&
            sourceName == other.sourceName &&
            copyright == other.copyright &&
            license == other.license &&
            canon == other.canon &&
            versionDate == other.versionDate &&
            _deepEquals(additional, other.additional);
  }

  @override
  int get hashCode => Object.hash(
        id,
        assetPath,
        languageName,
        languageCode,
        translationName,
        abbreviation,
        description,
        year,
        direction,
        sourceName,
        copyright,
        license,
        canon,
        versionDate,
        _deepHash(additional),
      );
}

/// Metadata attached to a loaded Bible instance.
class BibleMetadata {
  final BibleSource? source;
  final String? id;
  final String? description;
  final String? languageName;
  final String? languageCode;
  final String? translationName;
  final String? abbreviation;
  final int? year;
  final TextDirectionHint direction;
  final String? sourceName;
  final String? copyright;
  final String? license;
  final String? canon;
  final DateTime? versionDate;
  final Map<String, Object?> _additional;

  /// Unknown, JSON-compatible metadata fields preserved during round trips.
  ///
  /// The map and all nested maps and lists are deeply immutable.
  Map<String, Object?> get additional => _additional;

  /// Creates metadata without extension fields and remains const-compatible.
  const BibleMetadata({
    this.source,
    this.id,
    this.description,
    this.languageName,
    this.languageCode,
    this.translationName,
    this.abbreviation,
    this.year,
    this.direction = TextDirectionHint.auto,
    this.sourceName,
    this.copyright,
    this.license,
    this.canon,
    this.versionDate,
  }) : _additional = const {};

  const BibleMetadata._({
    this.source,
    this.id,
    this.description,
    this.languageName,
    this.languageCode,
    this.translationName,
    this.abbreviation,
    this.year,
    this.direction = TextDirectionHint.auto,
    this.sourceName,
    this.copyright,
    this.license,
    this.canon,
    this.versionDate,
    required Map<String, Object?> additional,
  }) : _additional = additional;

  /// Creates metadata with deeply immutable JSON-compatible extension fields.
  factory BibleMetadata.withAdditional({
    BibleSource? source,
    String? id,
    String? description,
    String? languageName,
    String? languageCode,
    String? translationName,
    String? abbreviation,
    int? year,
    TextDirectionHint direction = TextDirectionHint.auto,
    String? sourceName,
    String? copyright,
    String? license,
    String? canon,
    DateTime? versionDate,
    Map<String, Object?> additional = const {},
    String path = r'$.metadata',
  }) {
    source?.validate(path: _fieldPath(path, 'source'));
    if (id != null && (id.trim().isEmpty || id != id.trim())) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: _fieldPath(path, 'id'),
        message:
            'Edition IDs must be non-blank and have no surrounding whitespace.',
        value: id,
      );
    }
    return BibleMetadata._(
      source: source,
      id: id,
      description: description,
      languageName: languageName,
      languageCode: languageCode,
      translationName: translationName,
      abbreviation: abbreviation,
      year: year,
      direction: direction,
      sourceName: sourceName,
      copyright: copyright,
      license: license,
      canon: canon,
      versionDate: versionDate,
      additional: _freezeAdditional(additional, path: path),
    );
  }

  factory BibleMetadata.fromDecodedJson(
    Map<String, dynamic> json, {
    BibleSource? source,
  }) {
    final metadata = _readObjectField(json, 'metadata', path: r'$');
    final metadataSource = metadata == null
        ? null
        : _readObjectField(metadata, 'source', path: r'$.metadata');
    final rootSource = _readObjectField(json, 'source', path: r'$');
    final sourceMap = metadataSource ?? rootSource;
    final sourcePath =
        metadataSource != null ? r'$.metadata.source' : r'$.source';
    final embeddedSource = sourceMap == null
        ? null
        : BibleSource.fromDecodedJson(sourceMap, path: sourcePath);
    final parsedSource = source ?? embeddedSource;

    String? read(Iterable<String> keys) {
      return _readString(metadata, keys, path: r'$.metadata') ??
          _readString(json, keys, path: r'$');
    }

    int? readInt(Iterable<String> keys) {
      return _readInt(metadata, keys, path: r'$.metadata') ??
          _readInt(json, keys, path: r'$');
    }

    DateTime? readDate(Iterable<String> keys) {
      return _readDateTime(metadata, keys, path: r'$.metadata') ??
          _readDateTime(json, keys, path: r'$');
    }

    final languageName =
        read(const ['languageName', 'language_name', 'language']) ??
            parsedSource?.languageName;
    final languageCode =
        read(const ['languageCode', 'language_code', 'lang']) ??
            parsedSource?.languageCode;
    final direction = _readDirection(metadata, path: r'$.metadata') ??
        _readDirection(json, path: r'$') ??
        parsedSource?.direction ??
        _directionForLanguageCode(languageCode ?? '');

    final additional = <String, Object?>{};
    _addUnknownFields(additional, json, _rootRecognizedKeys);
    _addUnknownFields(additional, metadata, _metadataRecognizedKeys);

    return BibleMetadata.withAdditional(
      source: parsedSource,
      id: _readIdentifier(
            metadata,
            const ['id', 'editionId', 'edition_id'],
            path: r'$.metadata',
          ) ??
          _readIdentifier(
            json,
            const ['id', 'editionId', 'edition_id'],
            path: r'$',
          ) ??
          parsedSource?.id,
      description:
          read(const ['description', 'summary']) ?? parsedSource?.description,
      languageName: languageName,
      languageCode: languageCode,
      translationName: read(const [
            'translationName',
            'translation_name',
            'name',
            'title',
            'version',
          ]) ??
          parsedSource?.translationName,
      abbreviation:
          read(const ['abbreviation', 'abbr', 'shortName', 'short_name']) ??
              parsedSource?.abbreviation,
      year: readInt(const ['year']) ?? parsedSource?.year,
      direction: direction,
      sourceName:
          read(const ['sourceName', 'source_name']) ?? parsedSource?.sourceName,
      copyright: read(const ['copyright']) ?? parsedSource?.copyright,
      license: read(const ['license']) ?? parsedSource?.license,
      canon: read(const ['canon']) ?? parsedSource?.canon,
      versionDate: readDate(const ['versionDate', 'version_date', 'date']) ??
          parsedSource?.versionDate,
      additional: additional,
    );
  }

  BibleMetadata copyWith({
    Object? source = _unset,
    Object? id = _unset,
    Object? description = _unset,
    Object? languageName = _unset,
    Object? languageCode = _unset,
    Object? translationName = _unset,
    Object? abbreviation = _unset,
    Object? year = _unset,
    TextDirectionHint? direction,
    Object? sourceName = _unset,
    Object? copyright = _unset,
    Object? license = _unset,
    Object? canon = _unset,
    Object? versionDate = _unset,
    Map<String, Object?>? additional,
  }) {
    return BibleMetadata.withAdditional(
      source: identical(source, _unset) ? this.source : source as BibleSource?,
      id: identical(id, _unset) ? this.id : id as String?,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      languageName: identical(languageName, _unset)
          ? this.languageName
          : languageName as String?,
      languageCode: identical(languageCode, _unset)
          ? this.languageCode
          : languageCode as String?,
      translationName: identical(translationName, _unset)
          ? this.translationName
          : translationName as String?,
      abbreviation: identical(abbreviation, _unset)
          ? this.abbreviation
          : abbreviation as String?,
      year: identical(year, _unset) ? this.year : year as int?,
      direction: direction ?? this.direction,
      sourceName: identical(sourceName, _unset)
          ? this.sourceName
          : sourceName as String?,
      copyright:
          identical(copyright, _unset) ? this.copyright : copyright as String?,
      license: identical(license, _unset) ? this.license : license as String?,
      canon: identical(canon, _unset) ? this.canon : canon as String?,
      versionDate: identical(versionDate, _unset)
          ? this.versionDate
          : versionDate as DateTime?,
      additional: additional ?? this.additional,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...additional,
      if (source != null) 'source': source!.toJson(),
      if (id != null) 'id': id,
      if (description != null) 'description': description,
      if (languageName != null) 'languageName': languageName,
      if (languageCode != null) 'languageCode': languageCode,
      if (translationName != null) 'translationName': translationName,
      if (abbreviation != null) 'abbreviation': abbreviation,
      if (year != null) 'year': year,
      'direction': direction.name,
      if (sourceName != null) 'sourceName': sourceName,
      if (copyright != null) 'copyright': copyright,
      if (license != null) 'license': license,
      if (canon != null) 'canon': canon,
      if (versionDate != null) 'versionDate': versionDate!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BibleMetadata &&
            source == other.source &&
            id == other.id &&
            description == other.description &&
            languageName == other.languageName &&
            languageCode == other.languageCode &&
            translationName == other.translationName &&
            abbreviation == other.abbreviation &&
            year == other.year &&
            direction == other.direction &&
            sourceName == other.sourceName &&
            copyright == other.copyright &&
            license == other.license &&
            canon == other.canon &&
            versionDate == other.versionDate &&
            _deepEquals(additional, other.additional);
  }

  @override
  int get hashCode => Object.hash(
        source,
        id,
        description,
        languageName,
        languageCode,
        translationName,
        abbreviation,
        year,
        direction,
        sourceName,
        copyright,
        license,
        canon,
        versionDate,
        _deepHash(additional),
      );
}

/// Merges explicit metadata, source data, and language fallbacks.
///
/// Field precedence is explicit [metadata], then the explicit [source] (or the
/// source already attached to metadata), then the supplied language fallbacks.
/// An `auto` metadata direction is treated as unspecified when a source has a
/// concrete direction.
BibleMetadata mergeBibleMetadata({
  BibleMetadata? metadata,
  BibleSource? source,
  String? fallbackLanguageName,
  String? fallbackLanguageCode,
}) {
  final effectiveSource = source ?? metadata?.source;
  final metadataDirection = metadata?.direction;
  final direction =
      metadataDirection != null && metadataDirection != TextDirectionHint.auto
          ? metadataDirection
          : effectiveSource?.direction ??
              metadataDirection ??
              _directionForLanguageCode(
                metadata?.languageCode ??
                    effectiveSource?.languageCode ??
                    fallbackLanguageCode ??
                    '',
              );

  return BibleMetadata.withAdditional(
    source: effectiveSource,
    id: metadata?.id ?? effectiveSource?.id,
    description: metadata?.description ?? effectiveSource?.description,
    languageName: metadata?.languageName ??
        effectiveSource?.languageName ??
        fallbackLanguageName,
    languageCode: metadata?.languageCode ??
        effectiveSource?.languageCode ??
        fallbackLanguageCode,
    translationName:
        metadata?.translationName ?? effectiveSource?.translationName,
    abbreviation: metadata?.abbreviation ?? effectiveSource?.abbreviation,
    year: metadata?.year ?? effectiveSource?.year,
    direction: direction,
    sourceName: metadata?.sourceName ?? effectiveSource?.sourceName,
    copyright: metadata?.copyright ?? effectiveSource?.copyright,
    license: metadata?.license ?? effectiveSource?.license,
    canon: metadata?.canon ?? effectiveSource?.canon,
    versionDate: metadata?.versionDate ?? effectiveSource?.versionDate,
    additional: metadata?.additional ?? const {},
  );
}

/// Collection of available Bible sources.
class BibleCatalog {
  final List<BibleSource> sources;
  final Map<String, BibleSource> _sourcesById;

  BibleCatalog(Iterable<BibleSource> sources)
      : this._fromData(_BibleCatalogData.validate(sources));

  BibleCatalog._fromData(_BibleCatalogData data)
      : sources = data.sources,
        _sourcesById = data.sourcesById;

  factory BibleCatalog.fromJson(String jsonString) {
    try {
      return BibleCatalog.fromDecodedJson(json.decode(jsonString));
    } on BibleDataFormatError {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidJson,
        path: r'$',
        message: 'Catalog is not valid JSON.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  factory BibleCatalog.fromUtf8Bytes(List<int> bytes) {
    try {
      return BibleCatalog.fromJson(utf8.decode(bytes));
    } on BibleDataFormatError {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidJson,
        path: r'$',
        message: 'Catalog is not valid UTF-8 JSON.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  factory BibleCatalog.fromDecodedJson(Object? data) {
    return BibleCatalog(_parseSources(data));
  }

  static Future<BibleCatalog> loadAsset(dynamic assetBundle, String key) async {
    final content = await assetBundle.loadString(key);
    if (content is! String) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: r'$',
        message: 'Asset bundle loadString must return a String.',
        value: content,
      );
    }
    return BibleCatalog.fromJson(content);
  }

  BibleSource? findById(String id) => _sourcesById[id];

  List<BibleSource> forLanguage(String languageNameOrCode) {
    final normalized = languageNameOrCode.trim().toLowerCase();
    return List.unmodifiable(
      sources.where(
        (source) =>
            source.languageName.toLowerCase() == normalized ||
            source.languageCode.toLowerCase() == normalized,
      ),
    );
  }

  Map<String, List<BibleSource>> get byLanguageName {
    final grouped = <String, List<BibleSource>>{};
    for (final source in sources) {
      grouped.putIfAbsent(source.languageName, () => []).add(source);
    }
    return Map.unmodifiable({
      for (final entry in grouped.entries)
        entry.key: List.unmodifiable(entry.value),
    });
  }

  static List<BibleSource> _parseSources(
    Object? data, {
    String? languageName,
    String path = r'$',
    bool expectSource = false,
  }) {
    if (data is String) {
      if (data.trim().isEmpty) {
        throw BibleDataFormatError(
          code: BibleDataFormatErrorCode.invalidValue,
          path: path,
          message: 'Bible source asset path cannot be blank.',
          value: data,
        );
      }
      return [
        BibleSource.fromAssetPath(
          data,
          languageName: languageName,
        ).validate(path: path),
      ];
    }
    if (data is List) {
      return [
        for (var index = 0; index < data.length; index++)
          ..._parseSources(
            data[index],
            languageName: languageName,
            path: '$path[$index]',
            expectSource: true,
          ),
      ];
    }
    if (data is! Map) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: path,
        message: 'Catalog entries must be source objects, lists, or paths.',
        value: data,
      );
    }
    final map = _asJsonObject(data, path: path);

    if (expectSource || _looksLikeSourceCandidate(map)) {
      if (languageName != null) {
        map.putIfAbsent('languageName', () => languageName);
      }
      return [BibleSource.fromDecodedJson(map, path: path)];
    }

    final containers = const [
      'sources',
      'bibles',
      'translations',
    ].where(map.containsKey).toList(growable: false);
    if (containers.length > 1) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: path,
        message: 'Catalog must use only one source container key.',
        value: containers,
      );
    }
    if (containers.isNotEmpty) {
      final key = containers.single;
      return _parseSources(
        map[key],
        languageName: languageName,
        path: _fieldPath(path, key),
      );
    }

    final parsed = <BibleSource>[];
    for (final entry in map.entries) {
      final entryPath = _fieldPath(path, entry.key);
      final value = entry.value;
      if (value is String) {
        if (value.trim().isEmpty) {
          throw BibleDataFormatError(
            code: BibleDataFormatErrorCode.invalidValue,
            path: entryPath,
            message: 'Bible source asset path cannot be blank.',
            value: value,
          );
        }
        parsed.add(
          BibleSource.fromAssetPath(
            value,
            id: entry.key,
            languageName: languageName,
          ).validate(path: entryPath),
        );
        continue;
      }
      if (value is List) {
        parsed.addAll(
          _parseSources(
            value,
            languageName: languageName ?? entry.key,
            path: entryPath,
          ),
        );
        continue;
      }
      if (value is Map) {
        final sourceMap = _asJsonObject(value, path: entryPath);
        if (_looksLikeSourceCandidate(sourceMap)) {
          sourceMap.putIfAbsent('id', () => entry.key);
          if (languageName != null) {
            sourceMap.putIfAbsent('languageName', () => languageName);
          }
          parsed.add(BibleSource.fromDecodedJson(sourceMap, path: entryPath));
        } else {
          parsed.addAll(
            _parseSources(
              sourceMap,
              languageName: languageName ?? entry.key,
              path: entryPath,
            ),
          );
        }
        continue;
      }
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: entryPath,
        message: 'Catalog entry must be a source object, list, or path.',
        value: value,
      );
    }
    return parsed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleCatalog && _deepEquals(sources, other.sources);

  @override
  int get hashCode => Object.hashAll(sources);
}

class _BibleCatalogData {
  final List<BibleSource> sources;
  final Map<String, BibleSource> sourcesById;

  const _BibleCatalogData(this.sources, this.sourcesById);

  factory _BibleCatalogData.validate(Iterable<BibleSource> sources) {
    final sourceList = List<BibleSource>.unmodifiable(sources);
    final byId = <String, BibleSource>{};
    for (var index = 0; index < sourceList.length; index++) {
      final source = sourceList[index];
      final path = '\$.sources[$index]';
      source.validate(path: path);
      if (byId.containsKey(source.id)) {
        throw BibleDataFormatError(
          code: BibleDataFormatErrorCode.duplicateId,
          path: '$path.id',
          message: 'Bible source IDs must be unique.',
          value: source.id,
        );
      }
      byId[source.id] = source;
    }
    return _BibleCatalogData(sourceList, Map.unmodifiable(byId));
  }
}

const _sourcePathKeys = {'assetPath', 'asset_path', 'path', 'file', 'url'};

const _sourceRecognizedKeys = {
  ..._sourcePathKeys,
  'id',
  'key',
  'languageName',
  'language_name',
  'language',
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
  'description',
  'summary',
  'year',
  'direction',
  'textDirection',
  'text_direction',
  'sourceName',
  'source_name',
  'source',
  'copyright',
  'license',
  'canon',
  'versionDate',
  'version_date',
  'date',
};

const _metadataRecognizedKeys = {
  ..._sourceRecognizedKeys,
  'editionId',
  'edition_id',
};

const _rootRecognizedKeys = {..._metadataRecognizedKeys, 'books', 'metadata'};

bool _looksLikeSourceCandidate(Map<String, dynamic> map) =>
    map.keys.any(_sourceRecognizedKeys.contains);

Map<String, dynamic> _asJsonObject(Object value, {required String path}) {
  if (value is! Map) {
    throw BibleDataFormatError(
      code: BibleDataFormatErrorCode.invalidType,
      path: path,
      message: 'Expected a JSON object.',
      value: value,
    );
  }
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.nonJsonValue,
        path: path,
        message: 'JSON object keys must be strings.',
        value: entry.key,
      );
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

Map<String, dynamic>? _readObjectField(
  Map<String, dynamic> map,
  String key, {
  required String path,
}) {
  if (!map.containsKey(key) || map[key] == null) {
    return null;
  }
  return _asJsonObject(map[key]!, path: _fieldPath(path, key));
}

String? _readIdentifier(
  Map<String, dynamic>? map,
  Iterable<String> keys, {
  required String path,
}) {
  if (map == null) return null;
  for (final key in keys) {
    if (!map.containsKey(key) || map[key] == null) continue;
    final value = map[key];
    if (value is! String) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: _fieldPath(path, key),
        message: 'Expected an identifier string.',
        value: value,
      );
    }
    if (value.trim().isEmpty || value != value.trim()) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: _fieldPath(path, key),
        message:
            'Identifiers must be non-blank and have no surrounding whitespace.',
        value: value,
      );
    }
    return value;
  }
  return null;
}

String? _readString(
  Map<String, dynamic>? map,
  Iterable<String> keys, {
  required String path,
}) {
  if (map == null) {
    return null;
  }
  for (final key in keys) {
    if (!map.containsKey(key) || map[key] == null) {
      continue;
    }
    final value = map[key];
    if (value is! String) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: _fieldPath(path, key),
        message: 'Expected a string.',
        value: value,
      );
    }
    if (value.trim().isEmpty) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: _fieldPath(path, key),
        message: 'String value cannot be blank.',
        value: value,
      );
    }
    return value.trim();
  }
  return null;
}

int? _readInt(
  Map<String, dynamic>? map,
  Iterable<String> keys, {
  required String path,
}) {
  if (map == null) {
    return null;
  }
  for (final key in keys) {
    if (!map.containsKey(key) || map[key] == null) {
      continue;
    }
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: _fieldPath(path, key),
        message: 'Expected an integer value.',
        value: value,
      );
    }
    throw BibleDataFormatError(
      code: BibleDataFormatErrorCode.invalidType,
      path: _fieldPath(path, key),
      message: 'Expected an integer.',
      value: value,
    );
  }
  return null;
}

DateTime? _readDateTime(
  Map<String, dynamic>? map,
  Iterable<String> keys, {
  required String path,
}) {
  final value = _readString(map, keys, path: path);
  if (value == null) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    final actualKey = keys.firstWhere(
      (key) => map!.containsKey(key) && map[key] != null,
    );
    throw BibleDataFormatError(
      code: BibleDataFormatErrorCode.invalidValue,
      path: _fieldPath(path, actualKey),
      message: 'Expected an ISO-8601 date.',
      value: value,
    );
  }
  return parsed;
}

TextDirectionHint? _readDirection(
  Map<String, dynamic>? map, {
  required String path,
}) {
  const keys = ['direction', 'textDirection', 'text_direction'];
  final value = _readString(map, keys, path: path);
  if (value == null) {
    return null;
  }
  switch (value.toLowerCase()) {
    case 'auto':
      return TextDirectionHint.auto;
    case 'ltr':
    case 'left-to-right':
    case 'left_to_right':
      return TextDirectionHint.ltr;
    case 'rtl':
    case 'right-to-left':
    case 'right_to_left':
      return TextDirectionHint.rtl;
    default:
      final actualKey = keys.firstWhere(
        (key) => map!.containsKey(key) && map[key] != null,
      );
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: _fieldPath(path, actualKey),
        message: 'Text direction must be auto, ltr, or rtl.',
        value: value,
      );
  }
}

void _validateRequiredString(
  String value,
  String field,
  String path, {
  bool identifier = false,
}) {
  if (value.trim().isEmpty) {
    throw BibleDataFormatError(
      code: BibleDataFormatErrorCode.missingField,
      path: _fieldPath(path, field),
      message: 'Required Bible source field "$field" cannot be blank.',
      value: value,
    );
  }
  if (identifier && value != value.trim()) {
    throw BibleDataFormatError(
      code: BibleDataFormatErrorCode.invalidValue,
      path: _fieldPath(path, field),
      message: 'Bible source IDs cannot have leading or trailing whitespace.',
      value: value,
    );
  }
}

void _addUnknownFields(
  Map<String, Object?> target,
  Map<String, dynamic>? source,
  Set<String> recognized,
) {
  if (source == null) {
    return;
  }
  for (final entry in source.entries) {
    if (!recognized.contains(entry.key)) {
      target[entry.key] = entry.value;
    }
  }
}

Map<String, Object?> _freezeAdditional(
  Map<String, Object?> values, {
  required String path,
}) {
  final frozen = <String, Object?>{};
  for (final entry in values.entries) {
    if (_metadataRecognizedKeys.contains(entry.key)) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.reservedField,
        path: _fieldPath(path, entry.key),
        message: 'Recognized metadata fields cannot be stored as extensions.',
        value: entry.value,
      );
    }
    frozen[entry.key] = _freezeJsonValue(
      entry.value,
      path: _fieldPath(path, entry.key),
    );
  }
  return Map.unmodifiable(frozen);
}

Object? _freezeJsonValue(Object? value, {required String path}) {
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw BibleDataFormatError(
        code: BibleDataFormatErrorCode.nonJsonValue,
        path: path,
        message: 'JSON numbers must be finite.',
        value: value,
      );
    }
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable([
      for (var index = 0; index < value.length; index++)
        _freezeJsonValue(value[index], path: '$path[$index]'),
    ]);
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw BibleDataFormatError(
          code: BibleDataFormatErrorCode.nonJsonValue,
          path: path,
          message: 'JSON object keys must be strings.',
          value: entry.key,
        );
      }
      result[entry.key as String] = _freezeJsonValue(
        entry.value,
        path: _fieldPath(path, entry.key as String),
      );
    }
    return Map<String, Object?>.unmodifiable(result);
  }
  throw BibleDataFormatError(
    code: BibleDataFormatErrorCode.nonJsonValue,
    path: path,
    message: 'Metadata extensions must contain JSON-compatible values.',
    value: value,
  );
}

bool _deepEquals(Object? left, Object? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (!_deepEquals(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

int _deepHash(Object? value) {
  if (value is List) {
    return Object.hashAll(value.map(_deepHash));
  }
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    return Object.hashAll(
      entries.map((entry) => Object.hash(entry.key, _deepHash(entry.value))),
    );
  }
  return value.hashCode;
}

String _fieldPath(String base, String key) {
  if (RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(key)) {
    return '$base.$key';
  }
  final escaped = key.replaceAll('\\', r'\\').replaceAll("'", r"\'");
  return "$base['$escaped']";
}

String _labelFromSegment(String segment) {
  final words = segment
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(' ')
      .where((word) => word.isNotEmpty);
  return words
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

String _sanitizeId(String value) {
  final sanitized = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return sanitized.isEmpty ? 'bible_source' : sanitized;
}

String? _languageCodeForName(String languageName) {
  try {
    final language = BibleLanguageEnum.fromStr(languageName);
    if (language != BibleLanguageEnum.auto) {
      return language.code;
    }
  } on ArgumentError {
    // Preserve support for legacy names not known by bible_io_references.
  }

  switch (languageName.trim().toLowerCase()) {
    case 'italian':
      return 'it';
    default:
      return null;
  }
}

TextDirectionHint _directionForLanguageCode(String languageCode) {
  switch (languageCode.trim().toLowerCase()) {
    case 'ar':
    case 'fa':
    case 'he':
    case 'ur':
      return TextDirectionHint.rtl;
    default:
      return TextDirectionHint.auto;
  }
}
