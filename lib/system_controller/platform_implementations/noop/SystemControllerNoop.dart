import 'dart:io';
import 'package:castboard_core/models/system_controller/AvailableResolutions.dart';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_core/models/system_controller/DeviceOrientation.dart';
import 'package:castboard_core/models/system_controller/DeviceResolution.dart';
import 'package:castboard_player/system_controller/SystemController.dart';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/RpiHdmiModes.dart';

class SystemControllerNoop implements SystemController {
  @override
  Future<void> initialize() async {
    print(_format('Instance Initialized'));
    return;
  }

  @override
  Future<void> powerOff() async {
    print(_format('PowerOff called.'));
  }

  @override
  Future<void> reboot() async {
    print(_format('Reboot called.'));
  }

  @override
  Future<void> restart() async {
    print(_format('Restart called.'));
  }

  String _format(String message) {
    return '[SystemControllerNoop] - $message';
  }

  @override
  Future<bool> commitSystemConfig(SystemConfig config) async {
    print(' === Device Config Parameters === \n');
    config.toMap().forEach((key, value) => print('$key=$value \n'));
    print(' === END OF FILE ===');
    return true;
  }

  @override
  Future<void> dispose() async {
    print(_format('Instance disposed'));
    return;
  }

  @override
  Future<SystemConfig> getSystemConfig() async {
    return SystemConfig.defaults().copyWith(
        availableResolutions: AvailableResolutions([
      DeviceResolution.auto(),
      DeviceResolution(640, 480),
      DeviceResolution(1280, 720),
      DeviceResolution(1920, 1080),
    ]));
  }
}
