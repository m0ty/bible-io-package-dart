import 'package:unorm_dart/unorm_dart.dart' as unicode;

final RegExp unicodeTermPattern = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);
final RegExp _unicodeMarkPattern = RegExp(r'\p{M}+', unicode: true);

/// Normalize text for searching while preserving meaningful marks by default.
String normalizeSearchText(
  String text, {
  bool caseSensitive = false,
  bool normalizeUnicode = true,
  bool ignoreDiacritics = false,
}) {
  // Most Bible translations are ASCII-heavy. Avoid normalization tables for
  // the overwhelmingly common fast path.
  final isAscii = _isAscii(text);
  if (isAscii) return caseSensitive ? text : text.toLowerCase();
  var result = normalizeUnicode ? unicode.nfc(text) : text;
  if (!caseSensitive) {
    result = result
        .toLowerCase()
        .replaceAll('\u00df', 'ss')
        .replaceAll('\u03c2', '\u03c3')
        .replaceAll('\u017f', 's');
  }
  if (ignoreDiacritics) {
    result = unicode.nfd(result).replaceAll(_unicodeMarkPattern, '');
    result = unicode.nfc(result);
  } else if (normalizeUnicode) {
    result = unicode.nfc(result);
  }
  return result;
}

bool _isAscii(String text) {
  for (final unit in text.codeUnits) {
    if (unit >= 0x80) return false;
  }
  return true;
}

/// Extract normalized Unicode letter/mark/number search terms.
List<String> tokenizeSearchText(
  String text, {
  bool caseSensitive = false,
  bool normalizeUnicode = true,
  bool ignoreDiacritics = false,
}) {
  return List<String>.unmodifiable(
    unicodeTermPattern.allMatches(text).map((match) {
      return normalizeSearchText(
        match.group(0)!,
        caseSensitive: caseSensitive,
        normalizeUnicode: normalizeUnicode,
        ignoreDiacritics: ignoreDiacritics,
      );
    }).where((token) => token.isNotEmpty),
  );
}

/// Extract original, unnormalized Unicode words for display and statistics.
List<String> extractUnicodeWords(String text) {
  return List<String>.unmodifiable(
    unicodeTermPattern
        .allMatches(text)
        .map((match) => match.group(0)!)
        .where((word) => word.isNotEmpty),
  );
}

/// Whether [text] contains [query] after applying the selected normalization.
bool containsNormalizedText(
  String text,
  String query, {
  bool caseSensitive = false,
  bool normalizeUnicode = true,
  bool ignoreDiacritics = false,
}) {
  final normalizedQuery = normalizeSearchText(
    query,
    caseSensitive: caseSensitive,
    normalizeUnicode: normalizeUnicode,
    ignoreDiacritics: ignoreDiacritics,
  );
  if (normalizedQuery.isEmpty) return false;
  return normalizeSearchText(
    text,
    caseSensitive: caseSensitive,
    normalizeUnicode: normalizeUnicode,
    ignoreDiacritics: ignoreDiacritics,
  ).contains(normalizedQuery);
}

/// Whether a token contains a script that normally does not delimit every word
/// with whitespace.
bool usesUnspacedWordBoundaries(String token) {
  return token.runes.any(_isUnspacedScriptRune);
}

bool _isUnspacedScriptRune(int rune) {
  return (rune >= 0x3400 && rune <= 0x4dbf) || // CJK Extension A
      (rune >= 0x4e00 && rune <= 0x9fff) || // CJK Unified
      (rune >= 0xf900 && rune <= 0xfaff) || // CJK compatibility
      (rune >= 0x20000 && rune <= 0x323af) || // CJK extensions
      (rune >= 0x3040 && rune <= 0x309f) || // Hiragana
      (rune >= 0x30a0 && rune <= 0x30ff) || // Katakana
      (rune >= 0x31f0 && rune <= 0x31ff) || // Katakana extensions
      (rune >= 0xff66 && rune <= 0xff9d) || // Half-width Katakana
      (rune >= 0x0e00 && rune <= 0x0e7f) || // Thai
      (rune >= 0x0e80 && rune <= 0x0eff) || // Lao
      (rune >= 0x1000 && rune <= 0x109f) || // Myanmar
      (rune >= 0xa9e0 && rune <= 0xa9ff) || // Myanmar Extended-B
      (rune >= 0xaa60 && rune <= 0xaa7f) || // Myanmar Extended-A
      (rune >= 0x1780 && rune <= 0x17ff); // Khmer
}
