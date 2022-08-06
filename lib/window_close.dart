import 'dart:io';

import 'package:castboard_core/utils/compressImage.dart';
import 'package:castboard_performer/server/Server.dart';
import 'package:castboard_performer/service_advertiser/serviceAdvertiser.dart';
import 'package:castboard_performer/system_controller/SystemController.dart';
import 'package:flutter_window_close/flutter_window_close.dart';

void registerWindowCloseHook({
  required Server server,
  required SystemController systemController,
  required ImageCompressor? previewStreamCompressor,
}) {
  if (Platform.isLinux &&
      const bool.hasEnvironment('ELINUX_IS_DESKTOP') == false) {
    // Running on RPI. Probably best not to try and use this plugin.
    return;
  }

  FlutterWindowClose.setWindowShouldCloseHandler(() async {
    await ServiceAdvertiser.instance.stop();
    await server.shutdown();
    await systemController.dispose();
    previewStreamCompressor?.spinDown();
    return true;
  });
}
