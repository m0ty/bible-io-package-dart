import 'package:bible_io_references/bible_io_references.dart';

import 'chapter.dart';
import 'errors.dart';
import 'json_value.dart';
import 'verse.dart';

/// Container for chapters belonging to a single Bible book.
class Book {
  final BibleBookEnum bookEnum;
  final String name;
  final List<Chapter> chapters;

  /// Extensible, deeply immutable JSON-compatible book metadata.
  final Map<String, Object?> annotations;

  late final Map<int, Chapter> _chaptersByNumber;

  Book(
    this.bookEnum,
    List<Chapter> chapters, {
    String? name,
    Map<String, Object?> annotations = const {},
  })  : name = _prepareName(name ?? bookEnum.fullName),
        chapters = _prepareChapters(bookEnum, chapters),
        annotations = freezeJsonMap(
          annotations,
          reservedKeys: const {'name', 'chapters'},
          parameterName: 'annotations',
        ) {
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

  static String _prepareName(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    return name;
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
    return List<Verse>.unmodifiable(matches);
  }

  /// Creates a validated, immutable copy of this book.
  ///
  /// Changing [bookEnum] also requires supplying chapters belonging to the
  /// new book.
  Book copyWith({
    BibleBookEnum? bookEnum,
    String? name,
    List<Chapter>? chapters,
    Map<String, Object?>? annotations,
  }) {
    return Book(
      bookEnum ?? this.bookEnum,
      chapters ?? this.chapters,
      name: name ?? this.name,
      annotations: annotations ?? this.annotations,
    );
  }

  /// Encodes this book and its annotations as a JSON-compatible object.
  Map<String, Object?> toJsonValue() => Map<String, Object?>.unmodifiable({
        ...annotations,
        'name': name,
        'chapters': Map<String, Object?>.unmodifiable({
          for (final chapter in chapters)
            chapter.chapterNumber.toString(): chapter.toJsonValue(),
        }),
      });

  @override
  String toString() {
    return 'Book(${bookEnum.abbreviation}: $name)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Book &&
            other.bookEnum == bookEnum &&
            other.name == name &&
            jsonValueEquals(other.chapters, chapters) &&
            jsonValueEquals(other.annotations, annotations);
  }

  @override
  int get hashCode => Object.hash(
        bookEnum,
        name,
        jsonValueHash(chapters),
        jsonValueHash(annotations),
      );
}
