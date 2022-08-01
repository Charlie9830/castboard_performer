import 'dart:io';
import 'dart:typed_data';
import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/models/RemoteShowData.dart';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_core/models/system_controller/DeviceResolution.dart';
import 'package:castboard_core/utils/getUid.dart';
import 'package:castboard_performer/models/ShowFileUploadResult.dart';
import 'package:castboard_performer/server/Routes.dart';
import 'package:castboard_core/system-commands/SystemCommands.dart';
import 'package:castboard_performer/server/cacheHeaders.dart';
import 'package:castboard_performer/server/getAssetBundleRootPath.dart';
import 'package:castboard_performer/server/prepareStaticWebDirectory.dart';
import 'package:castboard_performer/server/routeHandlers.dart';
import 'package:castboard_performer/system_controller/SystemConfigCommitResult.dart';
import 'package:path/path.dart' as p;

// Shelf
import 'package:shelf_plus/shelf_plus.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef OnSystemCommandReceivedCallback = void Function(SystemCommand command);
typedef OnAvailableResolutionsRequestedCallback = Future<List<DeviceResolution>>
    Function();
typedef OnPlaybackCommandReceivedCallback = void Function(
    PlaybackCommand command);
typedef OnShowFileReceivedCallback = Future<ShowfileUploadResult> Function(
    List<int> bytes);
typedef OnShowDataPullCallback = RemoteShowData Function();
typedef OnShowDataReceivedCallback = Future<bool> Function(RemoteShowData data);
typedef OnHeartbeatCallback = void Function(String sessionId);
typedef OnSystemConfigPullCallback = Future<SystemConfig?> Function();
typedef OnSystemConfigPostCallback = Future<SystemConfigCommitResult> Function(
    SystemConfig config);
typedef OnPrepareShowfileDownloadCallback = Future<File> Function();
typedef OnPrepareLogsDownloadCallback = Future<File> Function();
typedef OnSoftwareUpdateCallback = Future<bool> Function(List<int> byteData);
typedef OnPreviewStreamListenersStateChangedCallback = void Function(
    bool hasListeners, PreviewStreamListenerState listenerState);

// Config
const _webAppFilePath = 'web_app/';
const _defaultDocument = 'index.html';

// WebSocket Stream
final Map<String, WebSocketChannel> _webSocketChannels = {};

enum PlaybackCommand {
  play,
  pause,
  next,
  prev,
}

enum PreviewStreamListenerState {
  listenerJoined,
  listenerLeft,
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
  final OnPrepareShowfileDownloadCallback? onPrepareShowfileDownload;
  final OnPrepareLogsDownloadCallback? onPrepareLogsDownloadCallback;
  final OnSoftwareUpdateCallback? onSoftwareUpdate;
  final OnPreviewStreamListenersStateChangedCallback?
      onPreviewStreamListenersChanged;

  File? _showfileDownloadTarget;
  File? _logsDownloadTarget;

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
    this.onPrepareShowfileDownload,
    this.onPrepareLogsDownloadCallback,
    this.onSoftwareUpdate,
    this.onPreviewStreamListenersChanged,
    required this.onHeartbeatReceived,
  });

  Future<void> initalize() async {
    try {
      // Serve directly from the _webAppFilePath. In future we may change this to the Asset Bundle Root so that we could
      // serve routes to Debug logs etc.
      final String webAppPath =
          p.join(getAssetBundleRootPath(), _webAppFilePath);

      // Prepare the Static Web Directory.
      LoggingManager.instance.server.info('Preparing Static Web Directory');
      await prepareStaticWebDirectory(webAppPath);

      LoggingManager.instance.server
          .info("Creating static file handler serving from $webAppPath");

      final staticFileHandler = createStaticHandler(
        webAppPath,
        defaultDocument: _defaultDocument,
      );

      LoggingManager.instance.server.info("Initializing router");
      final router = _initializeRouter();

      final cascade = Cascade().add(staticFileHandler).add(router);

      LoggingManager.instance.server.info("Starting up shelf server");
      server = await shelf_io.serve(
        const Pipeline()
            .addMiddleware(corsHeaders())
            .addMiddleware(cacheHeaders())
            .addHandler(cascade.handler),
        address,
        port,
      );
      LoggingManager.instance.server
          .info("Server running at ${server.address}:${server.port}");
    } catch (e, stacktrace) {
      LoggingManager.instance.server
          .severe('General error starting the shelf server', e, stacktrace);
      rethrow;
    }
    return;
  }

  RouterPlus _initializeRouter() {
    RouterPlus router = Router().plus;

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
      return handleShowfileUploadReq(req, onShowFileReceived);
    });

    router.put(Routes.systemSoftwareUpdate, (Request req) {
      LoggingManager.instance.server
          .info('System Software Update PUT Received');
      return handleSoftwareUpdateReq(req, onSoftwareUpdate);
    });

    // Prepare Showfile download
    router.get(Routes.prepareShowfileDownload, (Request req) {
      LoggingManager.instance.server
          .info('Prepare Showfile for download GET received.');
      return (Request innerReq) async {
        final result = await handlePrepareShowfileDownloadReq(
            innerReq, onPrepareShowfileDownload);

        if (result.file != null) {
          _showfileDownloadTarget = result.file;
          return result.response;
        }

        return result.response;
      };
    });

    // Showfile download.
    router.get(Routes.showfileDownload, (Request req) async {
      if (_showfileDownloadTarget == null) {
        LoggingManager.instance.server.warning(
            'A showfile download was called, but the _showfileDownloadTarget was null.');
        return Response.internalServerError(
            body: 'An error occurred, please try again');
      }

      if (await _showfileDownloadTarget!.exists() == false) {
        LoggingManager.instance.server.warning(
            "A showfile download was called, but the target file does not exist");
        return Response.internalServerError(
            body: 'An error occurred, please try again');
      }

      return _showfileDownloadTarget;
    }, use: download(filename: 'Showfile.zip'));

    // Prepare logs download.
    router.get(Routes.prepareLogsDownload, (Request req) {
      LoggingManager.instance.server
          .info('Prepare logs for download GET received');
      return (Request innerReq) async {
        final result = await handlePrepareLogsDownloadReq(
            innerReq, onPrepareLogsDownloadCallback);

        if (result.file != null) {
          _logsDownloadTarget = result.file;
          return result.response;
        }

        return result.response;
      };
    });

    // Logs Download
    router.get(Routes.logsDownload, (Request req) async {
      if (_logsDownloadTarget == null) {
        LoggingManager.instance.server.warning(
            'A log files download was called, but the _logsDownloadTarget was null.');
        return Response.internalServerError(
            body: 'An error occurred, please try again');
      }

      if (await _logsDownloadTarget!.exists() == false) {
        LoggingManager.instance.server.warning(
            "A logs file download was called, but the target file does not exist");
        return Response.internalServerError(
            body: 'An error occurred, please try again');
      }

      return _logsDownloadTarget;
    }, use: download(filename: 'logs.zip'));

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

    // Websocket
    router.get('/ws', webSocketHandler(_handleWebSocketConnectionEstablished));

    return router;
  }

  void _handleWebSocketConnectionEstablished(WebSocketChannel webSocket) {
    final String id = getUid();
    void noop(dynamic event) {}

    // Setup onDone Listener. Actual Listener is just a noop as we don't care what the client sends to us,
    // only that they are listening on the other end.
    webSocket.stream.listen(noop, onDone: () {
      _webSocketChannels.remove(id);
      onPreviewStreamListenersChanged?.call(_webSocketChannels.isNotEmpty,
          PreviewStreamListenerState.listenerLeft);
    }, cancelOnError: true);

    _webSocketChannels[id] = webSocket;
    onPreviewStreamListenersChanged?.call(_webSocketChannels.isNotEmpty,
        PreviewStreamListenerState.listenerJoined);
  }

  Future<void> shutdown() async {
    return server.close();
  }

  void sendFrameToPreviewStream(Uint8List bytes) {
    for (var channel in _webSocketChannels.values) {
      channel.sink.add(bytes);
    }
  }

  bool get previewStreamHasListeners => _webSocketChannels.isNotEmpty;
}
