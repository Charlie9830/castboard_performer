import 'package:shelf/shelf.dart';
import 'package:shelf_plus/shelf_plus.dart';
import 'package:shelf_multipart/multipart.dart';

/// Reads a multipart Request and returns a buffer containing the data.
Future<List<int>> readMultipartFileRequest(Request req) async {
  final buffer = <int>[];
  await for (final part in req.parts) {
    final String? contentDisposition = part.headers['content-disposition'];
    const fileFieldMatch = 'name="file"';

    // If headers for this part match our schema, add the contents to the buffer.
    if (contentDisposition != null &&
        contentDisposition.contains(fileFieldMatch)) {
      buffer.addAll(await part.readBytes());
    }
  }

  return buffer;
}
