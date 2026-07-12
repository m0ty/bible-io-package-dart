import 'dart:convert';
import 'dart:io';

/// Load and decode a UTF-8 Bible JSON file on platforms that support dart:io.
Future<String> loadBibleJson(
  String path, {
  void Function(double progress)? onProgress,
}) async {
  final file = File(path);
  final fileSize = await file.length();
  final buffer = StringBuffer();
  final stringSink = StringConversionSink.withCallback(buffer.write);
  final byteSink = utf8.decoder.startChunkedConversion(stringSink);
  var bytesRead = 0;
  var lastProgress = -1.0;

  void reportProgress(double value) {
    if (value != lastProgress) {
      lastProgress = value;
      onProgress?.call(value);
    }
  }

  await for (final chunk in file.openRead()) {
    byteSink.add(chunk);
    bytesRead += chunk.length;
    final fraction = fileSize == 0 ? 1.0 : bytesRead / fileSize;
    reportProgress(fraction > 1 ? 1.0 : fraction);
  }
  byteSink.close();

  reportProgress(1.0);
  return buffer.toString();
}
