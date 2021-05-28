import 'dart:convert';
import 'dart:io';
import 'package:castboard_core/storage/Storage.dart';

typedef void OnPlaybackCommandReceivedCallback(PlaybackCommand command);
typedef void OnShowFileReceivedAndStoredCallback();

enum PlaybackCommand {
  play,
  pause,
  next,
  prev,
}

class Server {
  final dynamic address;
  final int port;
  final OnPlaybackCommandReceivedCallback onPlaybackCommand;
  final OnShowFileReceivedAndStoredCallback onShowFileReceived;

  HttpServer httpServer;

  Server({
    this.address,
    this.port,
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

    httpServer = await HttpServer.bind(address, port);
    _runServerLoop(httpServer);
    return;
  }

  void _runServerLoop(HttpServer server) async {
    await for (var request in server) {
      final route = request.uri.toString();
      _router(route, request);
    }
  }

  Future<void> shutdown() async {
    return httpServer.close();
  }

  void _router(String route, HttpRequest request) {
    final method = request.method;
    switch (route) {
      case '/':
        if (method == 'GET') _handleRootReq(request);
        break;
      case '/upload':
        if (method == 'PUT') _handleUploadReq(request);
        break;
      case '/playback':
        if (method == 'PUT') _handlePlaybackReq(request);
        break;
    }
  }

  void _handlePlaybackReq(HttpRequest request) async {
    await for (var data in request) {
      // TODO: Check the length of that Data isnt something massive, incase we try to send a Binary Blob to this route.

      final String command = utf8.decode(data);
      print(command);

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
      }
    }

    request.response.close();
  }

  void _handleUploadReq(HttpRequest request) async {
    // TODO : Handle this better. Calling request.headers.contentType accesses the Stream which then throws an error when you try to 'await for' it below.

    // if (request.headers.contentType != ContentType.binary) {
    //   request.response.close();
    // }

    final buffer = <int>[];

    await for (var bytes in request) {
      buffer.addAll(bytes.toList());
    }

    // TODO: Verify the File is sane before writing it into storage.

    print("Received");

    await Storage.instance.copyShowFileIntoPlayerStorage(buffer);

    request.response.close();

    onShowFileReceived?.call();
  }

  void _handleRootReq(HttpRequest request) {
    request.response.write('Here comes some HTML');
    request.response.close();
  }
}
