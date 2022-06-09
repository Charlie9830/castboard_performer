import 'dart:io';

import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:path/path.dart' as p;

const _timestampFilename = 'timestamp';

/// The Yocto build Recipe for castboard-showcaller will leave a timestamp file in the build output folder
/// that represents the date of the Showcaller commmit used. We will query for this file, if it exists,
/// We will update the other Web assets File Modified metadata to match this date. Once that is done we will delete the timestamp
/// file.
/// This ensures that [shelf.staticFileHandler] will serve the files with the correct cache headers. This worksaround the fact that
/// Yocto uses a 'fake' known timestamp during it's build process in order to keep compatiability with Reproducible Builds.
Future<void> prepareStaticWebDirectory(String path) async {
  final timestampPath = p.join(path, _timestampFilename);
  final timestampFile = File(timestampPath);
  if (await timestampFile.exists() == false) {
    // Timestamp file doesn't exist. We have likely already updated the metadata during an earlier bootup.
    LoggingManager.instance.server.info('No Showcaller timestamp file found.');
    return;
  }

  final timestampString = await timestampFile.readAsString();
  final timestamp = DateTime.tryParse(timestampString);

  if (timestamp == null) {
    LoggingManager.instance.server.warning(
        'Unable to parse Showcaller build timestamp from $timestampPath');
    return;
  }

  LoggingManager.instance.server.info(
      'Showcaller timestamp file found: $timestampString.  Updating web_app directory file metadata');

  final webAppDirectory = Directory(path);

  if (await webAppDirectory.exists() == false) {
    LoggingManager.instance.server
        .warning('Web App Directory does not exist at $path');
    return;
  }

  LoggingManager.instance.server.info(
      'Updating lastModified property of web_app files at $path to value: ${_humanReadableTimestamp(timestamp)}');
  await for (var entity in webAppDirectory.list(recursive: true)) {
    if (entity is File) {
      await entity.setLastModified(timestamp);
    }
  }

  LoggingManager.instance.server
      .info('web_app lastModified property updated. Deleting timestamp file');

  await timestampFile.delete();

  LoggingManager.instance.server
      .info('web_app directory preperation completed.');
  return;
}

String _humanReadableTimestamp(DateTime timestamp) {
  return '${timestamp.day}/${timestamp.month}/${timestamp.year} - ${timestamp.hour}:${timestamp.minute}';
}
