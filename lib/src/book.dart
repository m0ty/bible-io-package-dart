import 'package:bible_io_references/bible_io_references.dart';

import 'chapter.dart';
import 'errors.dart';
import 'verse.dart';

/// Container for chapters belonging to a single Bible book.
class Book {
  final BibleBookEnum bookEnum;
  final String name;
  final List<Chapter> chapters;
  late final Map<int, Chapter> _chaptersByNumber;

  Book(this.bookEnum, List<Chapter> chapters, {String? name})
    : name = name ?? bookEnum.fullName,
      chapters = _prepareChapters(bookEnum, chapters) {
    _chaptersByNumber = Map<int, Chapter>.unmodifiable({
      for (final chapter in this.chapters) chapter.chapterNumber: chapter,
    });
  }

  static List<Chapter> _prepareChapters(
    BibleBookEnum book,
    List<Chapter> chapters,
  ) {
    final sortedChapters = List<Chapter>.of(chapters);
    final chapterNumbers = <int>{};

    for (final chapter in sortedChapters) {
      if (chapter.chapterNumber < 1) {
        throw ArgumentError.value(
          chapter.chapterNumber,
          'chapters',
          'Chapter number must be positive',
        );
      }
      if (chapter.book != book) {
        throw ArgumentError.value(
          chapter.book,
          'chapters',
          'Chapter ${chapter.chapterNumber} does not belong to $book',
        );
      }
      if (!chapterNumbers.add(chapter.chapterNumber)) {
        throw ArgumentError.value(
          chapter.chapterNumber,
          'chapters',
          'Duplicate chapter number',
        );
      }
    }

    sortedChapters.sort(
      (first, second) => first.chapterNumber.compareTo(second.chapterNumber),
    );
    return List<Chapter>.unmodifiable(sortedChapters);
  }

  /// Return the chapters that belong to this book.
  List<Chapter> getChapters() {
    return chapters;
  }

  /// Retrieve a chapter by its declared chapter number.
  Chapter getChapter(int chapterNumber) {
    final chapter = _chaptersByNumber[chapterNumber];
    if (chapter == null) {
      throw ChapterNotFoundError(bookEnum, chapterNumber);
    }
    return chapter;
  }

  /// Retrieve all verses for the requested chapter number.
  List<Verse> getVerses(int chapterNumber) {
    return getChapter(chapterNumber).getVerses();
  }

  /// Retrieve a single verse from a chapter.
  Verse getVerse(int chapterNumber, int verseNumber) {
    return getChapter(chapterNumber).getVerse(verseNumber);
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
