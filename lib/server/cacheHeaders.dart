import 'package:shelf/shelf.dart';

const _headers = {
  'Cache-Control': 'max-age=0, must-revalidate',
};

Middleware cacheHeaders() {
  return (Handler handler) {
    return (Request request) async {
      final response = await handler(request);
      return response.change(headers: {...response.headersAll, ..._headers});
    };
  };
}
