import 'dart:io';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/models/ApplicationConfigModel.dart';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/getAppConfigFIle.dart';

///
/// Writes the contents of [config] to the System config file, overwriting anything that exists there.
///
Future<void> writeApplicationConfigFile(ApplicationConfigModel config) async {
  final target = await getAppConfigFile();

  final configString = config.toConfigFileString();

  await target.writeAsString(configString, mode: FileMode.write);
}
