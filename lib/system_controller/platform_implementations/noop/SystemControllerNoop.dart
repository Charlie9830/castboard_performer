import 'dart:io';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_core/models/system_controller/DeviceOrientation.dart';
import 'package:castboard_core/models/system_controller/DeviceResolution.dart';
import 'package:castboard_player/system_controller/SystemController.dart';

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
  Future<DeviceOrientation> getCurrentOrientation() async {
    return DeviceOrientation.landscape;
  }

  @override
  Future<DeviceResolution> getCurrentResolution() async {
    return DeviceResolution(1920, 1080);
  }

  @override
  Future<bool> getIsAutoResolution() async {
    return true;
  }

  @override
  Future<DeviceResolution> getDesiredResolution() async {
    return DeviceResolution(1920, 1080);
  }

  @override
  Future<bool> commitSystemConfig(SystemConfig config) async {
    print(' === Device Config Parameters === \n');
    config.toMap().forEach((key, value) => print('$key=$value \n'));
    print(' === END OF FILE ===');
    return false;
  }

  @override
  Future<List<DeviceResolution>> getAvailableResolutions() async {
    return [
      DeviceResolution(1920, 1080),
      DeviceResolution.auto(),
    ];
  }

  @override
  Future<void> dispose() async {
    print(_format('Instance disposed'));
    return;
  }

  @override
  Future<SystemConfig> getSystemConfig() async {
    return SystemConfig.defaults();
  }
}
