import 'package:castboard_performer/system_controller/platform_implementations/rpi_linux/getRpiBootConfigFile.dart';
import 'package:castboard_performer/system_controller/platform_implementations/rpi_linux/models/RpiBootConfigModel.dart';

Future<RpiBootConfigModel> readRpiBootConfigFile() async {
  final configFile = getRpiBootConfigFile();
  if (await configFile.exists() == false) {
    return const RpiBootConfigModel.defaults();
  }

  final contents = await configFile.readAsString();
  return RpiBootConfigModel.fromFileString(contents);
}
