import 'package:bible_io_references/bible_io_references.dart';

import 'json_value.dart';
import 'location.dart';
import 'text_normalization.dart';

/// Lightweight data structure representing a single verse.
class Verse {
  final BibleBookEnum book;
  final int chapterNumber;
  final int verseNumber;
  final String text;

  /// Extensible, JSON-compatible data associated with this verse.
  ///
  /// The map and every nested map/list are deeply immutable. The ordinary
  /// const constructor creates a plain-text verse; use [Verse.checked] when
  /// supplying annotations or constructing verses from untrusted data.
  final Map<String, Object?> annotations;

  const Verse(this.book, this.chapterNumber, this.verseNumber, this.text)
      : annotations = const {},
        assert(chapterNumber > 0),
        assert(verseNumber > 0);

  /// Creates a verse with validation in every build mode.
  factory Verse.checked(
    BibleBookEnum book,
    int chapterNumber,
    int verseNumber,
    String text, {
    Map<String, Object?> annotations = const {},
  }) {
    if (chapterNumber < 1) {
      throw ArgumentError.value(
        chapterNumber,
        'chapterNumber',
        'must be positive',
      );
    }
    if (verseNumber < 1) {
      throw ArgumentError.value(verseNumber, 'verseNumber', 'must be positive');
    }
    return Verse._(
      book,
      chapterNumber,
      verseNumber,
      text,
      freezeJsonMap(
        annotations,
        reservedKeys: const {'text'},
        parameterName: 'annotations',
      ),
    );
  }

  const Verse._(
    this.book,
    this.chapterNumber,
    this.verseNumber,
    this.text,
    this.annotations,
  );

  /// The stable location of this verse within an edition.
  BibleLocation get location => BibleLocation.checked(
        book: book,
        chapter: chapterNumber,
        verse: verseNumber,
      );

  /// Converts this verse's location to a reference-package value.
  VerseRef toVerseRef() =>
      VerseRef.checked(book: book, chapter: chapterNumber, verse: verseNumber);

  /// Check whether [word] is a complete Unicode word token in this verse.
  ///
  /// Matching is case-insensitive and canonically normalized. Empty input and
  /// input containing more than one token do not match.
  bool containsWord(String word) {
    final queryTokens = tokenizeSearchText(word);
    if (queryTokens.length != 1) return false;
    return tokenizeSearchText(text).contains(queryTokens.single);
  }

  /// Check whether the verse contains [query] as a case-insensitive substring.
  ///
  /// Unlike [containsWord], this method can match part of a word. Empty input
  /// never matches.
  bool containsText(String query) {
    return containsNormalizedText(text, query);
  }

  /// Creates a validated copy of this verse.
  Verse copyWith({
    BibleBookEnum? book,
    int? chapterNumber,
    int? verseNumber,
    String? text,
    Map<String, Object?>? annotations,
  }) {
    return Verse.checked(
      book ?? this.book,
      chapterNumber ?? this.chapterNumber,
      verseNumber ?? this.verseNumber,
      text ?? this.text,
      annotations: annotations ?? this.annotations,
    );
  }

  /// Encodes the verse in the package's compatible JSON value shape.
  ///
  /// Plain verses remain strings. Annotated verses become an object containing
  /// `text` followed by their additional fields.
  Object toJsonValue() {
    if (annotations.isEmpty) return text;
    return Map<String, Object?>.unmodifiable({'text': text, ...annotations});
  }

  @override
  String toString() {
    return 'Verse(${book.abbreviation}:$chapterNumber:$verseNumber) -> $text';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Verse &&
            other.book == book &&
            other.chapterNumber == chapterNumber &&
            other.verseNumber == verseNumber &&
            other.text == text &&
            jsonValueEquals(other.annotations, annotations);
  }

  @override
  int get hashCode => Object.hash(
        book,
        chapterNumber,
        verseNumber,
        text,
        jsonValueHash(annotations),
      );
}
