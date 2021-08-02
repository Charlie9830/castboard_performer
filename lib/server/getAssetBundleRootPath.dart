import 'dart:io';

import 'package:castboard_player/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

String getAssetBundleRootPath() {
  // TODO: Temporary override of kDebugMode behaviour until bug is fixed.
  // Once this is fixed. Make sure to also update _pauseForEffect() in castboard_player:main.dart
  if (Platform.isLinux) {
    // Flutter-Pi Layout
    return p.join(kYoctoAssetBundlePath, 'assets');
  }

  if (kDebugMode) {
    return _getDebugAssetBundleRootPath();
  }

  if (Platform.isWindows) {
    return p.join(p.current, 'data', 'flutter_assets', 'assets');
  }

  // TODO: Re-enable when kDebugMode bug is fixed.
  // if (Platform.isLinux) {
  //   // Flutter-Pi Layout
  //   return p.join(kYoctoAssetBundlePath, 'assets');
  // }

  else {
    throw "Platform not currently supported by getAssetBundleRootPath(). Add conditional handling for this platform";
  }
}

String _getDebugAssetBundleRootPath() {
  return p.join(p.current, 'static_debug');
}
