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

  await for (final chunk in file.openRead()) {
    byteSink.add(chunk);
    bytesRead += chunk.length;
    onProgress?.call(fileSize == 0 ? 1.0 : bytesRead / fileSize);
  }
  byteSink.close();

  onProgress?.call(1.0);
  return buffer.toString();
}
