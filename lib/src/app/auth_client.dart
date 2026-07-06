import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;

import 'account_session.dart';

typedef AuthClientFact = http.Client Function(Map<String, String> headers);

abstract interface class ApiAccess {
  Future<T> run<T>({
    required List<String> scopes,
    required Future<T> Function(ApiResources resources) action,
  });
}

class ScopedApiAccess implements ApiAccess {
  ScopedApiAccess({required this.auth, AuthClientFact? authClientFactory})
    : authClientFactory =
          authClientFactory ??
          ((headers) => AuthHeadersClient(headers: headers));

  final SignInAuthGateway auth;
  final AuthClientFact authClientFactory;

  @override
  Future<T> run<T>({
    required List<String> scopes,
    required Future<T> Function(ApiResources resources) action,
  }) async {
    final headers = await auth.authorizationHeaders(scopes);
    final client = authClientFactory(headers);
    try {
      return await action(ApiResources(client));
    } finally {
      client.close();
    }
  }
}

class ApiResources {
  ApiResources(this.client);

  final http.Client client;

  late final sheets.SheetsApi sheetsApi = sheets.SheetsApi(client);
  late final drive.DriveApi driveApi = drive.DriveApi(client);
}

class AuthHeadersClient extends http.BaseClient {
  AuthHeadersClient({required Map<String, String> headers, http.Client? inner})
    : headers = Map<String, String>.unmodifiable(headers),
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
