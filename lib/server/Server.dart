import 'dart:io';
import 'package:http_server/http_server.dart';

class Server {
  final dynamic address;
  final int port;
  HttpServer httpServer;

  Server({
    this.address,
    this.port,
  });

  Future<void> initalize() async {
    httpServer = await HttpServer.bind(address, port);
    httpServer.listen((request) {
      final route = request.uri.toString();
      _router(route, request);
    });

    return;
  }

  Future<void> shutdown() async {
    return httpServer.close();
  }

  void _router(String route, HttpRequest request) {
    switch (route) {
      case '/':
        _handleRootReq(request);
        break;
    }
  }

  void _handleRootReq(HttpRequest request) {
    request.response.write('Here comes some HTML');
    request.response.close();
  }
}
