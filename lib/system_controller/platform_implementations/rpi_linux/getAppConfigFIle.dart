import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as pathProvider;
import 'dart:io';

Future<File> getAppConfigFile() async {
  final supportDir = await pathProvider.getApplicationDocumentsDirectory();
  final appConfigFile = File(p.join(supportDir.path, 'castboard.conf'));

  return appConfigFile;
}
