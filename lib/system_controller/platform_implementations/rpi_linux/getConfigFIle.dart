import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/RpiHdmiModes.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as pathProvider;
import 'dart:io';

Future<File> getConfigFile() async {
  final supportDir = await pathProvider.getApplicationSupportDirectory();
  final startupConfigFile =
      File(p.join(supportDir.path, 'castboard/', 'startup.conf'));

  return startupConfigFile;
}
