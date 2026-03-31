import 'package:bible_io_references/package.dart';

import 'errors.dart';
import 'verse.dart';

/// Collection of verses representing a single chapter in a book.
class Chapter {
  final BibleBookEnum book;
  final int chapterNumber;
  final List<Verse> verses;

  Chapter(this.book, this.chapterNumber, this.verses);

  /// Return all verses in the chapter.
  List<Verse> getVerses() {
    return verses;
  }

  /// Retrieve a verse by its index within the chapter.
  Verse getVerse(int verseNumber) {
    if (verseNumber < 1 || verseNumber > verses.length) {
      throw VerseNotFoundError(book, chapterNumber, verseNumber);
    }
    return verses[verseNumber - 1];
  }

  /// Search verses in the chapter for a word.
  List<Verse> search(String word) {
    return verses.where((verse) => verse.containsWord(word)).toList();
  }
}