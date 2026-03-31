import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  late Bible bible;

  setUp(() async {
    // Use the real KJV Bible JSON file for testing
    bible = await Bible.load('test/bible_versions/en_kjv.json');
  });

  // All tests have been reorganized into themed test files:
  // - bible_loading_test.dart: Bible loading and initialization tests
  // - book_navigation_test.dart: Book access and navigation tests
  // - chapter_navigation_test.dart: Chapter access and navigation tests
  // - verse_navigation_test.dart: Verse access and navigation tests
  // - search_functionality_test.dart: Search functionality tests
  // - reference_parsing_test.dart: Reference parsing tests
  // - data_validation_test.dart: Data validation and integrity tests
  // - boundary_performance_test.dart: Boundary conditions and performance tests

  test('placeholder test - all tests moved to themed files', () {
    expect(bible.books.length, 66);
  });
}