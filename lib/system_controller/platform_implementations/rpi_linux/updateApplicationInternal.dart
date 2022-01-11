import 'dart:io';

import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/path_provider_shims.dart';
import 'package:castboard_core/storage/Storage.dart';
import 'package:castboard_performer/system_controller/DBusLocations.dart';
import 'package:castboard_performer/system_controller/SystemController.dart';
import 'package:castboard_performer/system_controller/platform_implementations/rpi_linux/models/UpdaterArgsModel.dart';
import 'package:castboard_performer/versionCodename.dart';
import 'package:dbus/dbus.dart';
import 'package:path/path.dart' as p;

const String _appPath = '/usr/share/castboard-performer/';
const String _updaterConfPath = '/etc/castboard-updater/';
const String _updateStatusFilePath = '${_updaterConfPath}update_status';
const String _argsEnvFilePath = '${_updaterConfPath}args.env';
const String _appUnitName = 'cage@tty7.service';
const String _rollbackDirectoryName = 'rollback';
const String _castboardUpdaterServiceName = 'castboard-updater.service';

Future<bool> updateApplicationInternal(
    List<int> byteData, DBusClient systemBus) async {
  // Unzip the contents of byteData to a tempory directory.
  final tmpDir = await getTemporaryDirectoryShim();
  Directory updateSourceDir =
      Directory(p.join(tmpDir.path, 'castboard-performer-updates'));

  LoggingManager.instance.systemManager.info("Starting Software Update");
  LoggingManager.instance.systemManager
      .info("Saving incoming update file to ${updateSourceDir.path}");

  // If the updateSourceDir already exists. Delete it to clear out any old
  // updates.
  if (await updateSourceDir.exists())
    await updateSourceDir.delete(recursive: true);

  await updateSourceDir.create();

  LoggingManager.instance.systemManager.info("Decompressing update file");

  // Decompress the incoming update to the sourceDir.
  updateSourceDir =
      await Storage.instance.decompressGenericZip(byteData, updateSourceDir);

  LoggingManager.instance.systemManager.info("Decompression complete.");
  LoggingManager.instance.systemManager.info("Validating file");

  // Validate the update.
  if (await _validateIncomingUpdate(updateSourceDir)) {
    LoggingManager.instance.systemManager
        .info("Update file failed validation. Rejecting");
    return false;
  }

  LoggingManager.instance.systemManager.info("File passed validation checks");
  LoggingManager.instance.systemManager
      .info("Ensuring update_status file is reset");

  // Ensure the castboard-updater update-status file has been reset.
  final updateStatusFile = await _getUpdateStatusFile(createIfNeeded: true);
  await updateStatusFile.writeAsString('none');

  LoggingManager.instance.systemManager
      .info("update_status file reset complete");
  LoggingManager.instance.systemManager
      .info("Setting up the Updater Arguments");

  // Setup the args.env file for castboard-updater.
  final argsEnv = UpdaterArgsModel(
    appPath: _appPath,
    updateSourcePath: updateSourceDir.path,
    updaterConfPath: _updaterConfPath,
    appUnitName: _appUnitName,
    rollbackPath: (await _getRollbackDirectory(kVersionCodename)).path,
    outgoingCodename: kVersionCodename,
    incomingCodename: await _readCodenameFromFile(updateSourceDir),
  );

  LoggingManager.instance.systemManager
      .info("Writing the updater args env file");

  final argsEnvFile = await _getArgsEnvFile();
  await argsEnvFile.writeAsString(argsEnv.toEnvFileString());

  LoggingManager.instance.systemManager
      .info("Updater Args Env file write complete");
  LoggingManager.instance.systemManager
      .info("Obtaining systemd d-bus interface");

  // Obtain the systemd d-bus interface.
  final object = DBusLocations.systemdManager.object(systemBus);

  LoggingManager.instance.systemManager
      .info("Executing StartUnit on $_castboardUpdaterServiceName");

  // Call out to systemd to start the castboard-updater script.
  // The updater script will wait for a few seconds before shutting down castboard
  // giving us time to send notifications back to the remote.
  await object.callMethod(
    DBusLocations.systemdManager.interface,
    'StartUnit',
    [
      DBusString(_castboardUpdaterServiceName), // Unit
      DBusString(
          'replace'), // Restart Mode, one of 'replace', 'fail', 'isolate', 'ignore-dependencies' or 'ignore-requirements'.
    ],
  );

  LoggingManager.instance.systemManager
      .info("StartUnit Execution complete. Castboard shutdown imminent...");

  return true;
}

Future<UpdateStatus> getUpdateStatusInternal() async {
  final updateStatusFile = await _getUpdateStatusFile();

  if (await updateStatusFile.exists() == false) return UpdateStatus.none;

  final contents = (await updateStatusFile.readAsString()).trim();

  if (contents == 'none') return UpdateStatus.none;
  if (contents == 'failed') return UpdateStatus.failed;
  if (contents == 'success') return UpdateStatus.success;
  if (contents == 'started') return UpdateStatus.started;

  return UpdateStatus.none;
}

Future<String> _readCodenameFromFile(Directory sourceDir) async {
  final codenameFile = File(p.join(sourceDir.path, 'codename'));

  if (await codenameFile.exists() == false) {
    return 'Unknown';
  }

  return await codenameFile.readAsString();
}

Future<void> resetUpdateStatusInternal() async {
  final updateStatusFile = await _getUpdateStatusFile(createIfNeeded: true);
  await updateStatusFile.writeAsString('none');
}

Future<bool> _validateIncomingUpdate(Directory updateDir) async {
  // Validate the contents of the incoming software update against the known schema
  // of the sony layout.
  bool hasBundleDir = false;
  bool hasDataDir = false;
  bool hasExecutable = false;

  await for (var entity in updateDir.list()) {
    final name = p.basenameWithoutExtension(entity.path);

    if (entity is Directory) {
      if (name == 'bundle') hasBundleDir = true;
      if (name == 'data') hasDataDir = true;
    }

    if (entity is Directory) {
      // TODO: This could be wrong. Should'nt it be a file?
      if (name == 'performer') hasExecutable = true;
    }
  }

  return hasBundleDir && hasDataDir && hasExecutable;
}

Future<File> _getUpdateStatusFile({bool createIfNeeded = false}) async {
  final file = File(_updateStatusFilePath);

  if (await file.exists() == false && createIfNeeded == true) {
    await file.writeAsString('none');
  }

  return file;
}

Future<File> _getArgsEnvFile() async {
  final file = await File(_argsEnvFilePath);

  if (await file.exists() == false) await file.create();

  return file;
}

Future<Directory> _getRollbackDirectory(String versionCodename) async {
  final baseDir = await getApplicationsDocumentDirectoryShim();
  final dir = await Directory(
      p.join(baseDir.path, _rollbackDirectoryName, versionCodename));

  if (await dir.exists() == false) await dir.create(recursive: true);

  return dir;
}
