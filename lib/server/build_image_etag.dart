import 'package:castboard_core/classes/PhotoRef.dart';

Map<String, String> buildImageEtag(ImageRef ref) {
  if (ref == const ImageRef.none() || ref.uid == null) {
    return {};
  }

  return {'ETag': ref.uid};
}
