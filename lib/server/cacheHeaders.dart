import 'package:shelf/shelf.dart';

const _headers = {'Cache-Control': 'no-cache',};

Middleware cacheHeaders() {
  return (Handler handler) {
    return (Request request) async {
      final response = await handler(request);
      return response.change(headers: {...response.headersAll, ..._headers});
    };
  };
}
