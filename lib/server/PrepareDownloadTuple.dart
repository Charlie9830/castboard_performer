import 'dart:io';

import 'package:shelf_plus/shelf_plus.dart';

class PrepareDownloadTuple {
  final Response response;
  final File? file;

  PrepareDownloadTuple(this.response, this.file);
}
