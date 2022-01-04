import 'dart:io';

import 'package:castboard_core/path_provider_shims.dart';
import 'package:castboard_core/storage/Storage.dart';
import 'package:castboard_player/system_controller/DBusLocations.dart';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/models/UpdaterArgsModel.dart';
import 'package:castboard_player/versionCodename.dart';
import 'package:dbus/dbus.dart';
import 'package:path/path.dart' as p;

const String _appPath = '/usr/share/castboard-player/';
const String _updaterConfPath = '/etc/castboard-updater/';
const String _updateStatusFilePath = '${_updaterConfPath}update_status';
const String _argsEnvFilePath = '${_updaterConfPath}args.env';
const String _appUnitName = 'cage@tty7.service';
const String _rollbackDirectoryName = 'rollback';
const String _castboardUpdaterServiceName = 'castboard-updater.service';

Future<void> updateApplicationInternal(
    List<int> byteData, DBusClient _systemBus) async {
  // Unzip the contents of byteData to a tempory directory.
  final tmpDir = await getTemporaryDirectoryShim();
  Directory updateSourceDir =
      Directory(p.join(tmpDir.path, 'castboard-player-updates'));

  await updateSourceDir.delete();
  await updateSourceDir.create();

  updateSourceDir =
      await Storage.instance.decompressGenericZip(byteData, updateSourceDir);

  // Ensure the castboard-updater update-status file has been reset.
  final updateStatusFile = await _getUpdateStatusFile();
  await updateStatusFile.writeAsString('none');

  // Setup the args.env file for castboard-updater.
  final argsEnv = UpdaterArgsModel(
    appPath: _appPath,
    updateSourcePath: _updateStatusFilePath,
    updaterConfPath: _updaterConfPath,
    appUnitName: _appUnitName,
    rollbackPath: (await _getRollbackDirectory()).path,
    outgoingCodename: kVersionCodename,
    incomingCodename: 'Unknown',
  );
  final argsEnvFile = await _getArgsEnvFile();
  await argsEnvFile.writeAsString(argsEnv.toEnvFileString());

  // Call out to systemd to start the castboard-updater script.
  final object = DBusLocations.systemdManager.object(_systemBus);
  await object.callMethod(
    DBusLocations.systemdManager.interface,
    'StartUnit',
    [
      DBusString(_castboardUpdaterServiceName), // Unit
      DBusString(
          'replace'), // Restart Mode, one of 'replace', 'fail', 'isolate', 'ignore-dependencies' or 'ignore-requirements'.
    ],
  );
}

Future<File> _getUpdateStatusFile() async {
  final file = File(_updateStatusFilePath);

  if (await file.exists() == false) {
    await file.writeAsString('none');
  }

  return file;
}

Future<File> _getArgsEnvFile() async {
  final file = await File(_argsEnvFilePath);

  if (await file.exists() == false) await file.create();

  return file;
}

Future<Directory> _getRollbackDirectory() async {
  final baseDir = await getApplicationsDocumentDirectoryShim();
  final dir = await Directory(p.join(baseDir.path, _rollbackDirectoryName));

  if (await dir.exists() == false) await dir.create();

  return dir;
}
