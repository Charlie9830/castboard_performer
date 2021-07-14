import 'dart:io';
import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/models/RemoteShowData.dart';
import 'package:castboard_player/server/getAssetBundleRootPath.dart';
import 'package:castboard_player/server/routeHandlers.dart';
import 'package:path/path.dart' as p;

// Shelf
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

typedef void OnPlaybackCommandReceivedCallback(PlaybackCommand command);
typedef void OnShowFileReceivedAndStoredCallback();
typedef RemoteShowData OnShowDataPullCallback();
typedef Future<bool> OnShowDataReceivedCallback(RemoteShowData data);

// Config
const _webAppFilePath = 'web_app/';
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

    // Serve directly from the _webAppFilePath. In future we may change this to the Asset Bundle Root so that we could
    // serve routes to Debug logs etc.

    LoggingManager.instance.server.info("Creating static file handler.");
    final staticFileHandler = createStaticHandler(
      p.join(getAssetBundleRootPath(), _webAppFilePath),
      defaultDocument: _defaultDocument,
    );

    LoggingManager.instance..server.info("Initializing router");
    final router = _initializeRouter();

    final cascade = Cascade().add(staticFileHandler).add(router);

    try {
      LoggingManager.instance..server.info("Starting up shelf server");
      server = await shelf_io.serve(
          Pipeline().addMiddleware(corsHeaders()).addHandler(cascade.handler),
          address,
          port);
      LoggingManager.instance
        ..server.info("Server running at ${server.address}:${server.port}");
    } catch (e, stacktrace) {
      LoggingManager.instance
        ..server.severe('Error starting the shelf server', e, stacktrace);
    }
    return;
  }

  Router _initializeRouter() {
    Router router = Router();

    // Playback.
    router.put('/playback',
        (Request req) {
          LoggingManager.instance.server.info('Playback PUT command received');
          return handlePlaybackReq(req, onPlaybackCommand);
        });

    // Show File Upload
    router.put(
        '/upload', (Request req) {
          LoggingManager.instance.server.info('Show File Upload PUT received');
          return handleUploadReq(req, onShowFileReceived);
        });

    // Show File Download
    router.get('/download', (Request req) {
      LoggingManager.instance.server.info('Show File Download GET command received');
      return handleDownloadReq(req);
    });

    // Show Data Pull
    router.get(
        '/show', (Request req) {
          LoggingManager.instance.server.info('Show Data GET command received');
          return handleShowDataPull(req, onShowDataPull);
        });

    // Show Data Push
    router.post(
        '/show', (Request req) {
          LoggingManager.instance.server.info('Show Data POST command received');
          return handleShowDataPost(req, onShowDataReceived);
        });

    return router;
  }

  Future<void> shutdown() async {
    return server.close();
  }
}
