import 'dart:io';

import 'package:castboard_performer/castboard_platform.dart';
import 'package:castboard_performer/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

String getAssetBundleRootPath() {
  if (kDebugMode) {
    return _getDebugAssetBundleRootPath();
  }

  if (Platform.isWindows || Platform.isMacOS) {
    final executableParentDirectory =
        Directory(Platform.resolvedExecutable).parent;
    return p.join(
        executableParentDirectory.path, 'data', 'flutter_assets', 'assets');
  }

  if (CastboardPlatform.isElinux) {
    // Sony Layout
    return p.join(kYoctoAssetBundlePath, 'assets');
  } else {
    throw "Platform not currently supported by getAssetBundleRootPath(). Add conditional handling for this platform";
  }
}

String _getDebugAssetBundleRootPath() {
  return p.join(p.current, 'static_debug');
}
