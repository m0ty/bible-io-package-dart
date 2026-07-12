import 'dart:convert';

import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  group('Platform-neutral loading', () {
    test(
      'loads from asset bundles, UTF-8 bytes, and decoded JSON maps',
      () async {
        final jsonMap = _minimalBibleJson();
        final jsonString = jsonEncode(jsonMap);
        final source = BibleSource.fromAssetPath(
          'bible_io_json/English/kjv.json',
        );
        final bundle = _FakeAssetBundle({'bibles/kjv.json': jsonString});

        final assetBible = await Bible.loadAsset(
          bundle,
          'bibles/kjv.json',
          source: source,
        );
        final bytesBible = Bible.fromUtf8Bytes(utf8.encode(jsonString));
        final decodedBible = Bible.fromDecodedJson(jsonMap);

        expect(
          assetBible.getVerse(BibleBookEnum.genesis, 1, 1).text,
          'Alpha beta.',
        );
        expect(assetBible.source, source);
        expect(
          bytesBible.getVerse(BibleBookEnum.genesis, 1, 2).text,
          'Gamma delta.',
        );
        expect(decodedBible.books.single.name, 'Genesis');
      },
    );
  });

  group('Bible source metadata and catalogs', () {
    test('derives source metadata from asset paths', () {
      final source = BibleSource.fromAssetPath(
        'bible_io_json/English/kjv.json',
      );

      expect(source.id, 'english_kjv');
      expect(source.assetPath, 'bible_io_json/English/kjv.json');
      expect(source.languageName, 'English');
      expect(source.languageCode, 'en');
      expect(source.abbreviation, 'KJV');
      expect(source.translationName, 'KJV');
    });

    test('derives language codes from bible_io_references identifiers', () {
      const identifiers = {
        'Hindi': 'hi',
        'hin': 'hi',
        'Indonesian': 'id',
        'id': 'id',
        'Korean': 'ko',
        'Tagalog': 'tl',
        'fil': 'tl',
        'Vietnamese': 'vi',
      };

      for (final entry in identifiers.entries) {
        final source = BibleSource.fromAssetPath(
          'bible_io_json/${entry.key}/translation.json',
        );
        expect(
          source.languageCode,
          entry.value,
          reason: 'language identifier ${entry.key}',
        );
      }

      expect(
        BibleSource.fromAssetPath(
          'bible_io_json/Italian/cei.json',
        ).languageCode,
        'it',
      );
    });

    test('parses catalog sources from JSON lists and maps', () {
      final catalog = BibleCatalog.fromDecodedJson({
        'sources': [
          {
            'id': 'kjv',
            'assetPath': 'bible_io_json/English/kjv.json',
            'translationName': 'King James Version',
            'abbreviation': 'KJV',
            'languageCode': 'en',
          },
          'bible_io_json/Hebrew/wlc.json',
        ],
      });

      expect(catalog.sources.length, 2);
      expect(catalog.findById('kjv')?.translationName, 'King James Version');
      expect(catalog.forLanguage('en').single.abbreviation, 'KJV');
      expect(catalog.forLanguage('he').single.direction, TextDirectionHint.rtl);
    });

    test('parses nested language maps without treating IDs as paths', () {
      final catalog = BibleCatalog.fromDecodedJson({
        'English': {
          'kjv': 'translations/kjv.json',
          'web': 'translations/web.json',
        },
      });

      expect(catalog.sources, hasLength(2));
      expect(catalog.sources.map((source) => source.id), ['kjv', 'web']);
      expect(catalog.sources.map((source) => source.assetPath), [
        'translations/kjv.json',
        'translations/web.json',
      ]);
      expect(
        catalog.sources.map((source) => source.languageName),
        everyElement('English'),
      );
    });

    test('attaches richer metadata to loaded Bibles', () {
      final bible = Bible.fromDecodedJson(
        _minimalBibleJson(
          metadata: {
            'translationName': 'King James Version',
            'abbreviation': 'KJV',
            'languageCode': 'en',
            'license': 'Public Domain',
            'canon': 'protestant',
            'versionDate': '1769-01-01',
          },
        ),
      );

      expect(bible.translationName, 'King James Version');
      expect(bible.abbreviation, 'KJV');
      expect(bible.languageCode, 'en');
      expect(bible.license, 'Public Domain');
      expect(bible.canon, 'protestant');
      expect(bible.versionDate, DateTime(1769));
    });

    test('round-trips a source nested inside serialized metadata', () {
      final source = BibleSource(
        id: 'kjv',
        assetPath: 'bible_io_json/English/kjv.json',
        languageName: 'English',
        languageCode: 'en',
        translationName: 'King James Version',
        abbreviation: 'KJV',
        year: 1769,
        direction: TextDirectionHint.ltr,
        sourceName: 'Public Domain Text',
        license: 'Public Domain',
        canon: 'protestant',
        versionDate: DateTime(1769),
      );
      final bible = Bible.fromDecodedJson(_minimalBibleJson(), source: source);

      final restored = Bible.fromJson(bible.toJson());

      expect(restored.source, isNotNull);
      expect(restored.source!.toJson(), source.toJson());
    });

    test('derives the Bible language from source metadata when omitted', () {
      final json = _minimalBibleJson()..remove('language');
      const source = BibleSource(
        id: 'wlc',
        assetPath: 'bible_io_json/Hebrew/wlc.json',
        languageName: 'Hebrew',
        languageCode: 'he',
        translationName: 'Westminster Leningrad Codex',
        abbreviation: 'WLC',
      );

      final bible = Bible.fromDecodedJson(json, source: source);

      expect(bible.language, BibleLanguageEnum.hebrew);
    });
  });
}

Map<String, dynamic> _minimalBibleJson({Map<String, dynamic>? metadata}) {
  return {
    'language': 'English',
    'metadata': ?metadata,
    'books': {
      'gn': {
        'name': 'Genesis',
        'chapters': {
          '1': {'1': 'Alpha beta.', '2': 'Gamma delta.'},
        },
      },
    },
  };
}

class _FakeAssetBundle {
  final Map<String, String> assets;

  _FakeAssetBundle(this.assets);

  Future<String> loadString(String key) async => assets[key]!;
}
