import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/storage/Storage.dart';
import 'package:castboard_core/utils/getUid.dart';
import 'package:castboard_core/utils/get_human_friendly_id.dart';
import 'package:castboard_performer/server/Server.dart';
import 'package:castboard_performer/server/validate_server_port.dart';
import 'package:castboard_performer/system_controller/SystemConfigCommitResult.dart';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_performer/system_controller/SystemController.dart';
import 'package:castboard_performer/system_controller/platform_implementations/desktop/platform_settings_model.dart';
import 'package:castboard_performer/versionCodename.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Platform interface for Desktop operating systems. MacOS, Windows, Linux Desktop.
class SystemControllerDesktop implements SystemController {
  @override
  Future<void> initialize() async {
    // Nothing to initialize.
    return;
  }

  @override
  Future<SystemConfigCommitResult> commitSystemConfig(
      SystemConfig currentConfig, SystemConfig newConfig) async {
    final bool playShowOnIdle = newConfig.playShowOnIdle ??
        PlatformSettingsModel.initial().playShowOnIdle;

    final serverPort = validateServerPort(newConfig.serverPort)
        ? newConfig.serverPort
        : kDefaultServerPort;

    bool restartRequired = false;

    if (currentConfig.serverPort != serverPort ||
        currentConfig.deviceName != newConfig.deviceName) {
      restartRequired = true;
    }

    try {
      await _writePlatformSettingsToDisk(PlatformSettingsModel(
        playShowOnIdle: playShowOnIdle,
        serverPort: serverPort,
        deviceId: newConfig.deviceId,
        deviceName: newConfig.deviceName,
      ));
    } catch (e) {
      return SystemConfigCommitResult(
          success: false,
          restartRequired: false,
          resultingConfig: newConfig.copyWith());
    }

    return SystemConfigCommitResult(
        success: true,
        restartRequired: restartRequired,
        resultingConfig: newConfig.copyWith(playShowOnIdle: playShowOnIdle));
  }

  Future<void> _writePlatformSettingsToDisk(
      PlatformSettingsModel settings) async {
    await Storage.instance
        .getPerformerSettingsFile()
        .writeAsString(settings.toJson());
  }

  @override
  Future<SystemConfig> getSystemConfig() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final settingsFile = Storage.instance.getPerformerSettingsFile();

    // Construct initial system settings to return in case the file does not exist yet or we
    // have an error reading it.
    final initialSystemConfig = SystemConfig(
        playShowOnIdle: PlatformSettingsModel.initial().playShowOnIdle,
        playerBuildNumber: packageInfo.buildNumber,
        playerBuildSignature: packageInfo.buildSignature,
        playerVersion: packageInfo.version,
        versionCodename: kVersionCodename,
        serverPort: kDefaultServerPort,
        deviceId: getUid(),
        deviceName: 'Performer-${getHumanFriendlyId()}');

    if (await settingsFile.exists() == false) {
      LoggingManager.instance.player.info(
          'No system config file found. Using Initial settings and writing those to disk');

      // try {
      //   await _writePlatformSettingsToDisk(
      //       PlatformSettingsModel.fromSystemConfig(initialSystemConfig));
      // } catch (e, stacktrace) {
      //   LoggingManager.instance.player.warning(
      //       'An error occurred persisting the initial system config to disk',
      //       e,
      //       stacktrace);
      // }

      return initialSystemConfig;
    }

    try {
      final platformSettings =
          PlatformSettingsModel.fromJson(await settingsFile.readAsString());
      return initialSystemConfig.copyWith(
          playShowOnIdle: platformSettings.playShowOnIdle,
          deviceName: platformSettings.deviceName,
          deviceId: platformSettings.deviceId,
          serverPort: validateServerPort(platformSettings.serverPort)
              ? platformSettings.serverPort
              : kDefaultServerPort);
    } catch (e, stacktrace) {
      LoggingManager.instance.player.warning(
          'An error has occurred reading the System config file.',
          e,
          stacktrace);

      return initialSystemConfig;
    }
  }

  @override
  Future<void> powerOff() async {
    // Noop
    return;
  }

  @override
  Future<void> reboot() async {
    // Noop
    return;
  }

  @override
  Future<void> resetUpdateStatus() async {
    // Noop
    return;
  }

  @override
  Future<void> restart() {
    throw UnimplementedError();
  }

  @override
  Future<bool> updateApplication(List<int> byteData) async {
    // Noop
    return true;
  }

  @override
  Future<void> dispose() async {
    // Noop
    return;
  }
}
