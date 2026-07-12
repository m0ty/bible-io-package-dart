import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  const genesis = BibleBookEnum.genesis;

  group('Verse value', () {
    test('checked construction validates numbers in every build mode', () {
      expect(() => Verse.checked(genesis, 0, 1, 'text'), throwsArgumentError);
      expect(() => Verse.checked(genesis, 1, 0, 'text'), throwsArgumentError);
    });

    test('distinguishes Unicode whole words from substrings', () {
      const verse = Verse(
        genesis,
        1,
        1,
        "κόσμος κοσμικός בְּרֵאשִׁית God's 神创造天地",
      );

      expect(verse.containsWord('ΚΌΣΜΟΣ'), isTrue);
      expect(verse.containsWord('κόσ'), isFalse);
      expect(verse.containsWord('בְּרֵאשִׁית'), isTrue);
      expect(verse.containsWord("god's"), isFalse);
      expect(verse.containsWord('God'), isTrue);
      expect(verse.containsWord('创造'), isFalse);
      expect(verse.containsWord(''), isFalse);
      expect(verse.containsWord('two words'), isFalse);
      expect(verse.containsText('κόσ'), isTrue);
      expect(verse.containsText('创造'), isTrue);
      expect(verse.containsText(''), isFalse);
    });

    test('exposes value-safe locations and reference conversion', () {
      const verse = Verse(genesis, 2, 3, 'text');

      expect(
        verse.location,
        const BibleLocation(book: genesis, chapter: 2, verse: 3),
      );
      expect(
        verse.toVerseRef(),
        const VerseRef(book: genesis, chapter: 2, verse: 3),
      );
    });

    test('deeply freezes JSON annotations and preserves legacy JSON', () {
      final source = <String, Object?>{
        'heading': 'Creation',
        'layout': <String, Object?>{
          'lines': <Object?>['first'],
        },
      };
      final verse = Verse.checked(
        genesis,
        1,
        1,
        'In the beginning',
        annotations: source,
      );

      (source['layout']! as Map<String, Object?>)['lines'] = <Object?>[
        'changed',
      ];
      source['heading'] = 'Changed';

      expect(verse.annotations['heading'], 'Creation');
      expect(verse.toJsonValue(), {
        'text': 'In the beginning',
        'heading': 'Creation',
        'layout': {
          'lines': ['first'],
        },
      });
      expect(() => verse.annotations['new'] = true, throwsUnsupportedError);
      final layout = verse.annotations['layout']! as Map<String, Object?>;
      final lines = layout['lines']! as List<Object?>;
      expect(() => lines.add('second'), throwsUnsupportedError);
      expect(const Verse(genesis, 1, 2, 'plain').toJsonValue(), 'plain');
    });

    test('rejects structural and non-JSON annotations', () {
      expect(
        () => Verse.checked(
          genesis,
          1,
          1,
          'text',
          annotations: {'text': 'replacement'},
        ),
        throwsArgumentError,
      );
      expect(
        () => Verse.checked(
          genesis,
          1,
          1,
          'text',
          annotations: {'number': double.nan},
        ),
        throwsArgumentError,
      );
      expect(
        () => Verse.checked(
          genesis,
          1,
          1,
          'text',
          annotations: {
            'nested': <Object?, Object?>{1: 'not a JSON object key'},
          },
        ),
        throwsArgumentError,
      );
    });

    test('has structural value semantics and validated copyWith', () {
      final first = Verse.checked(
        genesis,
        1,
        1,
        'text',
        annotations: {
          'notes': ['one'],
        },
      );
      final equal = Verse.checked(
        genesis,
        1,
        1,
        'text',
        annotations: {
          'notes': ['one'],
        },
      );

      expect(first, equal);
      expect(first.hashCode, equal.hashCode);
      expect(first.copyWith(text: 'updated').text, 'updated');
      expect(first.copyWith(annotations: const {}).annotations, isEmpty);
      expect(() => first.copyWith(verseNumber: 0), throwsArgumentError);
    });
  });

  group('Book and chapter values', () {
    test('preserve deeply immutable annotations with value semantics', () {
      final firstChapter = Chapter(
        genesis,
        1,
        const [Verse(genesis, 1, 1, 'text')],
        annotations: {
          'heading': {'kind': 'major'},
        },
      );
      final equalChapter = Chapter(
        genesis,
        1,
        const [Verse(genesis, 1, 1, 'text')],
        annotations: {
          'heading': {'kind': 'major'},
        },
      );
      final firstBook = Book(
        genesis,
        [firstChapter],
        annotations: {
          'aliases': ['Beginning'],
        },
      );
      final equalBook = Book(
        genesis,
        [equalChapter],
        annotations: {
          'aliases': ['Beginning'],
        },
      );

      expect(firstChapter, equalChapter);
      expect(firstChapter.hashCode, equalChapter.hashCode);
      expect(firstBook, equalBook);
      expect(firstBook.hashCode, equalBook.hashCode);
      expect(firstBook.toJsonValue(), {
        'aliases': ['Beginning'],
        'name': 'Genesis',
        'chapters': {
          '1': {
            'heading': {'kind': 'major'},
            'verses': {'1': 'text'},
          },
        },
      });
      expect(
        () => (firstBook.annotations['aliases']! as List<Object?>).add('x'),
        throwsUnsupportedError,
      );
      expect(firstChapter.copyWith(annotations: const {}).annotations, isEmpty);
      expect(firstBook.copyWith(name: 'Genesis custom').name, 'Genesis custom');
    });

    test('reject structural annotations and blank book names', () {
      expect(
        () => Chapter(genesis, 1, const [], annotations: {'verses': []}),
        throwsArgumentError,
      );
      expect(
        () => Book(genesis, const [], annotations: {'chapters': {}}),
        throwsArgumentError,
      );
      expect(
        () => Book(genesis, const [], annotations: {'name': 'Other'}),
        throwsArgumentError,
      );
      expect(() => Book(genesis, const [], name: '  '), throwsArgumentError);
    });
  });

  group('Persistable UI keys', () {
    test('BibleLocation copies and round-trips safely', () {
      const original = BibleLocation(book: genesis, chapter: 1, verse: 2);
      final restored = BibleLocation.fromJson(original.toJson());

      expect(restored, original);
      expect(original.copyWith(chapter: 3).verse, 2);
      expect(
        original.copyWith(verse: null),
        const BibleLocation(book: genesis, chapter: 1),
      );
      expect(
        BibleLocation.fromJson({'book': 'Genesis', 'chapter': 1}),
        const BibleLocation(book: genesis, chapter: 1),
      );
      expect(
        () => BibleLocation.fromJson({'book': 'gn', 'chapter': '1'}),
        throwsFormatException,
      );
      expect(
        () => BibleLocation.fromJson({'book': 'unknown', 'chapter': 1}),
        throwsFormatException,
      );
      expect(() => original.copyWith(verse: 0), throwsArgumentError);
      expect(() => original.copyWith(verse: '2'), throwsArgumentError);
    });

    test('BibleVerseKey is edition-aware and JSON-restorable', () {
      final key = BibleVerseKey(
        editionId: 'eng-kjv-1769',
        location: const BibleLocation(book: genesis, chapter: 1, verse: 1),
      );
      final restored = BibleVerseKey.fromJson(key.toJson());

      expect(restored, key);
      expect(restored.hashCode, key.hashCode);
      expect(
        restored.toVerseRef(),
        const VerseRef(book: genesis, chapter: 1, verse: 1),
      );
      expect(
        BibleVerseKey.fromVerse(
          'eng-kjv-1769',
          const Verse(genesis, 1, 1, 'text'),
        ),
        key,
      );
      expect(key.copyWith(editionId: 'eng-web').editionId, 'eng-web');
      expect(
        BibleVerseKey(editionId: 'eng-web', location: key.location),
        isNot(key),
      );
    });

    test('BibleVerseKey rejects ambiguous or malformed state', () {
      expect(
        () => BibleVerseKey(
          editionId: ' ',
          location: const BibleLocation(book: genesis, chapter: 1, verse: 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => BibleVerseKey(
          editionId: ' eng-kjv-1769 ',
          location: const BibleLocation(
            book: genesis,
            chapter: 1,
            verse: 1,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => BibleVerseKey(
          editionId: 'eng-kjv-1769',
          location: const BibleLocation(book: genesis, chapter: 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => BibleVerseKey.fromJson({
          'editionId': 'eng-kjv-1769',
          'location': {'book': 'gn', 'chapter': 1},
        }),
        throwsFormatException,
      );
      expect(
        () => BibleVerseKey.fromJson({
          'editionId': 1,
          'location': {'book': 'gn', 'chapter': 1, 'verse': 1},
        }),
        throwsFormatException,
      );
    });
  });
}
