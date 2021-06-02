import 'dart:convert';

import 'package:castboard_core/models/RemoteShowData.dart';
import 'package:castboard_core/storage/Storage.dart';
import 'package:castboard_player/server/Server.dart';
import 'package:shelf/shelf.dart';

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
    Request request, dynamic onShowDataReceived) async {
  if (request.mimeType != 'application/json') {
    return Response.notModified();
  }

  if (onShowDataReceived == null) {
    return Response.internalServerError(body: 'onShowDataReceived is null');
  }

  final rawJson = await request.readAsString();
  try {
    final rawData = json.decoder.convert(rawJson);
    final result =
        await onShowDataReceived!.call(RemoteShowData.fromMap(rawData));
    if (result == true) {
      return Response.ok('');
    } else {
      return Response.internalServerError();
    }
  } catch (error) {
    return Response.internalServerError(body: error.toString());
  }
}

Future<Response> handleUploadReq(Request request, dynamic onShowFileReceived) async {
    // TODO : Handle this better. Calling request.headers.contentType accesses the Stream which then throws an error when you try to 'await for' it below.

    // if (request.headers.contentType != ContentType.binary) {
    //   request.response.close();
    // }

    final buffer = <int>[];

    await for (var bytes in request.read()) {
      buffer.addAll(bytes.toList());
    }

    // TODO: Verify the File is sane before writing it into storage.

    await Storage.instance!.copyShowFileIntoPlayerStorage(buffer);
    onShowFileReceived?.call();

    return Response.ok(null);
  }

  Future<Response> handlePlaybackReq(Request request, dynamic onPlaybackCommand) async {
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
