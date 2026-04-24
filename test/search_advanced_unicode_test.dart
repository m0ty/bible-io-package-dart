import 'dart:convert';
import 'dart:io';

import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  group('UTF-8 loading', () {
    test('preserves Arabic, Russian, and Chinese text', () async {
      final tempDir = Directory.systemTemp.createTempSync('bible_io_utf8_');
      final tempFile = File('${tempDir.path}/unicode_bible.json');

      final arabic = 'في البدء خلق الله السماوات والأرض';
      final russian = 'В начале сотворил Бог небо и землю';
      final chinese = '起初，神创造天地。';

      try {
        tempFile.writeAsStringSync(
          jsonEncode({
            'language': 'English',
            'books': {
              'gn': {
                'name': 'Genesis',
                'chapters': {
                  '1': {'1': arabic, '2': russian, '3': chinese},
                },
              },
            },
          }),
          encoding: utf8,
        );

        final bible = await Bible.load(tempFile.path);

        expect(bible.getVerse(BibleBookEnum.genesis, 1, 1).text, arabic);
        expect(bible.getVerse(BibleBookEnum.genesis, 1, 2).text, russian);
        expect(bible.getVerse(BibleBookEnum.genesis, 1, 3).text, chinese);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('Unicode search', () {
    late Bible bible;

    setUp(() {
      bible = _unicodeBible();
    });

    test('finds non-English terms', () {
      expect(bible.search('الله').map((v) => v.verseNumber), [1]);
      expect(bible.search('Бог').map((v) => v.verseNumber), [2]);
      expect(
        bible.searchAdvanced(text: 'الله').verses.map((v) => v.verseNumber),
        [1],
      );
      expect(
        bible.searchAdvanced(text: 'Бог').verses.map((v) => v.verseNumber),
        [2],
      );
      expect(
        bible.searchAdvanced(text: '创造').verses.map((v) => v.verseNumber),
        [3],
      );
    });

    test('keeps substring phrase search distinct from whole-word search', () {
      expect(
        bible.searchAdvanced(text: 'cat').verses.map((v) => v.verseNumber),
        [4, 8],
      );
      expect(
        bible
            .searchAdvanced(text: 'cat', wholeWords: true)
            .verses
            .map((v) => v.verseNumber),
        [4],
      );
    });

    test(
      'matches whole words across punctuation, hyphens, and apostrophes',
      () {
        expect(
          bible
              .searchAdvanced(text: 'cat', wholeWords: true)
              .verses
              .map((v) => v.verseNumber),
          [4],
        );
        expect(
          bible
              .searchAdvanced(text: 'sister', wholeWords: true)
              .verses
              .map((v) => v.verseNumber),
          [5],
        );
        expect(
          bible
              .searchAdvanced(text: 'мир', wholeWords: true)
              .verses
              .map((v) => v.verseNumber),
          [6],
        );
      },
    );
  });

  group('Search modes', () {
    late Bible bible;

    setUp(() {
      bible = _modeBible();
    });

    test(
      'exact matches phrases, all matches all terms, any matches any term',
      () {
        expect(
          bible
              .searchAdvanced(text: 'alpha beta', mode: SearchMode.exact)
              .verses
              .map((v) => v.verseNumber),
          [1],
        );
        expect(
          bible
              .searchAdvanced(text: 'alpha beta', mode: SearchMode.all)
              .verses
              .map((v) => v.verseNumber),
          [1, 2],
        );
        expect(
          bible
              .searchAdvanced(text: 'alpha beta', mode: SearchMode.any)
              .verses
              .map((v) => v.verseNumber),
          [1, 2, 3, 4],
        );
      },
    );

    test(
      'search remains an all-terms search and differs from exact phrases',
      () {
        final searchResults = bible
            .search('alpha beta')
            .map((v) => v.verseNumber);
        final exactResults = bible
            .searchAdvanced(text: 'alpha beta')
            .verses
            .map((v) => v.verseNumber);
        final allResults = bible
            .searchAdvanced(text: 'alpha beta', mode: SearchMode.all)
            .verses
            .map((v) => v.verseNumber);

        expect(searchResults, [1, 2]);
        expect(exactResults, [1]);
        expect(allResults, searchResults);
      },
    );

    test('maxResults limits indexed results in canonical order', () {
      final results = bible.searchAdvanced(
        text: 'beta alpha',
        mode: SearchMode.any,
        maxResults: 2,
      );

      expect(results.verses.map((v) => v.verseNumber), [1, 2]);
    });

    test('SearchOptions can drive the canonical advanced search path', () {
      final results = bible.searchWithOptions(
        'alpha beta',
        const SearchOptions(mode: SearchMode.all, maxResults: 1),
      );

      expect(results.verses.map((v) => v.verseNumber), [1]);
    });
  });
}

Bible _unicodeBible() {
  return Bible.fromJson(
    jsonEncode({
      'language': 'English',
      'books': {
        'gn': {
          'name': 'Genesis',
          'chapters': {
            '1': {
              '1': 'في البدء خلق الله السماوات والأرض',
              '2': 'В начале сотворил Бог небо и землю',
              '3': '起初，神创造天地。',
              '4': 'A scatter of cat-like words.',
              '5': "The sister's house is near.",
              '6': 'Слово, мир и словообразование.',
              '7': 'мировой порядок',
              '8': 'A scatter pattern.',
            },
          },
        },
      },
    }),
  );
}

Bible _modeBible() {
  return Bible.fromJson(
    jsonEncode({
      'language': 'English',
      'books': {
        'gn': {
          'name': 'Genesis',
          'chapters': {
            '1': {
              '1': 'alpha beta gamma',
              '2': 'alpha gamma beta',
              '3': 'alpha delta',
              '4': 'beta delta',
            },
          },
        },
      },
    }),
  );
}
