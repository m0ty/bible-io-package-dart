import 'dart:convert';

import 'package:bible_io_references/bible_io_references.dart';

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
  final int? year;
  final TextDirectionHint direction;
  final String? sourceName;
  final String? copyright;
  final String? license;
  final String? canon;
  final DateTime? versionDate;

  const BibleSource({
    required this.id,
    required this.assetPath,
    required this.languageName,
    required this.languageCode,
    required this.translationName,
    required this.abbreviation,
    this.year,
    this.direction = TextDirectionHint.auto,
    this.sourceName,
    this.copyright,
    this.license,
    this.canon,
    this.versionDate,
  });

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
    final fileBase = dotIndex == -1
        ? fileName
        : fileName.substring(0, dotIndex);
    final inferredLanguage =
        languageName ??
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
      id:
          id ??
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

  factory BibleSource.fromDecodedJson(Map<String, dynamic> json) {
    final assetPath =
        _readString(json, ['assetPath', 'asset_path', 'path', 'file', 'url']) ??
        '';
    final fallback = assetPath.isEmpty
        ? null
        : BibleSource.fromAssetPath(assetPath);
    final languageName =
        _readString(json, ['languageName', 'language_name', 'language']) ??
        fallback?.languageName ??
        '';
    final languageCode =
        _readString(json, ['languageCode', 'language_code', 'lang']) ??
        fallback?.languageCode ??
        _languageCodeForName(languageName) ??
        '';
    final abbreviation =
        _readString(json, [
          'abbreviation',
          'abbr',
          'shortName',
          'short_name',
        ]) ??
        fallback?.abbreviation ??
        '';
    final translationName =
        _readString(json, [
          'translationName',
          'translation_name',
          'name',
          'title',
          'version',
        ]) ??
        fallback?.translationName ??
        abbreviation;
    final direction =
        _readDirection(json) ??
        fallback?.direction ??
        _directionForLanguageCode(languageCode);

    return BibleSource(
      id:
          _readString(json, ['id', 'key']) ??
          fallback?.id ??
          _sanitizeId('${languageName}_$abbreviation'),
      assetPath: assetPath,
      languageName: languageName,
      languageCode: languageCode,
      translationName: translationName,
      abbreviation: abbreviation,
      year: _readInt(json, ['year']),
      direction: direction,
      sourceName: _readString(json, ['sourceName', 'source_name', 'source']),
      copyright: _readString(json, ['copyright']),
      license: _readString(json, ['license']),
      canon: _readString(json, ['canon']),
      versionDate: _readDateTime(json, ['versionDate', 'version_date', 'date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assetPath': assetPath,
      'languageName': languageName,
      'languageCode': languageCode,
      'translationName': translationName,
      'abbreviation': abbreviation,
      if (year != null) 'year': year,
      'direction': direction.name,
      if (sourceName != null) 'sourceName': sourceName,
      if (copyright != null) 'copyright': copyright,
      if (license != null) 'license': license,
      if (canon != null) 'canon': canon,
      if (versionDate != null) 'versionDate': versionDate!.toIso8601String(),
    };
  }
}

/// Metadata attached to a loaded Bible instance.
class BibleMetadata {
  final BibleSource? source;
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

  const BibleMetadata({
    this.source,
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
  });

  factory BibleMetadata.fromDecodedJson(
    Map<String, dynamic> json, {
    BibleSource? source,
  }) {
    final metadata = _asStringKeyedMap(json['metadata']);
    final sourceMap =
        _asStringKeyedMap(metadata?['source']) ??
        _asStringKeyedMap(json['source']);
    final parsedSource =
        source ??
        (sourceMap == null ? null : BibleSource.fromDecodedJson(sourceMap));

    String? read(Iterable<String> keys) {
      return _readString(metadata, keys) ??
          _readString(json, keys) ??
          _readString(sourceMap, keys);
    }

    int? readInt(Iterable<String> keys) {
      return _readInt(metadata, keys) ??
          _readInt(json, keys) ??
          _readInt(sourceMap, keys);
    }

    DateTime? readDate(Iterable<String> keys) {
      return _readDateTime(metadata, keys) ??
          _readDateTime(json, keys) ??
          _readDateTime(sourceMap, keys);
    }

    final languageName =
        read(['languageName', 'language_name', 'language']) ??
        parsedSource?.languageName;
    final languageCode =
        read(['languageCode', 'language_code', 'lang']) ??
        parsedSource?.languageCode;
    final direction =
        _readDirection(metadata) ??
        _readDirection(json) ??
        _readDirection(sourceMap) ??
        parsedSource?.direction ??
        _directionForLanguageCode(languageCode ?? '');

    return BibleMetadata(
      source: parsedSource,
      languageName: languageName,
      languageCode: languageCode,
      translationName:
          read([
            'translationName',
            'translation_name',
            'name',
            'title',
            'version',
          ]) ??
          parsedSource?.translationName,
      abbreviation:
          read(['abbreviation', 'abbr', 'shortName', 'short_name']) ??
          parsedSource?.abbreviation,
      year: readInt(['year']) ?? parsedSource?.year,
      direction: direction,
      sourceName:
          read(['sourceName', 'source_name']) ?? parsedSource?.sourceName,
      copyright: read(['copyright']) ?? parsedSource?.copyright,
      license: read(['license']) ?? parsedSource?.license,
      canon: read(['canon']) ?? parsedSource?.canon,
      versionDate:
          readDate(['versionDate', 'version_date', 'date']) ??
          parsedSource?.versionDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (source != null) 'source': source!.toJson(),
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
}

/// Collection of available Bible sources.
class BibleCatalog {
  final List<BibleSource> sources;

  BibleCatalog(Iterable<BibleSource> sources)
    : sources = List.unmodifiable(sources);

  factory BibleCatalog.fromJson(String jsonString) {
    return BibleCatalog.fromDecodedJson(json.decode(jsonString));
  }

  factory BibleCatalog.fromUtf8Bytes(List<int> bytes) {
    return BibleCatalog.fromJson(utf8.decode(bytes));
  }

  factory BibleCatalog.fromDecodedJson(Object? data) {
    return BibleCatalog(_parseSources(data));
  }

  static Future<BibleCatalog> loadAsset(dynamic assetBundle, String key) async {
    final jsonString = await assetBundle.loadString(key) as String;
    return BibleCatalog.fromJson(jsonString);
  }

  BibleSource? findById(String id) {
    for (final source in sources) {
      if (source.id == id) {
        return source;
      }
    }
    return null;
  }

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

  static List<BibleSource> _parseSources(Object? data, {String? languageName}) {
    if (data is String) {
      return [BibleSource.fromAssetPath(data, languageName: languageName)];
    }
    if (data is List) {
      return [
        for (final item in data)
          ..._parseSources(item, languageName: languageName),
      ];
    }
    final map = _asStringKeyedMap(data);
    if (map == null) {
      return const [];
    }

    if (_readString(map, ['assetPath', 'asset_path', 'path', 'file', 'url']) !=
        null) {
      if (languageName != null) {
        map.putIfAbsent('languageName', () => languageName);
      }
      return [BibleSource.fromDecodedJson(map)];
    }

    final rawSources = map['sources'] ?? map['bibles'] ?? map['translations'];
    if (rawSources != null) {
      return _parseSources(rawSources, languageName: languageName);
    }

    final sources = <BibleSource>[];
    for (final entry in map.entries) {
      final value = entry.value;
      if (value is String) {
        sources.add(
          BibleSource.fromAssetPath(
            value,
            id: entry.key,
            languageName: languageName,
          ),
        );
      } else if (value is List) {
        sources.addAll(
          _parseSources(value, languageName: languageName ?? entry.key),
        );
      } else {
        final sourceMap = _asStringKeyedMap(value);
        if (sourceMap != null) {
          final isSource =
              _readString(sourceMap, [
                'assetPath',
                'asset_path',
                'path',
                'file',
                'url',
              ]) !=
              null;
          if (isSource) {
            sourceMap.putIfAbsent('id', () => entry.key);
            if (languageName != null) {
              sourceMap.putIfAbsent('languageName', () => languageName);
            }
            sources.addAll(_parseSources(sourceMap));
          } else {
            sources.addAll(
              _parseSources(sourceMap, languageName: languageName ?? entry.key),
            );
          }
        }
      }
    }
    return sources;
  }
}

Map<String, dynamic>? _asStringKeyedMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return {for (final entry in value.entries) entry.key.toString(): entry.value};
}

String? _readString(Map<String, dynamic>? map, Iterable<String> keys) {
  if (map == null) {
    return null;
  }
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

int? _readInt(Map<String, dynamic>? map, Iterable<String> keys) {
  if (map == null) {
    return null;
  }
  for (final key in keys) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
  }
  return null;
}

DateTime? _readDateTime(Map<String, dynamic>? map, Iterable<String> keys) {
  final value = _readString(map, keys);
  return value == null ? null : DateTime.tryParse(value);
}

TextDirectionHint? _readDirection(Map<String, dynamic>? map) {
  final value = _readString(map, [
    'direction',
    'textDirection',
    'text_direction',
  ]);
  if (value == null) {
    return null;
  }
  return TextDirectionHint.fromString(value);
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
