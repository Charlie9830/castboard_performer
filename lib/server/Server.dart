import 'dart:io';
import 'package:castboard_core/models/RemoteShowData.dart';
import 'package:castboard_player/server/CorsMiddleware.dart';
import 'package:castboard_player/server/routeHandlers.dart';

// Shelf
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

typedef void OnPlaybackCommandReceivedCallback(PlaybackCommand command);
typedef void OnShowFileReceivedAndStoredCallback();
typedef RemoteShowData OnShowDataPullCallback();
typedef Future<bool> OnShowDataReceivedCallback(RemoteShowData data);

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
  final OnShowDataPullCallback? onShowDataPull;
  final OnShowDataReceivedCallback? onShowDataReceived;

  late HttpServer server;

  Server({
    this.address,
    this.port = 8080,
    this.onPlaybackCommand,
    this.onShowFileReceived,
    this.onShowDataPull,
    this.onShowDataReceived,
  });

  Future<void> initalize() async {
    // final discoverySocket = await ServerSocket.bind(InternetAddress(address), port + 1);
    // print('Discovery Socket Ready');
    // discoverySocket.listen((socket) async {
    //   final result = await socket.single;
    //   print(utf8.decode(result));
    // });

    final staticFileHandler = createStaticHandler(
          _staticFilesPath,
          defaultDocument: _defaultDocument,
        );
    final router = _initializeRouter();
    

    final cascade = Cascade().add(staticFileHandler).add(router);

    server = await shelf_io.serve(
        Pipeline().addMiddleware(corsMiddleware).addHandler(cascade.handler),
        address,
        port);
    print("Server Running");
    return;
  }

  Router _initializeRouter() {
    Router router = Router();
  
    // Playback.
    router.put('/playback',
        (Request req) => handlePlaybackReq(req, onPlaybackCommand));

    // Show File Upload
    router.put(
        '/upload', (Request req) => handleUploadReq(req, onShowFileReceived));

    // Show File Download
    router.get(
      '/download', (Request req) => handleDownloadReq(req)
    );

    // Show Data Pull
    router.get(
        '/show', (Request req) => handleShowDataPull(req, onShowDataPull));

    // Show Data Push
    router.post(
        '/show', (Request req) => handleShowDataPost(req, onShowDataReceived));

    return router;
  }

  Future<void> shutdown() async {
    return server.close();
  }
}
