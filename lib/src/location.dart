import 'package:bible_io_references/bible_io_references.dart';

import 'verse.dart';

/// Stable location for a chapter or verse inside a Bible.
class BibleLocation {
  final BibleBookEnum book;
  final int chapter;
  final int? verse;

  const BibleLocation({required this.book, required this.chapter, this.verse})
      : assert(chapter > 0),
        assert(verse == null || verse > 0);

  /// Create a location with runtime validation in all build modes.
  factory BibleLocation.checked({
    required BibleBookEnum book,
    required int chapter,
    int? verse,
  }) {
    if (chapter < 1) {
      throw ArgumentError.value(chapter, 'chapter', 'must be positive');
    }
    if (verse != null && verse < 1) {
      throw ArgumentError.value(verse, 'verse', 'must be positive');
    }
    return BibleLocation(book: book, chapter: chapter, verse: verse);
  }

  factory BibleLocation.fromVerse(Verse verse) {
    return BibleLocation.checked(
      book: verse.book,
      chapter: verse.chapterNumber,
      verse: verse.verseNumber,
    );
  }

  factory BibleLocation.fromVerseRef(VerseRef reference) {
    return BibleLocation.checked(
      book: reference.book,
      chapter: reference.chapter,
      verse: reference.verse,
    );
  }

  /// Restores a location previously produced by [toJson].
  ///
  /// Malformed input consistently throws [FormatException] rather than
  /// leaking a cast error.
  factory BibleLocation.fromJson(Map<String, Object?> json) {
    final book = _bookFromJson(json['book']);
    final chapter = _positiveIntFromJson(json, 'chapter');
    final rawVerse = json['verse'];
    final verse =
        rawVerse == null ? null : _positiveIntValueFromJson(rawVerse, 'verse');
    return BibleLocation.checked(book: book, chapter: chapter, verse: verse);
  }

  int get chapterNumber => chapter;

  int? get verseNumber => verse;

  bool get hasVerse => verse != null;

  /// Creates a validated copy of this location.
  ///
  /// Omitting [verse] preserves its current value. Passing `verse: null`
  /// explicitly changes a verse location into a chapter location.
  BibleLocation copyWith({
    BibleBookEnum? book,
    int? chapter,
    Object? verse = _keepVerse,
  }) {
    final int? nextVerse;
    if (identical(verse, _keepVerse)) {
      nextVerse = this.verse;
    } else if (verse == null || verse is int) {
      nextVerse = verse as int?;
    } else {
      throw ArgumentError.value(verse, 'verse', 'must be an int or null');
    }
    return BibleLocation.checked(
      book: book ?? this.book,
      chapter: chapter ?? this.chapter,
      verse: nextVerse,
    );
  }

  /// Convert this location to the rich reference package's passage model.
  Passage toPassage() {
    final verseNumber = verse;
    if (verseNumber == null) {
      return ChapterPassage(book, chapter);
    }
    return VersePassage([
      VerseRef.checked(book: book, chapter: chapter, verse: verseNumber),
    ]);
  }

  /// Convert a verse location to a [VerseRef].
  ///
  /// Throws when this location identifies a chapter rather than a verse.
  VerseRef toVerseRef() {
    final verseNumber = verse;
    if (verseNumber == null) {
      throw StateError('A chapter-only BibleLocation has no VerseRef.');
    }
    return VerseRef.checked(book: book, chapter: chapter, verse: verseNumber);
  }

  /// Encodes this location using a stable Bible-book abbreviation.
  Map<String, Object?> toJson() => {
        'book': book.abbreviation,
        'chapter': chapter,
        if (verse != null) 'verse': verse,
      };

  String get reference {
    final chapterReference = '${book.fullName} $chapter';
    final verseNumber = verse;
    if (verseNumber == null) {
      return chapterReference;
    }
    return '$chapterReference:$verseNumber';
  }

  @override
  String toString() => reference;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BibleLocation &&
            other.book == book &&
            other.chapter == chapter &&
            other.verse == verse;
  }

  @override
  int get hashCode => Object.hash(book, chapter, verse);
}

/// An edition-aware stable key for persisted verse UI state.
///
/// A [BibleLocation] alone is only unique within one Bible edition. This key
/// combines it with a non-blank edition identifier so bookmarks, highlights,
/// and reading progress cannot collide across translations.
final class BibleVerseKey {
  /// Creates a key with runtime validation in every build mode.
  factory BibleVerseKey({
    required String editionId,
    required BibleLocation location,
  }) =>
      BibleVerseKey.checked(editionId: editionId, location: location);

  /// Creates a key with runtime validation in every build mode.
  factory BibleVerseKey.checked({
    required String editionId,
    required BibleLocation location,
  }) {
    if (editionId.trim().isEmpty || editionId != editionId.trim()) {
      throw ArgumentError.value(
        editionId,
        'editionId',
        'must be non-blank and have no surrounding whitespace',
      );
    }
    if (location.chapter < 1) {
      throw ArgumentError.value(
        location.chapter,
        'location',
        'chapter must be positive',
      );
    }
    final verse = location.verse;
    if (verse == null) {
      throw ArgumentError.value(location, 'location', 'must identify a verse');
    }
    if (verse < 1) {
      throw ArgumentError.value(location, 'location', 'verse must be positive');
    }
    return BibleVerseKey._(editionId, location);
  }

  const BibleVerseKey._(this.editionId, this.location);

  factory BibleVerseKey.fromVerse(String editionId, Verse verse) {
    return BibleVerseKey(editionId: editionId, location: verse.location);
  }

  /// Restores a key previously produced by [toJson].
  factory BibleVerseKey.fromJson(Map<String, Object?> json) {
    final editionId = json['editionId'];
    if (editionId is! String ||
        editionId.trim().isEmpty ||
        editionId != editionId.trim()) {
      throw const FormatException(
        '"editionId" must be a non-blank, trimmed string',
      );
    }

    final rawLocation = json['location'];
    if (rawLocation is! Map) {
      throw const FormatException('"location" must be an object');
    }
    final locationJson = <String, Object?>{};
    for (final entry in rawLocation.entries) {
      if (entry.key is! String) {
        throw const FormatException('"location" keys must be strings');
      }
      locationJson[entry.key as String] = entry.value;
    }
    final location = BibleLocation.fromJson(locationJson);
    if (!location.hasVerse) {
      throw const FormatException('"location" must identify a verse');
    }
    return BibleVerseKey._(editionId, location);
  }

  final String editionId;
  final BibleLocation location;

  /// The location represented as a rich reference-package value.
  VerseRef toVerseRef() => location.toVerseRef();

  BibleVerseKey copyWith({String? editionId, BibleLocation? location}) {
    return BibleVerseKey(
      editionId: editionId ?? this.editionId,
      location: location ?? this.location,
    );
  }

  Map<String, Object?> toJson() => {
        'editionId': editionId,
        'location': location.toJson(),
      };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BibleVerseKey &&
            other.editionId == editionId &&
            other.location == location;
  }

  @override
  int get hashCode => Object.hash(editionId, location);

  @override
  String toString() => '$editionId:${location.reference}';
}

const _KeepVerse _keepVerse = _KeepVerse();

final class _KeepVerse {
  const _KeepVerse();
}

BibleBookEnum _bookFromJson(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('"book" must be a non-empty string');
  }
  final normalized = value.trim().toLowerCase();
  for (final book in BibleBookEnum.values) {
    if (book.abbreviation.toLowerCase() == normalized ||
        book.name.toLowerCase() == normalized ||
        book.fullName.toLowerCase() == normalized) {
      return book;
    }
  }
  throw FormatException('unknown Bible book: $value');
}

int _positiveIntFromJson(Map<String, Object?> json, String key) {
  return _positiveIntValueFromJson(json[key], key);
}

int _positiveIntValueFromJson(Object? value, String key) {
  if (value is! int || value < 1) {
    throw FormatException('"$key" must be a positive integer');
  }
  return value;
}
