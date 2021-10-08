import 'dart:io';

import 'package:castboard_player/system_controller/platform_implementations/SystemControllerLinux.dart';
import 'package:castboard_player/system_controller/platform_implementations/SystemControllerNoop.dart';

abstract class SystemController {
  factory SystemController() {
    /// DBus is only available on Linux. So if we aren't on linux we want to return a NOOP instance.
    if (Platform.isLinux) {
      return SystemControllerLinux();
    } else {
      return SystemControllerNoop();
    }
  }

  /// Triggers a hardware Power Off.
  Future<void> powerOff();

  /// Triggers a hardware reboot.
  Future<void> reboot();

  /// Triggers an application restart.
  Future<void> restart();

  Future<void> dispose();
}
