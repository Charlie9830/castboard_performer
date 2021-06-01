import 'dart:async';

import 'package:shelf/shelf.dart';

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type',
};

Handler corsMiddleware(FutureOr<Response> Function(Request) innerHandler) {
  return (Request request) async {
    final response = await innerHandler(request);
    print(request.headers);

    // Set CORS when responding to OPTIONS request
    if (request.method == 'OPTIONS') {
      return Response.ok('', headers: _corsHeaders);
    }

    // Move onto handler
    return response;
  };
}
