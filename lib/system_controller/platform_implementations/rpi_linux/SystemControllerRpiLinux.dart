import 'dart:io';

import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_core/models/system_controller/DeviceOrientation.dart';
import 'package:castboard_core/models/system_controller/DeviceResolution.dart';
import 'package:castboard_performer/system_controller/SystemConfigCommitResult.dart';
import 'package:castboard_performer/system_controller/platform_implementations/rpi_linux/models/ApplicationConfigModel.dart';
import 'package:castboard_performer/system_controller/SystemController.dart';
import 'package:castboard_performer/system_controller/platform_implementations/rpi_linux/RpiHdmiModes.dart';
import 'package:castboard_performer/system_controller/platform_implementations/rpi_linux/models/RpiBootConfigModel.dart';
import 'package:castboard_performer/system_controller/platform_implementations/rpi_linux/readApplicationConfigFile.dart';
import 'package:castboard_performer/system_controller/platform_implementations/rpi_linux/writeApplicationConfigFile.dart';
import 'package:castboard_performer/versionCodename.dart';
import 'package:dbus/dbus.dart';
import 'package:castboard_performer/system_controller/DBusLocations.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Platform Interface implementation of SystemController specific to the Rpi4 with our custom Yocto image and the poky-centerstage distro.
/// For System Commands we utilize dbus to talk to systemd.
/// For System Configuration we mount the boot partition during intialization and modify the rpi specific config.txt file, unmounting in the dispose() function.
/// For Software startup we write to a Startup Configuration file. This will be in the "Applications Support Directory" (according to path_provider), then inside the castboard
/// directory and finally in the startup.conf file.

// Systemd unit name. We currently use the Cage Wayland Compositor.
const String _unitName = 'cage@tty7.service';

// Paths
const String _rpiConfigMntDir = '/media/boot/';
const String rpiConfigPath = '$_rpiConfigMntDir/config.txt';

// Commands
const String _mountCommand = 'mount';
const String _unMountCommand = 'umount';

// Command Args
const List<String> _mountArgs = [_rpiConfigMntDir];

const Map<DeviceOrientation, int> _deviceOrientationMap = {
  DeviceOrientation.landscape: 0,
  DeviceOrientation.portraitLeft: 90,
  DeviceOrientation.portraitRight: 270,
};

class SystemControllerRpiLinux implements SystemController {
  final DBusClient _systemBus = DBusClient.system();
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    // Mount the Boot Config partition. fstab will ensure it is mounted with our permissions.
    try {
      final ProcessResult result = await Process.run(_mountCommand, _mountArgs);
      if (result.exitCode == 0 || result.exitCode == 32) {
        // Error code 32 is thrown when the drive is already mounted.

        // Success
        _initialized = true;
        return;
      }

      // Something has gone wrong. Log it and return.
      LoggingManager.instance.systemManager.severe(
          'SystemControllerRpiLinux initialization failed. Mount command returned exit code ${result.exitCode}');

      return;
    } catch (e) {
      LoggingManager.instance.systemManager.severe(
          'An error occured whilst mounting the boot config directory. \n $e');
    }

    return;
  }

  /// Triggers a hardware Power Off.
  @override
  Future<void> powerOff() async {
    // Send a Power Off signal via dbus. Security for this is handled by logind of which has been configured by cage for us.

    _assertInit();

    LoggingManager.instance.systemManager.info('System Power off called');

    final object = DBusLocations.logindManager.object(_systemBus);

    try {
      await object.callMethod(
        DBusLocations.logindManager.interface,
        'PowerOff',
        [const DBusBoolean(false)],
      );
    } catch (e) {
      _handleError(e, 'PowerOff');
    }
  }

  /// Triggers a hardware reboot.
  @override
  Future<void> reboot() async {
    // Send a Reboot signal via dbus. Security for this is handled by logind of which has been configured by cage for us.
    _assertInit();

    LoggingManager.instance.systemManager.info('System Reboot called');

    final object = DBusLocations.logindManager.object(_systemBus);

    try {
      await object.callMethod(
        DBusLocations.logindManager.interface,
        'Reboot',
        [const DBusBoolean(false)],
      );
    } catch (e) {
      _handleError(e, 'Reboot');
    }
  }

  @override
  Future<void> restart() async {
    // Send a Soft Restart signal via dbus. Security for this is handled by polkit, of which we have configured to allow us access to the 'manage-units' scope.
    _assertInit();

    LoggingManager.instance.systemManager
        .info('System Software Restart called');

    final object = DBusLocations.systemdManager.object(_systemBus);

    try {
      await object.callMethod(
        DBusLocations.systemdManager.interface,
        'RestartUnit',
        [
          const DBusString(_unitName), // Unit
          const DBusString(
              'replace'), // Restart Mode, one of 'replace', 'fail', 'isolate', 'ignore-dependencies' or 'ignore-requirements'.
        ],
      );
    } catch (e) {
      _handleError(e, 'PowerOff');
    }
  }

  DeviceOrientation _parseDeviceOrientation(int orientation) {
    switch (orientation) {
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

  Future<DeviceResolution> _getActualResolution() async {
    _assertInit();

    LoggingManager.instance.systemManager.info('Reading actual resolution');

    const String command = 'cat';
    final List<String> args = ['/sys/class/graphics/fb0/virtual_size'];

    final result = await Process.run(command, args);
    if (result.stdout is String) {
      final string = result.stdout as String;

      if (string.isEmpty ||
          string.contains(',') == false ||
          string.split(',').length < 2) {
        throw 'Unable to get current device resolution, result of \n $command $args \n could not be parsed \n'
            'Result is: $result';
      }

      final int width = int.parse(string.split(',')[0]);
      final int height = int.parse(string.split(',')[1]);

      return DeviceResolution(width, height);
    } else {
      throw 'Unable to get current device resolution, result of \n $command $args \n was not a String. '
          'Result is a ${result.runtimeType}, toString() as ${result.toString()}';
    }
  }

  @override
  Future<SystemConfigCommitResult> commitSystemConfig(
      SystemConfig currentConfig, SystemConfig configDelta) async {
    try {
      return await _commitSystemConfig(configDelta);
    } catch (e, stacktrace) {
      LoggingManager.instance.systemManager.severe(
          'An exception was thrown whilst commiting a System Configuration. configDelta: ${configDelta.toMap().toString()}',
          e,
          stacktrace);

      return SystemConfigCommitResult(
          success: false, restartRequired: false, resultingConfig: configDelta);
    }
  }

  Future<SystemConfigCommitResult> _commitSystemConfig(
      SystemConfig configDelta) async {
    // configDelta represents only the properties that have been modifed by the user, untouched properties will be null.
    _assertInit();

    LoggingManager.instance.systemManager.info(
        'Commiting System Configuration Delta:  ${configDelta.toMap().toString()}');

    // Keep track of if we are going to need to restart.
    bool restartRequired = false;

    LoggingManager.instance.systemManager.info(
        'Updating application configuration.. Reading existing Application Configuration');
    final runningAppConfig = await readApplicationConfigFile();
    ApplicationConfigModel newAppConfig = runningAppConfig.copyWith();

    // playShowOnIdle
    if (configDelta.playShowOnIdle != null) {
      newAppConfig =
          newAppConfig.copyWith(playShowOnIdle: configDelta.playShowOnIdle!);
    }

    await writeApplicationConfigFile(newAppConfig);

    // Read back the final resulting Config to provide as a component of our result.
    final resultingConfig = await getSystemConfig();

    return SystemConfigCommitResult(
      success: true,
      restartRequired: restartRequired,
      resultingConfig: resultingConfig,
    );
  }

  @override
  Future<SystemConfig> getSystemConfig() async {
    _assertInit();

    LoggingManager.instance.systemManager.info('Reading system configuration');

    ApplicationConfigModel? appConfig;

    final requests = [
      readApplicationConfigFile().then((result) => appConfig = result),
    ];

    final packageInfo = await PackageInfo.fromPlatform();

    await Future.wait(requests);

    final defaults = SystemConfig.defaults();

    final config = SystemConfig(
        playShowOnIdle: appConfig?.playShowOnIdle ?? defaults.playShowOnIdle,
        playerBuildNumber:
            packageInfo.buildNumber, // TODO Update these to performer names.
        playerBuildSignature: packageInfo.buildSignature,
        playerVersion: packageInfo.version,
        versionCodename: kVersionCodename,
        serverPort: 0,
        deviceId: 'UNSET DEVICE ID',
        deviceName: '');

    LoggingManager.instance.systemManager.info(
        'System Configuration fetched. \n ${config.toMap().toString()} \n');

    return config;
  }

  int _getHdmiModeInteger(DeviceResolution resolution) {
    // Map the incoming mode to an Rpi hdmi_mode integer.
    return rpiHdmiModes.keys.firstWhere(
        (key) => rpiHdmiModes[key] == resolution,
        orElse: () => const RpiBootConfigModel.defaults().hdmiMode);
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
}
