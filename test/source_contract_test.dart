import 'package:bible_io/src/errors.dart';
import 'package:bible_io/src/result.dart';
import 'package:bible_io/src/source.dart';
import 'package:test/test.dart';

void main() {
  group('BibleDataFormatError', () {
    test('exposes stable machine-readable diagnostics', () {
      final cause = FormatException('bad input');
      final stack = StackTrace.current;
      final error = BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidType,
        path: r'$.books.gn',
        message: 'Expected an object.',
        value: 42,
        cause: cause,
        stackTrace: stack,
      );

      expect(error.code, 'invalid_type');
      expect(error.path, r'$.books.gn');
      expect(error.value, 42);
      expect(error.cause, same(cause));
      expect(error.stackTrace, same(stack));
      expect(error.toString(), contains(r'$.books.gn'));
    });
  });

  group('BibleSource', () {
    const source = BibleSource(
      id: 'kjv',
      assetPath: 'bibles/English/kjv.json',
      languageName: 'English',
      languageCode: 'en',
      translationName: 'King James Version',
      abbreviation: 'KJV',
      description: 'Oxford 1769 text',
    );

    test('has value semantics and a nullable-aware copyWith', () {
      final equal = BibleSource.fromDecodedJson(source.toJson());

      expect(equal, source);
      expect(equal.hashCode, source.hashCode);
      expect(source.copyWith(description: null).description, isNull);
      expect(source.copyWith(translationName: 'KJV 1769').id, 'kjv');
    });

    test('preserves deeply immutable source extension fields', () {
      final parsed = BibleSource.fromDecodedJson({
        ...source.toJson(),
        'provider': {
          'revision': 2,
          'links': ['https://example.test'],
        },
      });

      expect(parsed.additional['provider'], {
        'revision': 2,
        'links': ['https://example.test'],
      });
      expect(parsed.toJson()['provider'], parsed.additional['provider']);
      final provider = parsed.additional['provider']! as Map;
      expect(() => provider['revision'] = 3, throwsUnsupportedError);
      expect(BibleSource.fromDecodedJson(parsed.toJson()), parsed);
    });

    test('rejects non-canonical source identifiers', () {
      expect(
        () => BibleSource.fromDecodedJson({
          ...source.toJson(),
          'id': ' kjv ',
        }),
        throwsA(isA<BibleDataFormatError>()),
      );
    });

    test(
      'retains const construction but validates runtime-required fields',
      () {
        const invalid = BibleSource(
          id: '',
          assetPath: 'bible.json',
          languageName: 'English',
          languageCode: 'en',
          translationName: 'Example',
          abbreviation: 'EX',
        );

        expect(
          invalid.validate,
          throwsA(
            isA<BibleDataFormatError>()
                .having(
                  (error) => error.code,
                  'code',
                  BibleDataFormatErrorCode.missingField,
                )
                .having((error) => error.path, 'path', r'$.id'),
          ),
        );
      },
    );
  });

  group('BibleMetadata', () {
    test('preserves root identity and unknown metadata deeply', () {
      final nested = <String, Object?>{
        'provider': <String, Object?>{
          'name': 'Bible Provider',
          'links': <Object?>['https://example.test'],
        },
      };
      final metadata = BibleMetadata.fromDecodedJson({
        'id': 'eng-kjv-1769',
        'description': 'A stable edition',
        'schemaVersion': 1,
        'metadata': nested,
      });

      expect(metadata.id, 'eng-kjv-1769');
      expect(metadata.description, 'A stable edition');
      expect(metadata.additional['schemaVersion'], 1);
      expect(metadata.additional['provider'], nested['provider']);
      expect(metadata.toJson()['provider'], nested['provider']);

      final provider = metadata.additional['provider']! as Map;
      final links = provider['links']! as List;
      expect(() => provider['name'] = 'changed', throwsUnsupportedError);
      expect(() => links.add('changed'), throwsUnsupportedError);

      (nested['provider']! as Map<String, Object?>)['name'] = 'mutated input';
      expect(provider['name'], 'Bible Provider');
    });

    test('rejects blank or whitespace-padded edition identity', () {
      for (final id in ['', ' edition ']) {
        expect(
          () => BibleMetadata.fromDecodedJson({'id': id}),
          throwsA(isA<BibleDataFormatError>()),
        );
      }
    });

    test('uses metadata, root, then source precedence', () {
      final metadata = BibleMetadata.fromDecodedJson({
        'id': 'root-id',
        'description': 'root description',
        'license': 'root license',
        'source': {
          'id': 'source-id',
          'assetPath': 'bibles/English/kjv.json',
          'languageName': 'English',
          'languageCode': 'en',
          'translationName': 'Source name',
          'abbreviation': 'SRC',
          'description': 'source description',
          'license': 'source license',
        },
        'metadata': {'translationName': 'Metadata name', 'custom': true},
      });

      expect(metadata.id, 'root-id');
      expect(metadata.description, 'root description');
      expect(metadata.translationName, 'Metadata name');
      expect(metadata.license, 'root license');
      expect(metadata.additional, containsPair('custom', true));
    });

    test('keeps source and metadata extensions at their original levels', () {
      const embeddedSource = BibleSource(
        id: 'kjv',
        assetPath: 'bibles/English/kjv.json',
        languageName: 'English',
        languageCode: 'en',
        translationName: 'King James Version',
        abbreviation: 'KJV',
      );
      final metadata = BibleMetadata.fromDecodedJson({
        'source': {
          ...embeddedSource.toJson(),
          'custom': 'source value',
        },
        'metadata': {'custom': 'metadata value'},
      });

      expect(metadata.source!.additional['custom'], 'source value');
      expect(metadata.additional['custom'], 'metadata value');
      final encoded = metadata.toJson();
      expect((encoded['source'] as Map)['custom'], 'source value');
      expect(encoded['custom'], 'metadata value');
    });

    test(
      'uses an explicitly supplied source instead of an embedded source',
      () {
        const supplied = BibleSource(
          id: 'catalog-id',
          assetPath: 'catalog/English/kjv.json',
          languageName: 'English',
          languageCode: 'en',
          translationName: 'Catalog name',
          abbreviation: 'CAT',
        );
        final metadata = BibleMetadata.fromDecodedJson({
          'source': {
            'id': 'embedded-id',
            'assetPath': 'embedded/English/kjv.json',
            'languageName': 'English',
            'languageCode': 'en',
            'translationName': 'Embedded name',
            'abbreviation': 'EMB',
          },
        }, source: supplied);

        expect(metadata.source, supplied);
        expect(metadata.id, 'catalog-id');
        expect(metadata.translationName, 'Catalog name');
      },
    );

    test('rejects non-JSON and reserved extension values', () {
      expect(
        () => BibleMetadata.withAdditional(additional: {'bad': DateTime(2026)}),
        throwsA(
          isA<BibleDataFormatError>().having(
            (error) => error.code,
            'code',
            BibleDataFormatErrorCode.nonJsonValue,
          ),
        ),
      );
      expect(
        () => BibleMetadata.withAdditional(
          additional: const {'translationName': 'hidden'},
        ),
        throwsA(
          isA<BibleDataFormatError>().having(
            (error) => error.code,
            'code',
            BibleDataFormatErrorCode.reservedField,
          ),
        ),
      );
    });

    test(
      'merge helper gives explicit metadata precedence and attaches source',
      () {
        const source = BibleSource(
          id: 'source-id',
          assetPath: 'bibles/Hebrew/wlc.json',
          languageName: 'Hebrew',
          languageCode: 'he',
          translationName: 'WLC',
          abbreviation: 'WLC',
          direction: TextDirectionHint.rtl,
        );
        const metadata = BibleMetadata(
          translationName: 'Display name',
          license: 'Custom license note',
        );

        final merged = mergeBibleMetadata(
          metadata: metadata,
          source: source,
          fallbackLanguageName: 'Fallback',
        );

        expect(merged.source, source);
        expect(merged.id, 'source-id');
        expect(merged.translationName, 'Display name');
        expect(merged.languageName, 'Hebrew');
        expect(merged.direction, TextDirectionHint.rtl);
        expect(merged.license, 'Custom license note');
      },
    );
  });

  group('BibleCatalog', () {
    test('indexes IDs and has value semantics', () {
      final first = BibleCatalog.fromDecodedJson({
        'English': {'kjv': 'bibles/kjv.json', 'web': 'bibles/web.json'},
      });
      final second = BibleCatalog(first.sources);

      expect(first.findById('web')?.abbreviation, 'WEB');
      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('rejects duplicate and blank IDs', () {
      const source = BibleSource(
        id: 'same',
        assetPath: 'bibles/English/a.json',
        languageName: 'English',
        languageCode: 'en',
        translationName: 'A',
        abbreviation: 'A',
      );
      expect(
        () => BibleCatalog(const [source, source]),
        throwsA(
          isA<BibleDataFormatError>()
              .having(
                (error) => error.code,
                'code',
                BibleDataFormatErrorCode.duplicateId,
              )
              .having((error) => error.path, 'path', r'$.sources[1].id'),
        ),
      );

      expect(
        () => BibleCatalog.fromDecodedJson({
          'sources': [
            {
              'id': '   ',
              'assetPath': 'bibles/English/a.json',
              'languageName': 'English',
              'languageCode': 'en',
              'translationName': 'A',
              'abbreviation': 'A',
            },
          ],
        }),
        throwsA(
          isA<BibleDataFormatError>().having(
            (error) => error.path,
            'path',
            r'$.sources[0].id',
          ),
        ),
      );
    });

    test('rejects malformed entries instead of dropping them', () {
      expect(
        () => BibleCatalog.fromDecodedJson({
          'sources': [
            {'id': 'missing-path'},
          ],
        }),
        throwsA(
          isA<BibleDataFormatError>().having(
            (error) => error.path,
            'path',
            r'$.sources[0].assetPath',
          ),
        ),
      );

      expect(
        () => BibleCatalog.fromDecodedJson({
          'English': {'broken': 7},
        }),
        throwsA(
          isA<BibleDataFormatError>()
              .having(
                (error) => error.code,
                'code',
                BibleDataFormatErrorCode.invalidType,
              )
              .having((error) => error.path, 'path', r'$.English.broken'),
        ),
      );
    });

    test('wraps JSON decoding failures', () {
      expect(
        () => BibleCatalog.fromJson('{not JSON'),
        throwsA(
          isA<BibleDataFormatError>()
              .having(
                (error) => error.code,
                'code',
                BibleDataFormatErrorCode.invalidJson,
              )
              .having((error) => error.cause, 'cause', isA<FormatException>()),
        ),
      );
    });
  });

  group('Result failures', () {
    test('retain typed causes and stack traces across transformations', () {
      final stack = StackTrace.current;
      final error = BibleDataFormatError(
        code: BibleDataFormatErrorCode.invalidValue,
        path: r'$.books',
        message: 'Invalid books.',
        stackTrace: stack,
      );
      final result = Result<int>.failureFrom(error);
      final mapped = result.map((value) => value.toString());

      expect(result.error, 'Invalid books.');
      expect(result.cause, same(error));
      expect(result.stackTrace, same(stack));
      expect(mapped.cause, same(error));
      expect(mapped.stackTrace, same(stack));
      expect(
        () => mapped.value,
        throwsA(
          isA<ResultException>()
              .having((exception) => exception.cause, 'cause', same(error))
              .having(
                (exception) => exception.stackTrace,
                'stack',
                same(stack),
              ),
        ),
      );
    });

    test('keeps the existing string failure constructor compatible', () {
      const Result<int> result = Result.failure('not found');

      expect(result.error, 'not found');
      expect(result.cause, isNull);
      expect(result.stackTrace, isNull);
    });
  });
}
