import 'dart:io';

import 'package:castboard_performer/system_controller/platform_implementations/rpi_linux/SystemControllerRpiLinux.dart';
import 'package:castboard_performer/system_controller/platform_implementations/rpi_linux/models/RpiBootConfigModel.dart';

File getRpiBootConfigFile() {
  return File(rpiConfigPath);
}
