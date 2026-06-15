import 'package:http/http.dart' as http;

typedef GoogleAuthorizationClientFactory =
    http.Client Function(Map<String, String> headers);

class GoogleAuthorizationHeadersClient extends http.BaseClient {
  GoogleAuthorizationHeadersClient({
    required Map<String, String> headers,
    http.Client? inner,
  }) : headers = Map<String, String>.unmodifiable(headers),
       _inner = inner ?? http.Client();

  final Map<String, String> headers;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
