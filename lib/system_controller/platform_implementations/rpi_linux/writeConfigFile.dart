import 'dart:io';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/models/RpiConfigModel.dart';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/getConfigFIle.dart';

///
/// Writes the contents of [config] to the System config file, overwriting anything that exists there.
///
Future<void> writeConfigFile(RpiConfigModel config) async {
  final target = await getConfigFile();

  final configString = config.toConfigFileString();

  await target.writeAsString(configString, mode: FileMode.write);
}
