import 'dart:io';

Future<Map<String, String>> generateFileHeaders(File file) async {
  final stat = await file.stat();

  return {
    HttpHeaders.contentLengthHeader: stat.size.toString(),
    HttpHeaders.contentTypeHeader: 'binary/octet-stream',
    'Content-Disposition': 'attachment; filename="cool.zip"'
  };
}
