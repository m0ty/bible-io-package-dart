import 'dart:io';

import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  late Bible bible;

  setUp(() async {
    // Use the real KJV Bible JSON file for testing
    bible = await Bible.load('test/bible_versions/en_kjv.json');
  });

  group('Bible loading and initialization', () {
    test('loads Bible from valid JSON file', () {
      expect(bible.language, isNotNull);
      expect(bible.books.length, 66); // KJV has 66 books
    });

    test('throws exception for non-existent file', () async {
      expect(Bible.load('/non/existent/file.json'), throwsA(isA<FileSystemException>()));
    });

    test('throws exception for invalid JSON', () async {
      final tempFile = File('${Directory.systemTemp.path}/invalid.json');
      tempFile.writeAsStringSync('invalid json');
      expect(Bible.load(tempFile.path), throwsA(isA<FormatException>()));
      await Future.delayed(Duration(milliseconds: 100)); // Allow async operation to complete
      tempFile.deleteSync();
    });

    test('throws exception for malformed Bible JSON', () async {
      final tempFile = File('${Directory.systemTemp.path}/malformed.json');
      tempFile.writeAsStringSync('{"invalid": "structure"}');
      expect(Bible.load(tempFile.path), throwsA(isA<TypeError>()));
      await Future.delayed(Duration(milliseconds: 100)); // Allow async operation to complete
      tempFile.deleteSync();
    });
  });
}