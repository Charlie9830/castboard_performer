import 'dart:async';
import 'dart:convert';

import 'package:castboard_core/classes/FontRef.dart';
import 'package:castboard_core/classes/PhotoRef.dart';
import 'package:castboard_core/enum-converters/EnumConversionError.dart';
import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/models/RemoteShowData.dart';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_core/storage/Storage.dart';
import 'package:castboard_core/system-commands/SystemCommands.dart';
import 'package:castboard_performer/server/PrepareDownloadTuple.dart';
import 'package:castboard_performer/server/Server.dart';
import 'package:castboard_performer/server/build_image_etag.dart';
import 'package:castboard_performer/server/generateFileHeaders.dart';
import 'package:castboard_performer/server/match_image_etag.dart';
import 'package:castboard_performer/server/readMultipartFileRequest.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_plus/shelf_plus.dart';
import 'package:shelf_multipart/multipart.dart';

Future<Response> handleHeadshotRequest(Request request, String filename) async {
  final ref = ImageRef.fromFilename(filename);

  if (matchImageEtag(request, ref)) {
    // Return 304 - Not Modified, this forces the browser to use it's own cached version.
    return Response(304);
  }

  final file = Storage.instance.getHeadshotFile(ref);
  if (file == null || await file.exists() == false) {
    return Response.notFound(null);
  }

  return Response.ok(file.openRead(), headers: buildImageEtag(ref));
}

Future<Response> handleImageRequest(Request request, String filename) async {
  final ref = ImageRef.fromFilename(filename);

  if (matchImageEtag(request, ref)) {
    // Return 304 - Not Modified, this forces the browser to use it's own cached version.
    return Response(304);
  }

  final file = Storage.instance.getImageFile(ref);
  if (file == null || await file.exists() == false) {
    return Response.notFound(null);
  }

  return Response.ok(file.openRead(), headers: buildImageEtag(ref));
}

Future<Response> handleBackgroundRequest(
    Request request, String filename) async {
  final ref = ImageRef.fromFilename(filename);

  if (matchImageEtag(request, ref)) {
    // Return 304 - Not Modified, this forces the browser to use it's own cached version.
    return Response(304);
  }

  final file = Storage.instance.getBackgroundFile(ref);
  if (file == null || await file.exists() == false) {
    return Response.notFound(null);
  }

  return Response.ok(file.openRead(), headers: buildImageEtag(ref));
}

Future<Response> handleBuiltInFontRequest(
    Request request, String fontFamily) async {
  const regularSuffix = '-Regular';
  const variableWeightSuffix = '-VariableFont_wght';
  const extension = '.ttf';

  final decoded = Uri.decodeComponent(fontFamily);
  final fontDirectory =
      decoded.replaceAll(' ', '_'); // Replace spaces with underscores
  final fontFileBaseName = decoded.replaceAll(' ', ''); // Remove Spaces.

  try {
    // Try to fetch font with the -Regular suffix first.
    final bytes = await rootBundle.load(
        'assets/fonts/$fontDirectory/$fontFileBaseName$regularSuffix$extension');

    return Response.ok(bytes.buffer.asUint8List());
  } on FlutterError {
    // Font may not have a -Regular suffix. Try -VariableFont_wght suffix instead.
    final bytes = await rootBundle.load(
        'assets/fonts/$fontDirectory/$fontFileBaseName$variableWeightSuffix$extension');

    return Response.ok(bytes.buffer.asUint8List());
  } catch (e, stacktrace) {
    // Another error occurred.
    LoggingManager.instance.server
        .warning('Failed to serve Built in Font File.', e, stacktrace);
    return Response.notFound(null);
  }
}

Future<Response> handleCustomFontRequest(Request request, String fontId) async {
  final fontFile = Storage.instance.getFontFile(FontRef.fromString(fontId));

  if (fontFile == null || await fontFile.exists() == false) {
    return Response.notFound(null);
  }

  return Response.ok(fontFile.openRead());
}

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

  if (request.isMultipart == false) {
    return Response(401); // Not a mulitpart request.
  }

  if (callback == null) {
    LoggingManager.instance.server
        .severe('OnShowFileReceivedCallback was null');
    return Response.internalServerError(body: 'An error occured');
  }

  // Read request into buffer.
  final buffer = await readMultipartFileRequest(request);

  // Send the buffer to the Player for validation.
  final result = await callback(buffer);

  // Good Showfile.
  if (result.generalResult == true) return Response.ok(null);

  // Unknown error.
  if (result.validationResult == null) {
    return Response.internalServerError(
        body: 'An error occurred. Please try again');
  }

  // Showfile is incompatiable with this version of the software.
  if (result.validationResult!.isCompatiableFileVersion == false) {
    return Response.internalServerError(
        body:
            'Showfile was created with a newer version of Castboard. Please update Performer software');
  }

  // Showfile failed validation.
  if (result.validationResult!.isValid == false) {
    return Response.internalServerError(
        body:
            'Invalid showfile. Please check you have the correct file and try again.');
  }

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

Future<Response> _handleHeadshotRequest(
    Request request, String filename) async {
  if (Storage.initialized == false) {
    return Response.internalServerError();
  }

  return Response.ok(
      Storage.instance.getHeadshotFile(ImageRef.fromFilename(filename)));
}
