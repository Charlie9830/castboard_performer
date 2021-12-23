import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/models/RpiConfigModel.dart';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/getConfigFIle.dart';

Future<RpiConfigModel> readConfigFile() async {
  final systemConfigFile = await getConfigFile();
  final exists = await systemConfigFile.exists();

  if (exists == false) {
    return RpiConfigModel.defaults();
  }

  final contents = await systemConfigFile.readAsString();
  return RpiConfigModel.fromFile(contents);
}
