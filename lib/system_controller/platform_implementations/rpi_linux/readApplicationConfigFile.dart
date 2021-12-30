import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/models/ApplicationConfigModel.dart';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/getAppConfigFIle.dart';

Future<ApplicationConfigModel> readConfigFile() async {
  final systemConfigFile = await getAppConfigFile();
  final exists = await systemConfigFile.exists();

  if (exists == false) {
    return ApplicationConfigModel.defaults();
  }

  final contents = await systemConfigFile.readAsString();
  return ApplicationConfigModel.fromFile(contents);
}
