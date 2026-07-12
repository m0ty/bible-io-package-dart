import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  const genesis = BibleBookEnum.genesis;

  group('Chapter model correctness', () {
    test('sorts copied verses and looks up sparse verse numbers', () {
      const verseTwo = Verse(genesis, 4, 2, 'Second');
      const verseNine = Verse(genesis, 4, 9, 'Ninth');
      final input = <Verse>[verseNine, verseTwo];

      final chapter = Chapter(genesis, 4, input);

      expect(chapter.verses, [verseTwo, verseNine]);
      expect(chapter.getVerse(2), same(verseTwo));
      expect(chapter.getVerse(9), same(verseNine));
      expect(() => chapter.getVerse(1), throwsA(isA<VerseNotFoundError>()));
      expect(input, [verseNine, verseTwo]);

      input.clear();
      expect(chapter.verses, [verseTwo, verseNine]);
      expect(() => chapter.verses.add(verseTwo), throwsUnsupportedError);
      expect(() => chapter.getVerses().clear(), throwsUnsupportedError);
    });

    test('rejects duplicate verse numbers', () {
      expect(
        () => Chapter(genesis, 1, const [
          Verse(genesis, 1, 3, 'First value'),
          Verse(genesis, 1, 3, 'Duplicate value'),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects verses from another book or chapter', () {
      expect(
        () => Chapter(genesis, 1, const [
          Verse(BibleBookEnum.exodus, 1, 1, 'Wrong book'),
        ]),
        throwsArgumentError,
      );
      expect(
        () =>
            Chapter(genesis, 1, const [Verse(genesis, 2, 1, 'Wrong chapter')]),
        throwsArgumentError,
      );
    });

    test('rejects non-positive chapter and verse numbers', () {
      expect(() => Chapter(genesis, 0, const []), throwsArgumentError);
      expect(
        () => Chapter(genesis, 1, [Verse(genesis, 1, 0, 'Invalid verse')]),
        throwsA(anyOf(isA<AssertionError>(), isA<ArgumentError>())),
      );
    });
  });

  group('Book model correctness', () {
    test('sorts copied chapters and looks up sparse chapter numbers', () {
      const verseTwo = Verse(genesis, 2, 5, 'Chapter two');
      const verseSeven = Verse(genesis, 7, 11, 'Chapter seven');
      final chapterTwo = Chapter(genesis, 2, const [verseTwo]);
      final chapterSeven = Chapter(genesis, 7, const [verseSeven]);
      final input = <Chapter>[chapterSeven, chapterTwo];

      final book = Book(genesis, input);

      expect(book.chapters, [chapterTwo, chapterSeven]);
      expect(book.getChapter(2), same(chapterTwo));
      expect(book.getChapter(7), same(chapterSeven));
      expect(book.getVerses(7), [verseSeven]);
      expect(book.getVerse(2, 5), same(verseTwo));
      expect(() => book.getChapter(1), throwsA(isA<ChapterNotFoundError>()));
      expect(input, [chapterSeven, chapterTwo]);

      input.clear();
      expect(book.chapters, [chapterTwo, chapterSeven]);
      expect(() => book.chapters.add(chapterTwo), throwsUnsupportedError);
      expect(() => book.getChapters().clear(), throwsUnsupportedError);
    });

    test('rejects duplicate chapter numbers', () {
      final first = Chapter(genesis, 3, const [
        Verse(genesis, 3, 1, 'First chapter value'),
      ]);
      final duplicate = Chapter(genesis, 3, const [
        Verse(genesis, 3, 2, 'Duplicate chapter value'),
      ]);

      expect(() => Book(genesis, [first, duplicate]), throwsArgumentError);
    });

    test('rejects chapters from another book', () {
      final exodus = Chapter(BibleBookEnum.exodus, 1, const [
        Verse(BibleBookEnum.exodus, 1, 1, 'Exodus'),
      ]);

      expect(() => Book(genesis, [exodus]), throwsArgumentError);
    });
  });

  group('Bible model correctness', () {
    test('defensively copies the book list used by indexes and search', () {
      final chapter = Chapter(genesis, 1, const [
        Verse(genesis, 1, 1, 'Stable text'),
      ]);
      final input = <Book>[
        Book(genesis, [chapter]),
      ];
      final bible = Bible.fromBooks(input);

      input.clear();

      expect(bible.getBook(genesis).chapters, [chapter]);
      expect(bible.search('stable'), hasLength(1));
      expect(() => bible.books.clear(), throwsUnsupportedError);
    });

    test('navigates declared sparse chapter numbers across books', () {
      final bible = Bible.fromBooks([
        Book(genesis, [
          Chapter(genesis, 7, const [Verse(genesis, 7, 1, 'Seven')]),
          Chapter(genesis, 2, const [Verse(genesis, 2, 1, 'Two')]),
        ]),
        Book(BibleBookEnum.exodus, [
          Chapter(BibleBookEnum.exodus, 3, const [
            Verse(BibleBookEnum.exodus, 3, 1, 'Exodus three'),
          ]),
        ]),
      ]);

      expect(
        bible.nextChapter(const BibleLocation(book: genesis, chapter: 2)),
        const BibleLocation(book: genesis, chapter: 7),
      );
      expect(
        bible.nextChapter(const BibleLocation(book: genesis, chapter: 7)),
        const BibleLocation(book: BibleBookEnum.exodus, chapter: 3),
      );
      expect(
        bible.previousChapter(
          const BibleLocation(book: BibleBookEnum.exodus, chapter: 3),
        ),
        const BibleLocation(book: genesis, chapter: 7),
      );
    });

    test('accepts short, OSIS, USFM, and full-name book identifiers', () {
      for (final identifier in ['gn', 'Gen', 'GEN', 'Genesis']) {
        final bible = Bible.fromDecodedJson({
          'books': {
            identifier: {
              'chapters': {
                '1': {'1': identifier},
              },
            },
          },
        });

        expect(bible.getVerse(genesis, 1, 1).text, identifier);
      }
    });

    test('rejects duplicate books expressed with different identifiers', () {
      expect(
        () => Bible.fromDecodedJson({
          'books': {
            'gn': {
              'chapters': {
                '1': {'1': 'First'},
              },
            },
            'GEN': {
              'chapters': {
                '1': {'1': 'Duplicate'},
              },
            },
          },
        }),
        throwsA(
          isA<BibleDataFormatError>()
              .having(
                (error) => error.code,
                'code',
                BibleDataFormatErrorCode.invalidValue,
              )
              .having((error) => error.path, 'path', r'$.books.GEN'),
        ),
      );
    });
  });
}
