import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
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

  test(
    'scoped Google API access requests scopes and closes the authenticated client after the action',
    () async {
      final gateway = _RecordingSignInAuthGateway();
      final authClient = _CloseTrackingAuthClient();
      final access = GoogleScopedApiAccess(
        authorizationGateway: gateway,
        authorizationClientFactory: (_) => authClient,
      );

      final result = await access.run(
        scopes: const [sheets.SheetsApi.spreadsheetsScope],
        action: (resources) async {
          expect(resources.sheetsApi, isA<sheets.SheetsApi>());
          expect(authClient.closed, isFalse);
          await Future<void>.delayed(Duration.zero);
          expect(authClient.closed, isFalse);
          return 'validated';
        },
      );

      expect(result, 'validated');
      expect(gateway.requestedScopes.single, [
        sheets.SheetsApi.spreadsheetsScope,
      ]);
      expect(authClient.closed, isTrue);
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

class _CloseTrackingAuthClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }

  @override
  void close() {
    closed = true;
  }
}

class _RecordingSignInAuthGateway extends ChangeNotifier
    implements SignInAuthGateway {
  final List<List<String>> requestedScopes = [];

  @override
  GoogleAccountProfile? get currentAccount => null;

  @override
  Future<void> restoreAccount() async {}

  @override
  Future<void> switchAccount({List<String> scopes = const []}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<Map<String, String>> authorizationHeaders(List<String> scopes) async {
    requestedScopes.add(scopes);
    return const {'Authorization': 'Bearer test-token'};
  }
}
