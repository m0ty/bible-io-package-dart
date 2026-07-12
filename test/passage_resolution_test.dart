import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  late Bible bible;

  setUp(() {
    bible = _smallBible();
  });

  group('references 1.1 integration', () {
    test('resolves cross-book ranges in edition order', () {
      final verses = bible.getVerseRangeByRef('Genesis 1:2-Exodus 1:1');

      expect(verses.map((verse) => verse.text), [
        'Genesis 1:2',
        'Genesis 2:1',
        'Exodus 1:1',
      ]);
      expect(() => verses.add(verses.first), throwsUnsupportedError);
    });

    test('resolves book, chapter-range, verse-list, and sequence passages', () {
      expect(bible.getPassage('Genesis').map((verse) => verse.text), [
        'Genesis 1:1',
        'Genesis 1:2',
        'Genesis 2:1',
      ]);
      expect(bible.getPassage('Genesis 1-2').map((verse) => verse.text), [
        'Genesis 1:1',
        'Genesis 1:2',
        'Genesis 2:1',
      ]);
      expect(bible.getPassage('Genesis 1:1,2:1').map((verse) => verse.text), [
        'Genesis 1:1',
        'Genesis 2:1',
      ]);
      expect(
        bible.getPassage('Genesis 1:2; Exodus 1').map((verse) => verse.text),
        ['Genesis 1:2', 'Exodus 1:1', 'Exodus 1:2'],
      );
    });

    test('preserves overlaps and sequence duplicates', () {
      final verses = bible.getPassage('Genesis 1:1,1-2; Genesis 1:2');

      expect(verses.map((verse) => verse.verseNumber), [1, 1, 2, 2]);
    });

    test('validates every chapter against the loaded edition', () {
      expect(
        () => bible.getPassage('Genesis 1-3'),
        throwsA(isA<ChapterNotFoundError>()),
      );
    });

    test('resolves OSIS and USFM references exported by the dependency', () {
      expect(
        bible
            .resolveReference(referenceFromOsisIdentifier('Gen.1.2-Exod.1.1'))
            .map((verse) => verse.text),
        ['Genesis 1:2', 'Genesis 2:1', 'Exodus 1:1'],
      );
      expect(
        bible
            .resolveReference(referenceFromUsfmIdentifier('GEN-EXO 1:2-1:1'))
            .map((verse) => verse.text),
        ['Genesis 1:2', 'Genesis 2:1', 'Exodus 1:1'],
      );
    });

    test('uses typed non-throwing parsing with multilingual detection', () {
      final parsed = bible.parseReference('Génesis 1:1');

      expect(parsed, isA<ParseSuccess<Reference>>());
      expect(parsed.valueOrNull, isA<VerseRef>());
      expect(parsed.metadataOrNull?.detectedLanguage, isNotNull);

      final strictSpanish = bible.parseReference(
        'Génesis 1:1',
        inputLanguage: BibleLanguageEnum.spanish,
      );
      expect(
        strictSpanish.metadataOrNull?.detectedLanguage,
        BibleLanguageEnum.spanish,
      );

      final invalid = bible.parseReference('not a reference');
      expect(invalid, isA<ParseFailure<Reference>>());
      expect(invalid.errorOrNull?.errorCode, isNotNull);
    });

    test('auto-detects loaded aliases but keeps explicit language strict', () {
      final greekBible = Bible.fromBooks([
        Book(BibleBookEnum.genesis, [
          Chapter(BibleBookEnum.genesis, 1, const [
            Verse(BibleBookEnum.genesis, 1, 1, 'Loaded alias'),
          ]),
        ], name: 'My Genesis'),
      ], language: BibleLanguageEnum.greek);

      expect(greekBible.getVerseByRef('My Genesis 1:1').text, 'Loaded alias');

      final strict = greekBible.parseReference(
        'Genesis 1:1',
        inputLanguage: BibleLanguageEnum.esperanto,
      );
      expect(
        strict.errorOrNull?.errorCode,
        ReferenceParseErrorCode.unsupportedLanguage,
      );
    });

    test('BibleLocation interoperates with VerseRef and Passage', () {
      const reference = VerseRef(
        book: BibleBookEnum.genesis,
        chapter: 1,
        verse: 2,
      );
      final location = BibleLocation.fromVerseRef(reference);

      expect(location.toVerseRef(), reference);
      expect(location.toPassage(), VersePassage([reference]));
      expect(
        const BibleLocation(
          book: BibleBookEnum.genesis,
          chapter: 2,
        ).toPassage(),
        ChapterPassage(BibleBookEnum.genesis, 2),
      );
      expect(
        () => BibleLocation.checked(book: BibleBookEnum.genesis, chapter: 0),
        throwsArgumentError,
      );
    });
  });
}

Bible _smallBible() {
  return Bible.fromDecodedJson({
    'language': 'English',
    'books': {
      'gn': {
        'name': 'Genesis',
        'chapters': {
          '2': {'1': 'Genesis 2:1'},
          '1': {'2': 'Genesis 1:2', '1': 'Genesis 1:1'},
        },
      },
      'ex': {
        'name': 'Exodus',
        'chapters': {
          '1': {'2': 'Exodus 1:2', '1': 'Exodus 1:1'},
        },
      },
    },
  });
}
