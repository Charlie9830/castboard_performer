import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:castboard_core/enum-converters/EnumConversionError.dart';
import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/models/RemoteShowData.dart';
import 'package:castboard_core/models/system_controller/AvailableResolutions.dart';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_core/storage/Storage.dart';
import 'package:castboard_core/system-commands/SystemCommands.dart';
import 'package:castboard_player/server/PrepareDownloadTuple.dart';
import 'package:castboard_player/server/Server.dart';
import 'package:castboard_player/server/generateFileHeaders.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_plus/shelf_plus.dart';
import 'package:path/path.dart' as p;

Future<Response> handleHeartbeat(
    Request request, void Function(String sessionId) onHeartbeat) async {
  final sessionId = await request.readAsString();

  onHeartbeat(sessionId);

  return Response.ok(null);
}

Future<Response> handleShowDataPull(
    Request request, dynamic onShowDataPull) async {
  if (onShowDataPull == null) {
    return Response.internalServerError(
        body: 'onShowDataPull callback is null.');
  }

  final showData = onShowDataPull?.call();

  if (showData == null) {
    return Response.internalServerError(
        body: 'No data was returned by the onShowDataPull callback');
  }

  final jsonData = json.encoder.convert(showData.toMap());
  final response =
      Response.ok(jsonData, headers: {'Content-Type': 'application/json'});

  return response;
}

Future<Response> handleShowDataPost(
    Request request, OnShowDataReceivedCallback? onShowDataReceived) async {
  if (request.mimeType != 'application/json') {
    return Response.notModified();
  }

  if (onShowDataReceived == null) {
    return Response.internalServerError(body: 'onShowDataReceived is null');
  }

  if (Storage.instance.isWriting || Storage.instance.isReading) {
    if (Storage.instance.isWriting) {
      LoggingManager.instance.server.warning(
          "A show data POST request was denied because the Storage class is busy writing");
    }

    if (Storage.instance.isReading) {
      LoggingManager.instance.server.warning(
          "A a show data POST request was denied because the Storage class is busy reading");
    }

    return Response.internalServerError(
        body: 'Storage is busy. Please try again');
  }

  final rawJson = await request.readAsString();
  try {
    final rawData = json.decoder.convert(rawJson);
    final result = await onShowDataReceived(RemoteShowData.fromMap(rawData));
    if (result == true) {
      return Response.ok('');
    } else {
      return Response.internalServerError();
    }
  } catch (error) {
    return Response.internalServerError(body: error.toString());
  }
}

Future<PrepareDownloadTuple> handlePrepareLogsDownloadReq(
    Request request, OnPrepareLogsDownloadCallback? callback) async {
  if (callback == null) {
    LoggingManager.instance.server.warning(
        "A download request was denied because the OnPrepareLogsDownloadCallback is null");
    return PrepareDownloadTuple(
        Response.internalServerError(
            body: "The OnPrepareLogsDownloadCallback is null"),
        null);
  }

  final file = await callback();

  if (await file.exists() == false) {
    return PrepareDownloadTuple(
      Response.notFound('File not Found'),
      null,
    );
  }

  return PrepareDownloadTuple(
    Response.ok(null),
    file,
  );
}

Future<PrepareDownloadTuple> handlePrepareShowfileDownloadReq(
    Request request, OnPrepareShowfileDownloadCallback? callback) async {
  if (callback == null) {
    LoggingManager.instance.server.warning(
        "A download request was denied because the OnShowfileDownloadCallback is null");
    return PrepareDownloadTuple(
        Response.internalServerError(
            body: "The OnShowfileDownloadCallback is null"),
        null);
  }

  // Call out to the main thread to Pack up the showfile into an archive and give us a reference to the completed archive.
  final file = await callback();

  if (await file.exists() == false) {
    return PrepareDownloadTuple(
      Response.notFound('File not Found'),
      null,
    );
  }

  if (Storage.instance.isWriting || Storage.instance.isReading) {
    if (Storage.instance.isWriting) {
      LoggingManager.instance.server.warning(
          "A download request was denied because the Storage class is busy writing");
    }

    if (Storage.instance.isReading) {
      LoggingManager.instance.server.warning(
          "A download request was denied because the Storage class is busy reading");
    }

    return PrepareDownloadTuple(
        Response.internalServerError(body: 'Storage is busy. Please try again'),
        null);
  }

  return PrepareDownloadTuple(
    Response.ok(null),
    file,
  );
}

Future<Response> handleShowfileUploadReq(
    Request request, OnShowFileReceivedCallback? callback) async {
  if (request.contentLength == null || request.contentLength == 0) {
    return Response(400); // Bad Request.
  }

  if (callback == null) {
    LoggingManager.instance.server
        .severe('OnShowFileReceivedCallback was null');
    return Response.internalServerError(body: 'An error occured');
  }

  final buffer = <int>[];
  await for (var bytes in request.read()) {
    buffer.addAll(bytes.toList());
  }

  final result = await callback(buffer);

  // Good Showfile.
  if (result.generalResult == true) return Response.ok(null);
  
  // Unknown error.
  if (result.validationResult == null)
    return Response.internalServerError(
        body: 'An error occurred. Please try again');

  // Showfile is incompatiable with this version of the software.
  if (result.validationResult!.isCompatiableFileVersion == false)
    return Response.internalServerError(
        body:
            'Showfile was created with a newer version of Castboard. Please update player software');

  // Showfile failed validation.
  if (result.validationResult!.isValid == false)
    return Response.internalServerError(
        body:
            'Invalid showfile. Please check you have the correct file and try again.');

  // Fallen through. But something is probably wrong.
  return Response.internalServerError(body: 'An unknown error occurred');
}

Future<Response> handlePlaybackReq(
    Request request, dynamic onPlaybackCommand) async {
  await for (var data in request.read()) {
    // TODO: Check the length of that Data isnt something massive, in case we try to send a Binary Blob to this route.
    final String command = utf8.decode(data);
    switch (command) {
      case 'play':
        onPlaybackCommand?.call(PlaybackCommand.play);
        break;
      case 'pause':
        onPlaybackCommand?.call(PlaybackCommand.pause);
        break;
      case 'next':
        onPlaybackCommand?.call(PlaybackCommand.next);
        break;
      case 'prev':
        onPlaybackCommand?.call(PlaybackCommand.prev);
        break;
      default:
        return Response.notFound(null);
    }
  }

  return Response.ok(null);
}

Future<Response> handleSystemCommandReq(
    Request request, OnSystemCommandReceivedCallback? onSystemCommand) async {
  final rawJson = await request.readAsString();
  try {
    final rawData = json.decoder.convert(rawJson);
    final SystemCommand command = SystemCommand.fromMap(rawData);

    if (command.type == SystemCommandType.none) {
      LoggingManager.instance.server.warning('Received a NoneSystemCommand');
      return Response.ok(null);
    }

    onSystemCommand?.call(command);

    return Response.ok(null);
  } on EnumConversionError {
    LoggingManager.instance.server.warning(
        'Failed to parse SystemCommand.type into SystemCommandType enum');
    return Response.ok(null);
  } catch (error) {
    return Response.internalServerError(body: error.toString());
  }
}

Future<Response> handleSystemConfigReq(
    Request request, OnSystemConfigPullCallback? callback) async {
  if (callback == null) {
    LoggingManager.instance.server
        .warning('Tried to call OnSystemConfigPullCallback but it was null');
    return Response.internalServerError(
        body: 'OnSystemConfigPull Callback was null');
  }

  final result = await callback();

  if (result == null) {
    LoggingManager.instance.server.warning(
        'OnSystemConfigPullCallback returned null. Unable to repond with System Config');
    return Response.internalServerError(body: 'An error occurred');
  }

  final jsonData = json.encoder.convert(result.toMap());
  return Response.ok(jsonData);
}

Future<Response> handleSystemConfigPost(
    Request request, OnSystemConfigPostCallback? callback) async {
  if (callback == null) {
    LoggingManager.instance.server
        .warning('Tried to call OnSystemConfigPostCallback but it was null');
    return Response.internalServerError(
        body: 'OnSystemConfigPost Callback was null');
  }

  final rawJson = await request.readAsString();
  final config = SystemConfig.fromMap(json.decode(rawJson));

  final commitResult = await callback(config);

  if (commitResult.success == true) {
    return Response.ok(commitResult.restartRequired.toString());
  } else {
    return Response.internalServerError(
        body: 'An error occurred. Please try again');
  }
}

Future<Response> handleAlive(Request req) async {
  LoggingManager.instance.server.info('Received an are you alive ping');
  return Response.ok(null);
}

Future<Response> handleLogsDownload(
    Request req, OnPrepareLogsDownloadCallback? callback) async {
  if (callback == null) {
    LoggingManager.instance.server
        .warning('Tried to call OnLogsDownloadCallback but it was null');
    return Response.internalServerError(body: 'An error occured');
  }

  final logsArchive = await callback();

  return Response.ok(logsArchive.openRead(),
      headers: await generateFileHeaders(logsArchive));
}
