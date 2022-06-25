import 'package:castboard_core/models/system_controller/AvailableResolutions.dart';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_core/models/system_controller/DeviceResolution.dart';
import 'package:castboard_performer/system_controller/SystemConfigCommitResult.dart';
import 'package:castboard_performer/system_controller/SystemController.dart';

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
  Future<SystemConfigCommitResult> commitSystemConfig(
      SystemConfig config) async {
    print(' === Device Config Parameters === \n');
    config.toMap().forEach((key, value) => print('$key=$value \n'));
    print(' === END OF FILE ===');
    return SystemConfigCommitResult(
        success: true, restartRequired: true, resultingConfig: config);
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
      const DeviceResolution.auto(),
      const DeviceResolution(640, 480),
      const DeviceResolution(1280, 720),
      const DeviceResolution(1920, 1080),
    ]));
  }

  @override
  Future<bool> updateApplication(List<int> byteData) async {
    print("Update Application called");
    return true;
  }

  @override
  Future<UpdateStatus> getUpdateStatus() async {
    return UpdateStatus.none;
  }

  @override
  Future<void> resetUpdateStatus() async {
    print('resetUpdateStatus called');
    return;
  }
}
