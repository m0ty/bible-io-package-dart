import 'package:bible_io_references/bible_io_references.dart';

import 'errors.dart';
import 'json_value.dart';
import 'verse.dart';

/// Collection of verses representing a single chapter in a book.
class Chapter {
  final BibleBookEnum book;
  final int chapterNumber;
  final List<Verse> verses;

  /// Extensible, deeply immutable JSON-compatible chapter metadata.
  final Map<String, Object?> annotations;

  late final Map<int, Verse> _versesByNumber;

  Chapter(
    this.book,
    this.chapterNumber,
    List<Verse> verses, {
    Map<String, Object?> annotations = const {},
  })  : verses = _prepareVerses(book, chapterNumber, verses),
        annotations = freezeJsonMap(
          annotations,
          reservedKeys: const {'verses'},
          parameterName: 'annotations',
        ) {
    _versesByNumber = Map<int, Verse>.unmodifiable({
      for (final verse in this.verses) verse.verseNumber: verse,
    });
  }

  static List<Verse> _prepareVerses(
    BibleBookEnum book,
    int chapterNumber,
    List<Verse> verses,
  ) {
    if (chapterNumber < 1) {
      throw ArgumentError.value(
        chapterNumber,
        'chapterNumber',
        'must be positive',
      );
    }
    final sortedVerses = List<Verse>.of(verses);
    final verseNumbers = <int>{};

    for (final verse in sortedVerses) {
      if (verse.verseNumber < 1) {
        throw ArgumentError.value(
          verse.verseNumber,
          'verses',
          'Verse number must be positive',
        );
      }
      if (verse.book != book) {
        throw ArgumentError.value(
          verse.book,
          'verses',
          'Verse ${verse.verseNumber} does not belong to $book',
        );
      }
      if (verse.chapterNumber != chapterNumber) {
        throw ArgumentError.value(
          verse.chapterNumber,
          'verses',
          'Verse ${verse.verseNumber} does not belong to chapter '
              '$chapterNumber',
        );
      }
      if (!verseNumbers.add(verse.verseNumber)) {
        throw ArgumentError.value(
          verse.verseNumber,
          'verses',
          'Duplicate verse number',
        );
      }
    }

    sortedVerses.sort(
      (first, second) => first.verseNumber.compareTo(second.verseNumber),
    );
    return List<Verse>.unmodifiable(sortedVerses);
  }

  /// Return all verses in the chapter.
  List<Verse> getVerses() {
    return verses;
  }

  /// Retrieve a verse by its declared verse number.
  Verse getVerse(int verseNumber) {
    final verse = _versesByNumber[verseNumber];
    if (verse == null) {
      throw VerseNotFoundError(book, chapterNumber, verseNumber);
    }
    return verse;
  }

  /// Search verses in the chapter for a word.
  List<Verse> search(String word) {
    return List<Verse>.unmodifiable(
      verses.where((verse) => verse.containsWord(word)),
    );
  }

  /// Creates a validated, immutable copy of this chapter.
  ///
  /// Changing [book] or [chapterNumber] also requires supplying verses whose
  /// locations match the new chapter.
  Chapter copyWith({
    BibleBookEnum? book,
    int? chapterNumber,
    List<Verse>? verses,
    Map<String, Object?>? annotations,
  }) {
    return Chapter(
      book ?? this.book,
      chapterNumber ?? this.chapterNumber,
      verses ?? this.verses,
      annotations: annotations ?? this.annotations,
    );
  }

  /// Encodes this chapter in a backward-compatible JSON value shape.
  ///
  /// An unannotated chapter remains the legacy verse-number map. Annotated
  /// chapters use an object with a `verses` member alongside their metadata.
  Map<String, Object?> toJsonValue() {
    final versesJson = Map<String, Object?>.unmodifiable({
      for (final verse in verses)
        verse.verseNumber.toString(): verse.toJsonValue(),
    });
    if (annotations.isEmpty) return versesJson;
    return Map<String, Object?>.unmodifiable({
      ...annotations,
      'verses': versesJson,
    });
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Chapter &&
            other.book == book &&
            other.chapterNumber == chapterNumber &&
            jsonValueEquals(other.verses, verses) &&
            jsonValueEquals(other.annotations, annotations);
  }

  @override
  int get hashCode => Object.hash(
        book,
        chapterNumber,
        jsonValueHash(verses),
        jsonValueHash(annotations),
      );
}
