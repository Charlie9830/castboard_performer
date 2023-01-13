import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/storage/Storage.dart';
import 'package:castboard_performer/system_controller/SystemConfigCommitResult.dart';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_performer/system_controller/SystemController.dart';
import 'package:castboard_performer/system_controller/platform_implementations/desktop/system_settings_model.dart';
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
      SystemConfig config) async {
    final bool playShowOnIdle =
        config.playShowOnIdle ?? SystemSettingsModel.initial().playShowOnIdle;
    try {
      await Storage.instance.getPerformerSettingsFile().writeAsString(
          SystemSettingsModel(playShowOnIdle: playShowOnIdle).toJson());
    } catch (e) {
      return SystemConfigCommitResult(
          success: false,
          restartRequired: false,
          resultingConfig: config.copyWith());
    }

    return SystemConfigCommitResult(
        success: true,
        restartRequired: false,
        resultingConfig: config.copyWith(playShowOnIdle: playShowOnIdle));
  }

  @override
  Future<SystemConfig> getSystemConfig() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final settingsFile = Storage.instance.getPerformerSettingsFile();

    // Construct default system settings to return in case the file does not exist yet or we
    // have an error reading it.
    final defaultSystemSettings = SystemConfig(
      playShowOnIdle: SystemSettingsModel.initial().playShowOnIdle,
      playerBuildNumber: packageInfo.buildNumber,
      playerBuildSignature: packageInfo.buildSignature,
      playerVersion: packageInfo.version,
      versionCodename: kVersionCodename,
    );

    if (await settingsFile.exists() == false) {
      LoggingManager.instance.player
          .info('No system config file found. Using default settings');
      return defaultSystemSettings;
    }

    try {
      final platformSettings =
          SystemSettingsModel.fromJson(await settingsFile.readAsString());

      return defaultSystemSettings.copyWith(
          playShowOnIdle: platformSettings.playShowOnIdle);
    } catch (e, stacktrace) {
      LoggingManager.instance.player.warning(
          'An error has occurred reading the System config file.',
          e,
          stacktrace);

      return defaultSystemSettings;
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
