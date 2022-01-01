import 'dart:io';
import 'dart:typed_data';
import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/models/RemoteShowData.dart';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_core/models/system_controller/DeviceResolution.dart';
import 'package:castboard_player/server/Routes.dart';
import 'package:castboard_core/system-commands/SystemCommands.dart';
import 'package:castboard_player/server/getAssetBundleRootPath.dart';
import 'package:castboard_player/server/routeHandlers.dart';
import 'package:castboard_player/system_controller/SystemConfigCommitResult.dart';
import 'package:path/path.dart' as p;

// Shelf
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';


typedef void OnSystemCommandReceivedCallback(SystemCommand command);
typedef Future<
    List<DeviceResolution>> OnAvailableResolutionsRequestedCallback();
typedef void OnPlaybackCommandReceivedCallback(PlaybackCommand command);
typedef Future<bool> OnShowFileReceivedCallback(List<int> bytes);
typedef RemoteShowData OnShowDataPullCallback();
typedef Future<bool> OnShowDataReceivedCallback(RemoteShowData data);
typedef void OnHeartbeatCallback(String sessionId);
typedef Future<SystemConfig?> OnSystemConfigPullCallback();
typedef Future<SystemConfigCommitResult> OnSystemConfigPostCallback(
    SystemConfig config);
typedef Future<File> OnShowfileDownloadCallback();
typedef Future<File> OnLogsDownloadCallback();

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
  final String address;
  final int port;
  final OnPlaybackCommandReceivedCallback? onPlaybackCommand;
  final OnShowFileReceivedCallback? onShowFileReceived;
  final OnShowDataPullCallback? onShowDataPull;
  final OnShowDataReceivedCallback? onShowDataReceived;
  final OnHeartbeatCallback onHeartbeatReceived;
  final OnSystemCommandReceivedCallback? onSystemCommandReceived;
  final OnSystemConfigPullCallback? onSystemConfigPull;
  final OnSystemConfigPostCallback? onSystemConfigPostCallback;
  final OnShowfileDownloadCallback? onShowfileDownload;
  final OnLogsDownloadCallback? onLogsDownloadCallback;

  late HttpServer server;

  Server({
    this.address = '0.0.0.0',
    this.port = 8080,
    this.onPlaybackCommand,
    this.onShowFileReceived,
    this.onShowDataPull,
    this.onShowDataReceived,
    this.onSystemCommandReceived,
    this.onSystemConfigPull,
    this.onSystemConfigPostCallback,
    this.onShowfileDownload,
    this.onLogsDownloadCallback,
    required this.onHeartbeatReceived,
  });

  Future<void> initalize() async {
    // final discoverySocket = await ServerSocket.bind(InternetAddress(address), port + 1);
    // print('Discovery Socket Ready');
    // discoverySocket.listen((socket) async {
    //   final result = await socket.single;
    //   print(utf8.decode(result));
    // });

    try {
      // Serve directly from the _webAppFilePath. In future we may change this to the Asset Bundle Root so that we could
      // serve routes to Debug logs etc.
      final String webAppPath =
          p.join(getAssetBundleRootPath(), _webAppFilePath);
      LoggingManager.instance.server
          .info("Creating static file handler serving from $webAppPath");
      final staticFileHandler = createStaticHandler(
        webAppPath,
        defaultDocument: _defaultDocument,
      );

      LoggingManager.instance..server.info("Initializing router");
      final router = _initializeRouter();

      final cascade = Cascade().add(staticFileHandler).add(router);

      LoggingManager.instance..server.info("Starting up shelf server");
      server = await shelf_io.serve(
        Pipeline().addMiddleware(corsHeaders()).addHandler(cascade.handler),
        address,
        port,
      );
      LoggingManager.instance
        ..server.info("Server running at ${server.address}:${server.port}");
    } catch (e, stacktrace) {
      LoggingManager.instance
        ..server
            .severe('General error starting the shelf server', e, stacktrace);
    }
    return;
  }

  Router _initializeRouter() {
    Router router = Router();

    // Alive
    router.get(Routes.alive, (Request req) {
      return handleAlive(req);
    });

    // Heartbeat
    router.post(Routes.heartbeat, (Request req) {
      return handleHeartbeat(req, onHeartbeatReceived);
    });

    // Playback.
    router.put(Routes.playback, (Request req) {
      LoggingManager.instance.server.info('Playback PUT command received');
      return handlePlaybackReq(req, onPlaybackCommand);
    });

    // System Configuration.
    router.get(Routes.system, (Request req) {
      return handleSystemConfigReq(req, onSystemConfigPull);
    });

    router.post(Routes.system, (Request req) {
      return handleSystemConfigPost(req, onSystemConfigPostCallback);
    });

    // System Command Send Port.
    router.put(Routes.systemCommand, (Request req) {
      LoggingManager.instance.server.info('System PUT command received');
      return handleSystemCommandReq(req, onSystemCommandReceived);
    });

    // Show File Upload
    router.put(Routes.upload, (Request req) {
      LoggingManager.instance.server.info('Show File Upload PUT received');
      return handleUploadReq(req, onShowFileReceived);
    });

    // Show File Download
    router.get(Routes.download, (Request req) {
      LoggingManager.instance.server
          .info('Show File Download GET command received');
      return handleDownloadReq(req, onShowfileDownload);
    });

    // Show Data Pull
    router.get(Routes.show, (Request req) {
      LoggingManager.instance.server.info('Show Data GET command received');
      return handleShowDataPull(req, onShowDataPull);
    });

    // Show Data Push
    router.post(Routes.show, (Request req) {
      LoggingManager.instance.server.info('Show Data POST command received');
      return handleShowDataPost(req, onShowDataReceived);
    });

    // Logs Download
    router.get(Routes.logsDownload, (Request req) {
      LoggingManager.instance.server.info('Logs Download GET received');
      return handleLogsDownload(req, onLogsDownloadCallback);
    });

    return router;
  }

  Future<void> shutdown() async {
    return server.close();
  }
}
