import 'package:castboard_core/classes/PhotoRef.dart';
import 'package:shelf/shelf.dart';

bool matchImageEtag(Request request, ImageRef ref) {
  return request.headers.containsKey('If-None-Match') &&
      request.headers['If-None-Match'] == ref.uid;
}
