import 'package:bible_io_references/package.dart';

import 'chapter.dart';
import 'errors.dart';
import 'verse.dart';

/// Container for chapters belonging to a single Bible book.
class Book {
  final BibleBookEnum bookEnum;
  final String name;
  final List<Chapter> chapters;

  Book(this.bookEnum, this.chapters, {String? name})
      : name = name ?? bookEnum.fullName;

  /// Return the chapters that belong to this book.
  List<Chapter> getChapters() {
    return chapters;
  }

  /// Retrieve all verses for the requested chapter number.
  List<Verse> getVerses(int chapterNumber) {
    if (chapterNumber < 1 || chapterNumber > chapters.length) {
      throw ChapterNotFoundError(bookEnum, chapterNumber);
    }
    return chapters[chapterNumber - 1].getVerses();
  }

  /// Retrieve a single verse from a chapter.
  Verse getVerse(int chapterNumber, int verseNumber) {
    if (chapterNumber < 1 || chapterNumber > chapters.length) {
      throw ChapterNotFoundError(bookEnum, chapterNumber);
    }
    return chapters[chapterNumber - 1].getVerse(verseNumber);
  }

  /// Search within the book for verses containing a word.
  List<Verse> search(String word) {
    final matches = <Verse>[];
    for (final chapter in chapters) {
      matches.addAll(chapter.search(word));
    }
    return matches;
  }

  @override
  String toString() {
    return 'Book(${bookEnum.abbreviation}: $name)';
  }
}