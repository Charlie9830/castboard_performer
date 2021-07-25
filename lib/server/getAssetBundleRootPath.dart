import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

String getAssetBundleRootPath() {
  if (kDebugMode) {
    return _getDebugAssetBundleRootPath();
  }

  if (Platform.isWindows) {
    return p.join(p.current, 'data', 'flutter_assets', 'assets');
  } 

  if (Platform.isLinux) {
    // Flutter-Pi Layout
    return p.join(p.current, 'assets');
  }

  else {
    throw "Platform not currently supported by getAssetBundleRootPath(). Add conditional handling for this platform";
  }
}

String _getDebugAssetBundleRootPath() {
  return p.join(p.current, 'static_debug');
}
