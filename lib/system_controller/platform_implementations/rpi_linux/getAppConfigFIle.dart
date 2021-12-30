import 'package:path/path.dart' as p;
import 'dart:io';

Future<File> getAppConfigFile() async {
  final appConfigFile = File(p.join('etc', 'castboard', 'castboard.conf'));

  return appConfigFile;
}
