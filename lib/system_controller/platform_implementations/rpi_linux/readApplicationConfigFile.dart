import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/models/ApplicationConfigModel.dart';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/getAppConfigFIle.dart';

Future<ApplicationConfigModel> readApplicationConfigFile() async {
  final appConfigFile = await getAppConfigFile();
  final exists = await appConfigFile.exists();

  if (exists == false) {
    return ApplicationConfigModel.defaults();
  }

  final contents = await appConfigFile.readAsString();
  return ApplicationConfigModel.fromFile(contents);
}
