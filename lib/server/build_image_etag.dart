import 'package:castboard_core/classes/PhotoRef.dart';

Map<String, String> buildImageEtag(ImageRef ref) {
  if (ref == const ImageRef.none()) {
    return {};
  }

  return {'ETag': ref.uid};
}
