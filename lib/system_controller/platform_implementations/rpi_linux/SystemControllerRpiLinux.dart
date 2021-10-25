import 'dart:io';

import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/models/system_controller/DeviceConfig.dart';
import 'package:castboard_core/models/system_controller/DeviceOrientation.dart';
import 'package:castboard_core/models/system_controller/DeviceResolution.dart';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/models/StartupConfigModel.dart';
import 'package:castboard_player/system_controller/SystemController.dart';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/RpiHdmiModes.dart';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/readStartupConfig.dart';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/writeStartupConfig.dart';
import 'package:dbus/dbus.dart';
import 'package:castboard_player/system_controller/DBusLocations.dart';

/// Platform Interface implementation of SystemController specific to the Rpi4 with our custom Yocto image and the poky-centerstage distro.
/// For System Commands we utilize dbus to talk to systemd.
/// For System Configuration we mount the boot partition during intialization and modify the rpi specific config.txt file, unmounting in the dispose() function.
/// For Software startup we write to a Startup Configuration file. This will be in the "Applications Support Directory" (according to path_provider), then inside the castboard
/// directory and finally in the startup.conf file.

// Systemd unit name. We currently use the Cage Wayland Compositor.
const String _unitName = 'cage@tty7';

// Paths
const String _rpiConfigMntDir = '/media/boot/';
const String _rpiConfigPath = '$_rpiConfigMntDir/config.txt';

// Commands
const String _mountCommand = 'mount';
const String _unMountCommand = 'umount';
const String _grepCommand = 'grep';
const String _sedCommand = 'sed';

// Command Args
const List<String> _mountArgs = [_rpiConfigMntDir];
const String _hdmiModePattern = 'hdmi_mode=[0-107].';
const String _hdmiGroupPattern = 'hdmi_group=[0-2]';

const Map<DeviceOrientation, int> _deviceOrientationMap = {
  DeviceOrientation.landscape: 0,
  DeviceOrientation.portraitLeft: 90,
  DeviceOrientation.portraitRight: 270,
};

class SystemControllerRpiLinux implements SystemController {
  DBusClient _systemBus = DBusClient.system();
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    // Mount the Boot Config partition. fstab will ensure it is mounted with our permissions.
    final result = await Process.run(_mountCommand, _mountArgs);

    if (result.exitCode != 0) {
      throw 'SystemControllerRpiLinux initialization failed. Mount command returned exit code ${result.exitCode}';
    }

    _initialized = true;

    return;
  }

  /// Triggers a hardware Power Off.
  Future<void> powerOff() async {
    // Send a Power Off signal via dbus. Security for this is handled by logind of which has been configured by cage for us.

    _assertInit();
    final object = DBusLocations.logindManager.object(_systemBus);

    try {
      await object.callMethod(
        DBusLocations.logindManager.interface,
        'PowerOff',
        [DBusBoolean(false)],
      );
    } catch (e) {
      _handleError(e, 'PowerOff');
    }
  }

  /// Triggers a hardware reboot.
  Future<void> reboot() async {
    // Send a Reboot signal via dbus. Security for this is handled by logind of which has been configured by cage for us.
    _assertInit();
    final object = DBusLocations.logindManager.object(_systemBus);

    try {
      await object.callMethod(
        DBusLocations.logindManager.interface,
        'Reboot',
        [DBusBoolean(false)],
      );
    } catch (e) {
      _handleError(e, 'PowerOff');
    }
  }

  Future<void> restart() async {
    // Send a Soft Restart signal via dbus. Security for this is handled by polkit, of which we have configured to allow us access to the 'manage-units' scope.
    _assertInit();
    final object = DBusLocations.systemdManager.object(_systemBus);

    try {
      await object.callMethod(
        DBusLocations.systemdManager.interface,
        'RestartUnit',
        [
          DBusString(_unitName), // Unit
          DBusString(
              'replace'), // Restart Mode, one of 'replace', 'fail', 'isolate', 'ignore-dependencies' or 'ignore-requirements'.
        ],
      );
    } catch (e) {
      _handleError(e, 'PowerOff');
    }
  }

  @override
  Future<DeviceOrientation> getCurrentOrientation() async {
    _assertInit();

    final currentConfig = await readStartupConfig();

    switch (currentConfig.deviceRotation) {
      case 0:
        return DeviceOrientation.landscape;
      case 90:
        return DeviceOrientation.portraitRight;
      case 270:
        return DeviceOrientation.portraitLeft;
      default:
        return DeviceOrientation.landscape;
    }
  }

  @override
  Future<DeviceResolution> getCurrentResolution() async {
    _assertInit();
    final String command = 'cat';
    final List<String> args = ['/sys/class/graphics/fb0/virtual_size'];

    final result = await Process.run(command, args);
    if (result.stdout is String) {
      final string = result.stdout as String;

      if (string.isEmpty ||
          string.contains(',') == false ||
          string.split(',').length < 2) {
        throw 'Unable to get current device resolution, result of \n $command $args \n could not be parsed.';
      }

      final int width = int.parse(string.split(',')[0]);
      final int height = int.parse(string.split(',')[1]);

      return DeviceResolution(width, height);
    } else {
      throw 'Unable to get current device resolution, result of \n $command $args \n was not a String';
    }
  }

  @override
  Future<DeviceResolution> getDesiredResolution() async {
    _assertInit();

    // The state for auto resolution is stored in a different property within the config file. So check that property first, if it's set to auto,
    // short circut out and return a DeviceResolution representing auto mode.
    if (await getIsAutoResolution()) {
      return DeviceResolution.auto();
    }

    final grep = await Process.run(_grepCommand, [_hdmiModePattern]);

    if (grep.exitCode != 0) {
      throw 'Unable to get desired resolution, Grep failed to find entry in config.txt';
    }

    if (grep.stdout is String) {
      final List<String> results = (grep.stdout as String)
          .split('/n')
          .where((value) => value.contains('#') == false)
          .toList();

      if (results.isEmpty) {
        throw 'Unable to get desired resolution, Error parsing results from Grep';
      }

      final mode = results.first.replaceFirst('hdmi_mode=', '');
      final int? modeInt = int.tryParse(mode);

      if (modeInt == null || modeInt == 0 || modeInt > 107) {
        throw 'Unable to get desired resolution, Error parsing results from Grep. Failed to extract mode integer.';
      }

      if (rpiHdmiModes.containsKey(modeInt) == false) {
        throw 'Unrecognized HDMI mode int. Mode integer was not found in RpiHdmiModes map';
      }

      return rpiHdmiModes[modeInt]!;
    }

    throw 'Unable to get desired resolution, stdout result from grep was not a String';
  }

  @override
  Future<bool> getIsAutoResolution() async {
    _assertInit();

    final grep =
        await Process.run(_grepCommand, [_hdmiGroupPattern, _rpiConfigPath]);

    if (grep.exitCode != 0) {
      throw 'Unable to get Auto Resolution mode. Grep failed to find entry in config.txt';
    }

    if (grep.stdout is String) {
      final resultString = grep.stdout as String;
      if (resultString.contains('=0')) {
        return true;
      }
    }

    return false;
  }

  @override
  Future<bool> commitDeviceConfig(DeviceConfig config) async {
    _assertInit();

    bool restartRequired = false;
    // Apply Changes (if any) to Startup Configuration.
    if (_containsStartupConfigUpdates(config)) {
      await writeStartupConfig(StartupConfigModel(
          deviceRotation: _deviceOrientationMap[config.deviceOrientation!]!));

      restartRequired = true;
    }

    // Apply Device Resolution Changes (if any)
    if (config.deviceResolution != null) {
      await _updateDeviceResolution(config.deviceResolution!);

      restartRequired = true;
    }

    return restartRequired;
  }

  @override
  Future<List<DeviceResolution>> getAvailableResolutions() async {
    return [...rpiHdmiModes.values, DeviceResolution.auto()];
  }

  Future<void> _updateDeviceResolution(
      DeviceResolution incomingResolution) async {
    final currentDesiredRes = await getDesiredResolution();

    if (currentDesiredRes == incomingResolution) {
      // No update needed.
      return;
    }

    final int incomingMode = rpiHdmiModes.keys.firstWhere(
        (key) => rpiHdmiModes[key] == incomingResolution,
        orElse: () => -1);

    if (incomingMode == -1) {
      throw 'Invalid Rpi device resolution integer';
    }

    final replacementString = 'hdmi_mode=$incomingMode';

    // Run sed to modify the Rpi boot config. We don't check for the exit code as Sed will emit a non-zero exit code if nothing was changed,
    // this may not neccisarily indicate an error.
    await Process.run(
        _sedCommand, ['s/$_hdmiModePattern/$replacementString/g']);

    return;
  }

  bool _assertInit() {
    if (_initialized == false) {
      throw 'SystemControllerRpiLinux initialize() has not been called, call it before calling other methods';
    }

    return true;
  }

  void _handleError(Object e, String call) {
    LoggingManager.instance.systemManager.warning(
        'An exception was thrown whilst calling $call - ${e.toString()}');
  }

  @override
  Future<void> dispose() async {
    final futures = [
      _systemBus.close(),
      Process.run(_unMountCommand, _mountArgs)
    ];

    await Future.wait(futures);
    return;
  }

  /// Determines if the provided DeviceConfig contains updates to the Startup Configuration.
  bool _containsStartupConfigUpdates(DeviceConfig config) {
    return config.deviceOrientation != null;
  }
}
