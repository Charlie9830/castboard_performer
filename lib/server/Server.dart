import 'dart:convert';
import 'dart:io';
import 'package:castboard_core/storage/Storage.dart';
import 'package:castboard_player/server/CorsMiddleware.dart';

// Shelf
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

typedef void OnPlaybackCommandReceivedCallback(PlaybackCommand command);
typedef void OnShowFileReceivedAndStoredCallback();

// Config
const _staticFilesPath = 'static/';
const _defaultDocument = 'index.html';

enum PlaybackCommand {
  play,
  pause,
  next,
  prev,
}

class Server {
  final dynamic address;
  final int port;
  final OnPlaybackCommandReceivedCallback? onPlaybackCommand;
  final OnShowFileReceivedAndStoredCallback? onShowFileReceived;

  late HttpServer server;

  Server({
    this.address,
    this.port = 8080,
    this.onPlaybackCommand,
    this.onShowFileReceived,
  });

  Future<void> initalize() async {
    // final discoverySocket = await ServerSocket.bind(InternetAddress(address), port + 1);
    // print('Discovery Socket Ready');
    // discoverySocket.listen((socket) async {
    //   final result = await socket.single;
    //   print(utf8.decode(result));
    // });

    final router = _initializeRouter();

    server = await shelf_io.serve(
        Pipeline().addMiddleware(corsMiddleware).addHandler(router),
        address,
        port);
    print("Server Running");
    // _runServerLoop(server);
    return;
  }

  Router _initializeRouter() {
    Router router = Router();
    router.get(
        '/',
        createStaticHandler(_staticFilesPath,
            defaultDocument: _defaultDocument,
            listDirectories: true
            ));

    // Playback.
    router.put('/playback', _handlePlaybackReq);

    // Show File Upload
    router.put('/upload', _handleUploadReq);

    return router;
  }

  Future<void> shutdown() async {
    return server.close();
  }

  Future<Response> _handlePlaybackReq(Request request) async {
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

  Future<Response> _handleUploadReq(Request request) async {
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
}
