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
    return BibleLocation(
      book: verse.book,
      chapter: verse.chapterNumber,
      verse: verse.verseNumber,
    );
  }

  factory BibleLocation.fromVerseRef(VerseRef reference) {
    return BibleLocation(
      book: reference.book,
      chapter: reference.chapter,
      verse: reference.verse,
    );
  }

  int get chapterNumber => chapter;

  int? get verseNumber => verse;

  bool get hasVerse => verse != null;

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
