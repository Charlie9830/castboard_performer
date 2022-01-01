import 'dart:io';

import 'package:shelf_plus/shelf_plus.dart';

class PrepareShowfileDownloadTuple {
  final Response response;
  final File? file;

  PrepareShowfileDownloadTuple(this.response, this.file);
}
