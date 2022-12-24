import 'dart:ui';

import 'package:castboard_performer/constants.dart';
import 'package:window_manager/window_manager.dart';

Future<void> setFullScreen(bool fullscreen) async {
  if (fullscreen == true) {
    // Entering Fullscreen.

    // Set window size to minimum size so that Fullscreen mode doesn't spill over onto another monitor.
    await windowManager.setSize(kMinimumWindowSize);
    await windowManager.setFullScreen(true);
    return;

  }


  await windowManager.setFullScreen(false);
  await windowManager.setSize(const Size(1280, 800)); // Set Size to comfortable but smallish Size.
}
