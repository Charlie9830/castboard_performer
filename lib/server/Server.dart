import 'dart:io';
import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/models/RemoteShowData.dart';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_core/models/system_controller/DeviceResolution.dart';
import 'package:castboard_core/models/understudy/message_model.dart';
import 'package:castboard_core/utils/getUid.dart';
import 'package:castboard_performer/models/ShowFileUploadResult.dart';
import 'package:castboard_performer/models/understudy_session_model.dart';
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
typedef OnSoftwareUpdateCallback = Future<void> Function();
typedef OnPreviewStreamListenersStateChangedCallback = void Function(
    bool hasListeners, PreviewStreamListenerState listenerState);
typedef OnUnderstudyClientConnectionEstablished = void Function(
    UnderstudySessionModel session);
typedef OnUnderstudyClientConnectionDropped = void Function(String clientId);

// Config
const _webAppFilePath = 'web_app/';
const _defaultDocument = 'index.html';

const String kServerAddress = '127.0.0.1';
const int kServerPort = 8080;

// WebSocket Stream
final Map<String, WebSocketChannel> _previewStreamWebSocketChannels = {};
final Map<String, WebSocketChannel> _understudyWebSocketChannels = {};
bool get hasWebViewerClients => _understudyWebSocketChannels.isNotEmpty;

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
  final OnUnderstudyClientConnectionEstablished?
      onUnderstudyClientConnectionEstablished;
  final OnUnderstudyClientConnectionDropped?
      onUnderstudyClientConnectionDropped;

  File? _showfileDownloadTarget;
  File? _logsDownloadTarget;

  late HttpServer server;

  Server({
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
    required this.onHeartbeatReceived,
    this.onUnderstudyClientConnectionEstablished,
    this.onUnderstudyClientConnectionDropped,
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
        InternetAddress.anyIPv4,
        kServerPort,
      );

      LoggingManager.instance.server
          .info("Server running at ${server.address}:${server.port}");
    } catch (e, stacktrace) {
      // TODO: Trying to use a Socket that is already in use will throw a Socket Exception here.
      // We should provide more information to the user about this instead of just throwing them into a general
      // server error.
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

    // Understudy Websocket.
    router.get('/api/understudy', (Request req) {
      return webSocketHandler(
          (socket) => _handleWebClientConnectionEstablished(socket, req));
    });

    // Understudy Asset Requests.
    router.get('/api/understudy/headshots/<headshot>', handleHeadshotRequest);
    router.get('/api/understudy/images/<image>', handleImageRequest);
    router.get(
        '/api/understudy/backgrounds/<background>', handleBackgroundRequest);
    router.get(
        '/api/understudy/fonts/builtin/<familyname>', handleBuiltInFontRequest);
    router.get(
        '/api/understudy/fonts/custom/<fontId>', handleCustomFontRequest);
    return router;
  }

  void setWebViewerClientsSlideIndex(int index) {
    if (_understudyWebSocketChannels.isEmpty) {
      return;
    }

    final message = UnderstudyMessageModel(
        type: UnderstudyMessageType.slideIndex, payload: index.toString());

    for (final channel in _understudyWebSocketChannels.values) {
      channel.sink.add(message.toJson());
    }
  }

  void updateWebViewerClientHTML(UnderstudyMessageModel message) {
    if (_understudyWebSocketChannels.isEmpty) {
      return;
    }

    for (final channel in _understudyWebSocketChannels.values) {
      channel.sink.add(message.toJson());
    }
  }

  void _handleWebClientConnectionEstablished(
      WebSocketChannel webSocket, Request req) async {
    // Noop listener for when the Client sends data to us, as we don't care what they send us.
    void noop(dynamic event) {}

    // Extract the clientId Query parameter.
    final queryParams = req.requestedUri.queryParameters;
    final String existingClientId = queryParams['id'] ?? '';

    // Extract the Remote address from request context.
    InternetAddress? remoteAddress;
    final rawConnectionInfo = req.context['shelf.io.connection_info'];
    if (rawConnectionInfo is HttpConnectionInfo) {
      remoteAddress = rawConnectionInfo.remoteAddress;
    }

    // Create a new ClientId if an existing one hasn't been provided by the client.
    final clientId = existingClientId.isEmpty ? getUid() : existingClientId;

    // Setup onDone Listener. Actual Listener is just a noop as we don't care what the client sends to us,
    // only that they are listening on the other end.
    webSocket.stream.listen(noop, onDone: () {
      // Remove the channel when the client has disconnected.
      _understudyWebSocketChannels.remove(clientId);

      onUnderstudyClientConnectionDropped?.call(clientId);
    });

    // Add the channel to the list.
    _understudyWebSocketChannels[clientId] = webSocket;

    webSocket.sink.add(UnderstudyMessageModel(
            type: UnderstudyMessageType.clientId, payload: clientId)
        .toJson());

    // Collect a list of all Network Addresses the device is bound to.
    final deviceAddresses = (await NetworkInterface.list(
            includeLinkLocal: true,
            includeLoopback: true,
            type: InternetAddressType.IPv4))
        .map((interface) => interface.addresses)
        .expand((i) => i)
        .toSet();

    final userAgentString = req.headers['user-agent'] ?? '';

    // Call the onWebViewerClientConnectionEstablished to inform Performer that a connection has been established.
    // Performer will then call the updateWebViewerHTML function to send the html slides to the client.
    onUnderstudyClientConnectionEstablished?.call(UnderstudySessionModel(
      id: clientId,
      connectionTimestamp: DateTime.now(),
      active: true,
      clientIPAddress: remoteAddress == null
          ? 'Unknown'
          : remoteAddress.isLoopback || deviceAddresses.contains(remoteAddress)
              ? 'This Device'
              : remoteAddress.address,
      userAgentString: userAgentString,
    ));
  }

  Future<void> shutdown() async {
    return server.close();
  }

  bool get previewStreamHasListeners =>
      _previewStreamWebSocketChannels.isNotEmpty;

  InternetAddress get address => server.address;

  int get port => server.port;
}
