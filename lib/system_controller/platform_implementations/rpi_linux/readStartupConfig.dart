import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/models/StartupConfigModel.dart';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/getStartupConfigFile.dart';

Future<StartupConfigModel> readStartupConfig() async {
  final systemConfigFile = await getStartupConfigFile();
  final exists = await systemConfigFile.exists();

  if (exists == false) {
    return StartupConfigModel.defaults();
  }

  final contents = await systemConfigFile.readAsString();
  return StartupConfigModel.fromFile(contents);
}
