import 'dart:convert';

import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  group('content schema version 1', () {
    test('preserves identity, order, and annotations across a round trip', () {
      final data = _annotatedBibleJson();
      final bible = Bible.fromDecodedJson(data);

      expect(bible.schemaVersion, currentBibleSchemaVersion);
      expect(bible.id, 'example-2026');
      expect(bible.description, 'Schema fixture');
      expect(
        bible.books.map((book) => book.bookEnum),
        [BibleBookEnum.exodus, BibleBookEnum.genesis],
      );
      expect(bible.annotations['provider'], {'slug': 'example'});
      expect(bible.metadata.additional['customMetadata'], {
        'revision': 2,
      });

      final genesis = bible.getBook(BibleBookEnum.genesis);
      final chapter = genesis.getChapter(1);
      final verse = chapter.getVerse(1);
      expect(genesis.annotations['section'], 'Torah');
      expect(chapter.annotations['heading'], 'Creation');
      expect(verse.annotations['paragraphStart'], isTrue);

      final encoded = jsonDecode(bible.toJson()) as Map<String, dynamic>;
      expect(encoded['schemaVersion'], 1);
      expect(encoded['bookOrder'], ['ex', 'gn']);
      expect(encoded['provider'], {'slug': 'example'});
      expect(
        encoded['metadata'],
        containsPair('customMetadata', {'revision': 2}),
      );

      final restored = Bible.fromDecodedJson(encoded);
      expect(restored.id, bible.id);
      expect(restored.books, bible.books);
      expect(restored.annotations, bible.annotations);
      expect(restored.metadata, bible.metadata);
    });

    test('legacy maps use enum canon order, never JSON insertion order', () {
      final bible = Bible.fromDecodedJson({
        'books': {
          'ex': {
            'chapters': {
              '1': {'1': 'Exodus'},
            },
          },
          'gn': {
            'chapters': {
              '1': {'1': 'Genesis'},
            },
          },
        },
      });

      expect(
        bible.books.map((book) => book.bookEnum),
        [BibleBookEnum.genesis, BibleBookEnum.exodus],
      );
      expect(
        jsonDecode(bible.toJson())['bookOrder'],
        ['gn', 'ex'],
      );
    });

    test('rejects unsupported versions and incomplete explicit order', () {
      expect(
        () => Bible.fromDecodedJson({
          'schemaVersion': 2,
          'books': {
            'gn': {
              'chapters': {
                '1': {'1': 'text'},
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
              .having(
                (error) => error.path,
                'path',
                r'$.schemaVersion',
              ),
        ),
      );

      final data = _annotatedBibleJson();
      data['bookOrder'] = ['gn'];
      expect(
        () => Bible.fromDecodedJson(data),
        throwsA(
          isA<BibleDataFormatError>().having(
            (error) => error.path,
            'path',
            r'$.bookOrder',
          ),
        ),
      );

      final ambiguous = _annotatedBibleJson();
      final ambiguousBooks = ambiguous['books']! as Map<String, dynamic>;
      (ambiguousBooks['gn']! as Map<String, dynamic>)['name'] = 'Same';
      (ambiguousBooks['ex']! as Map<String, dynamic>)['name'] = 'same';
      expect(
        () => Bible.fromDecodedJson(ambiguous),
        throwsA(
          isA<BibleDataFormatError>().having(
            (error) => error.path,
            'path',
            r'$.books',
          ),
        ),
      );
    });

    test('strict and permissive policies differ only on skeletal content', () {
      expect(
        () => Bible.fromDecodedJson({'books': <String, dynamic>{}}),
        throwsA(isA<BibleDataFormatError>()),
      );

      final partial = Bible.fromDecodedJson(
        {'books': <String, dynamic>{}},
        options: const BibleLoadOptions(
          validation: BibleDataValidationOptions.permissive,
          searchIndexMode: SearchIndexMode.disabled,
        ),
      );
      expect(partial.books, isEmpty);
      expect(partial.search('anything'), isEmpty);

      expect(
        () => Bible.fromDecodedJson(
          {'books': []},
          options: const BibleLoadOptions(
            validation: BibleDataValidationOptions.permissive,
          ),
        ),
        throwsA(
          isA<BibleDataFormatError>().having(
            (error) => error.code,
            'code',
            BibleDataFormatErrorCode.invalidType,
          ),
        ),
      );
    });

    test('permissive mode still rejects explicit null structural fields', () {
      const permissive = BibleLoadOptions(
        validation: BibleDataValidationOptions.permissive,
      );
      final invalidDocuments = <Map<String, dynamic>>[
        {'schemaVersion': null, 'books': <String, dynamic>{}},
        {'books': null},
        {
          'books': {
            'gn': {'chapters': null},
          },
        },
        {
          'books': {
            'gn': {
              'chapters': {
                '1': {'verses': null},
              },
            },
          },
        },
        {
          'books': {
            'gn': {
              'chapters': {
                '1': {
                  '1': {'text': null},
                },
              },
            },
          },
        },
      ];

      for (final document in invalidDocuments) {
        expect(
          () => Bible.fromDecodedJson(document, options: permissive),
          throwsA(
            isA<BibleDataFormatError>().having(
              (error) => error.code,
              'code',
              BibleDataFormatErrorCode.invalidType,
            ),
          ),
        );
      }

      final nullOrder = _annotatedBibleJson()..['bookOrder'] = null;
      expect(
        () => Bible.fromDecodedJson(nullOrder, options: permissive),
        throwsA(isA<BibleDataFormatError>()),
      );
    });
  });

  group('loading and index lifecycle', () {
    test('async construction supports lazy and disabled indexes', () async {
      final encoded = jsonEncode(_annotatedBibleJson());
      final lazy = await Bible.fromJsonAsync(
        encoded,
        options: const BibleLoadOptions(
          searchIndexMode: SearchIndexMode.lazy,
        ),
      );

      expect(lazy.hasSearchIndex, isFalse);
      expect(lazy.search('created'), isNotEmpty);
      expect(lazy.hasSearchIndex, isTrue);
      lazy.clearSearchIndex();
      expect(lazy.hasSearchIndex, isFalse);
      await lazy.prewarmSearchIndexAsync();
      expect(lazy.hasSearchIndex, isTrue);
      lazy.clearSearchIndex();
      lazy.prewarmSearchIndex();
      expect(lazy.hasSearchIndex, isTrue);

      final disabled = Bible.fromJson(
        encoded,
        options: const BibleLoadOptions(
          searchIndexMode: SearchIndexMode.disabled,
        ),
      );
      expect(disabled.search('created'), isNotEmpty);
      disabled.prewarmSearchIndex();
      expect(disabled.hasSearchIndex, isFalse);
    });

    test('asset loading reports stable UI progress phases', () async {
      final progress = <BibleLoadProgress>[];
      final bundle = _FakeAssetBundle(jsonEncode(_annotatedBibleJson()));

      final bible = await Bible.loadAsset(
        bundle,
        'example.json',
        onLoadProgress: progress.add,
      );

      expect(bible.id, 'example-2026');
      expect(
        progress.map((value) => value.phase),
        [
          BibleLoadPhase.reading,
          BibleLoadPhase.reading,
          BibleLoadPhase.processing,
          BibleLoadPhase.processing,
          BibleLoadPhase.complete,
        ],
      );
      expect(
        progress.map((value) => value.fraction),
        orderedEquals([0, 0.65, 0.65, 1, 1]),
      );
    });
  });

  group('edition-aware navigation', () {
    test('follows declared cross-book order and creates persisted keys', () {
      final bible = Bible.fromDecodedJson(_annotatedBibleJson());
      final exodus = bible.getVerse(BibleBookEnum.exodus, 1, 1);
      final genesis = bible.getVerse(BibleBookEnum.genesis, 1, 1);

      expect(bible.nextVerse(exodus.location), genesis.location);
      expect(bible.previousVerse(genesis.location), exodus.location);
      expect(bible.nextVerse(genesis.location), isNull);
      expect(
        bible.getVerseRangeByRef(
          'Exodus Local 1:1-Genesis Local 1:1',
        ),
        [exodus, genesis],
      );
      expect(
        bible.parseReference('Exodus Local 1:1-Genesis Local 1:1'),
        isA<ParseSuccess<Reference>>(),
      );
      expect(
        bible.getPassage('Exodus Local 1:1-Genesis Local 1:1'),
        [exodus, genesis],
      );
      expect(bible.keyForVerse(genesis).editionId, 'example-2026');
      expect(bible.keyForLocation(genesis.location).location, genesis.location);
      expect(bible.formatLocation(genesis.location), 'Genesis Local 1:1');
    });
  });
}

Map<String, dynamic> _annotatedBibleJson() {
  return {
    'schemaVersion': 1,
    'language': 'English',
    'provider': {'slug': 'example'},
    'metadata': {
      'id': 'example-2026',
      'description': 'Schema fixture',
      'translationName': 'Example Translation',
      'customMetadata': {'revision': 2},
    },
    'bookOrder': ['ex', 'gn'],
    'books': {
      'gn': {
        'name': 'Genesis Local',
        'section': 'Torah',
        'chapters': {
          '1': {
            'heading': 'Creation',
            'verses': {
              '1': {
                'text': 'In the beginning God created.',
                'paragraphStart': true,
              },
            },
          },
        },
      },
      'ex': {
        'name': 'Exodus Local',
        'chapters': {
          '1': {'1': 'These are the names.'},
        },
      },
    },
  };
}

class _FakeAssetBundle {
  final String content;

  const _FakeAssetBundle(this.content);

  Future<String> loadString(String key) async => content;
}
