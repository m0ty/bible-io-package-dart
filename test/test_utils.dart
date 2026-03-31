import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

/// Shared test utilities for Bible-related tests.
class BibleTestFixture {
  static Bible? _bible;

  /// Get a shared Bible instance for testing.
  /// Loads the KJV Bible once and reuses it across all tests.
  static Future<Bible> getBible() async {
    if (_bible == null) {
      _bible = await Bible.load('test/bible_versions/en_kjv.json');
    }
    return _bible!;
  }

  /// Reset the shared Bible instance (useful for testing different scenarios).
  static void reset() {
    _bible = null;
  }
}

/// Convenience function for tests that need a Bible instance.
/// Usage: `late Bible bible; setUp(() async => bible = await bibleFixture());`
Future<Bible> bibleFixture() => BibleTestFixture.getBible();

/// Alternative: Use setUpAll with a global variable approach
/// This is useful when you want to share setup across multiple test files
/// but still have per-file control.
///
/// Example usage in a test file:
/// ```dart
/// import 'test_utils.dart' as test_utils;
///
/// void main() {
///   late Bible bible;
///
///   setUpAll(() async {
///     bible = await test_utils.bibleFixture();
///   });
///
///   // Your tests here...
/// }
/// ```