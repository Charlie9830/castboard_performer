import 'dart:io';

import 'package:castboard_performer/system_controller/platform_implementations/rpi_linux/SystemControllerRpiLinux.dart';

File getRpiBootConfigFile() {
  return File(rpiConfigPath);
}
