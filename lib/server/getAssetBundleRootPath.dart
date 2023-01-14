import 'dart:io';

import 'package:castboard_performer/castboard_platform.dart';
import 'package:castboard_performer/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

String getAssetBundleRootPath() {
  if (kDebugMode) {
    return _getDebugAssetBundleRootPath();
  }

  if (Platform.isWindows) {
    final executableParentDirectory =
        Directory(Platform.resolvedExecutable).parent;
    return p.join(
        executableParentDirectory.path, 'data', 'flutter_assets', 'assets');
  }

  if (Platform.isMacOS) {
    final macOSPackageRoot = Directory(Platform.resolvedExecutable)
        .parent
        .parent; // Gives us a reference to castboard_performer.app/Contents/
    return p.join(macOSPackageRoot.path, 'Frameworks', 'App.framework',
        'Resources', 'flutter_assets', 'assets');
  }

  if (CastboardPlatform.isElinux) {
    // Sony Layout
    return p.join(kYoctoAssetBundlePath, 'assets');
  } else {
    throw "Platform not currently supported by getAssetBundleRootPath(). Add conditional handling for this platform";
  }
}

String _getDebugAssetBundleRootPath() {
  if (Platform.isMacOS) {
    print(Platform.resolvedExecutable);
    // Platform.resolvedExecutable will be the executable inside the built package. In other words it's path from the project root will be very deep.
    final projectDir = Directory(Platform.resolvedExecutable)
        .parent // MacOS
        .parent // Contents
        .parent // Castboard Performer.app
        .parent // Debug
        .parent // Products
        .parent // Build
        .parent // macos
        .parent // build
        .parent; // castboard_performer
    return p.join(projectDir.path, 'static_debug');
  }

  return p.join(p.current, 'static_debug');
}
