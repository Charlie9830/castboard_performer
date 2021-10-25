import 'dart:io';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/models/StartupConfigModel.dart';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/getStartupConfigFile.dart';

///
/// Writes the contents of [config] to the System config file, overwriting anything that exists there.
///
Future<void> writeStartupConfig(StartupConfigModel config) async {
  final target = await getStartupConfigFile();

  final configString = config.toConfigFileString();

  await target.writeAsString(configString, mode: FileMode.write);
}
