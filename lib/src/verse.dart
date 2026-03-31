import 'package:bible_io_references/package.dart';

/// Lightweight data structure representing a single verse.
class Verse {
  final BibleBookEnum book;
  final int chapterNumber;
  final int verseNumber;
  final String text;

  Verse(this.book, this.chapterNumber, this.verseNumber, this.text);

  /// Check if the verse contains a given word (case-insensitive).
  bool containsWord(String word) {
    return text.toLowerCase().contains(word.toLowerCase());
  }

  @override
  String toString() {
    return 'Verse(${book.abbreviation}:$chapterNumber:$verseNumber) -> $text';
  }
}