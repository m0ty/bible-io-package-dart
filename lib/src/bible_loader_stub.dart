/// File-path loading is only available on platforms with dart:io.
Future<String> loadBibleJson(
  String path, {
  void Function(double progress)? onProgress,
}) {
  return Future.error(
    UnsupportedError(
      'Bible.load(path) requires dart:io. Use Bible.loadAsset(), '
      'Bible.fromUtf8Bytes(), or Bible.fromDecodedJson() on this platform.',
    ),
  );
}
