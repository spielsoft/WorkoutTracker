import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  test(
    'authorization client applies a stable copy of Google headers',
    () async {
      final headers = {'Authorization': 'Bearer original-token'};
      final inner = _CapturingClient();
      final client = GoogleAuthorizationHeadersClient(
        headers: headers,
        inner: inner,
      );

      headers['Authorization'] = 'Bearer mutated-token';
      await client.send(http.Request('GET', Uri.parse('https://example.com')));

      expect(
        inner.sentRequest?.headers['Authorization'],
        'Bearer original-token',
      );
    },
  );
}

class _CapturingClient extends http.BaseClient {
  http.BaseRequest? sentRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sentRequest = request;
    return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
  }
}
