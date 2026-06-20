import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

const workoutTrackerGooglePickerClientIdDartDefine =
    'WORKOUT_TRACKER_GOOGLE_PICKER_CLIENT_ID';
const workoutTrackerGooglePickerClientId = String.fromEnvironment(
  workoutTrackerGooglePickerClientIdDartDefine,
);
const workoutTrackerGooglePickerCallbackTimeout = Duration(minutes: 5);

class SelectedSpreadsheet {
  const SelectedSpreadsheet({
    required this.spreadsheetId,
    required this.name,
    this.drivePath,
    this.webViewLink,
    this.accountEmail,
  });

  final String spreadsheetId;
  final String name;
  final String? drivePath;
  final String? webViewLink;
  final String? accountEmail;

  String get displayLabel {
    final path = drivePath?.trim();
    if (path != null && path.isNotEmpty) {
      return path;
    }
    final trimmedName = name.trim();
    return trimmedName.isEmpty ? spreadsheetId : trimmedName;
  }

  Map<String, Object?> toJson() {
    return {
      'spreadsheetId': spreadsheetId,
      'name': name,
      if (drivePath != null) 'drivePath': drivePath,
      if (webViewLink != null) 'webViewLink': webViewLink,
      if (accountEmail != null) 'accountEmail': accountEmail,
    };
  }

  static SelectedSpreadsheet? fromJson(Object? value) {
    if (value case <String, Object?>{
      'spreadsheetId': final String spreadsheetId,
      'name': final String name,
    }) {
      return SelectedSpreadsheet(
        spreadsheetId: spreadsheetId,
        name: name,
        drivePath: value['drivePath'] as String?,
        webViewLink: value['webViewLink'] as String?,
        accountEmail: value['accountEmail'] as String?,
      );
    }
    return null;
  }
}

String encodeSelectedSpreadsheet(SelectedSpreadsheet selected) {
  return jsonEncode(selected.toJson());
}

SelectedSpreadsheet? decodeSelectedSpreadsheet(String encoded) {
  try {
    return SelectedSpreadsheet.fromJson(jsonDecode(encoded));
  } on Object {
    return null;
  }
}

abstract interface class SpreadsheetPicker {
  SpreadsheetPickerAvailability get availability;

  Future<SelectedSpreadsheet?> chooseSpreadsheet();

  Future<SelectedSpreadsheet?> createSpreadsheet();
}

class SpreadsheetPickerAvailability {
  const SpreadsheetPickerAvailability.available()
    : chooseUnavailableReason = null,
      createUnavailableReason = null;

  const SpreadsheetPickerAvailability.unavailable({
    this.chooseUnavailableReason,
    this.createUnavailableReason,
  });

  final String? chooseUnavailableReason;
  final String? createUnavailableReason;

  bool get canChoose => chooseUnavailableReason == null;

  bool get canCreate => createUnavailableReason == null;

  String? get summary {
    final reasons = {
      if (chooseUnavailableReason case final String reason) reason,
      if (createUnavailableReason case final String reason) reason,
    };
    return reasons.isEmpty ? null : reasons.join(' ');
  }
}

class DisabledSpreadsheetPicker implements SpreadsheetPicker {
  const DisabledSpreadsheetPicker({
    this.reason =
        'Google Drive sheet selection is temporarily disabled for this build.',
  });

  final String reason;

  @override
  SpreadsheetPickerAvailability get availability {
    return SpreadsheetPickerAvailability.unavailable(
      chooseUnavailableReason: reason,
      createUnavailableReason: reason,
    );
  }

  @override
  Future<SelectedSpreadsheet?> chooseSpreadsheet() async {
    throw StateError(reason);
  }

  @override
  Future<SelectedSpreadsheet?> createSpreadsheet() async {
    throw StateError(reason);
  }
}

class MobileGoogleDriveSpreadsheetPicker implements SpreadsheetPicker {
  const MobileGoogleDriveSpreadsheetPicker({
    this.clientId = workoutTrackerGooglePickerClientId,
    this.callbackTimeout = workoutTrackerGooglePickerCallbackTimeout,
  });

  final String clientId;
  final Duration callbackTimeout;

  @override
  SpreadsheetPickerAvailability get availability {
    final trimmedClientId = clientId.trim();
    return SpreadsheetPickerAvailability.unavailable(
      chooseUnavailableReason: trimmedClientId.isEmpty
          ? 'Google Drive Picker is missing an OAuth client ID.'
          : null,
      createUnavailableReason:
          'Google Drive sheet creation is not connected yet.',
    );
  }

  @override
  Future<SelectedSpreadsheet?> chooseSpreadsheet() async {
    final trimmedClientId = clientId.trim();
    if (trimmedClientId.isEmpty) {
      throw StateError('Google Drive Picker is missing an OAuth client ID.');
    }

    final callbackReceiver = await _LoopbackGooglePickerCallbackReceiver.bind(
      timeout: callbackTimeout,
    );
    try {
      final authorizationUrl = _googlePickerAuthorizationUrl(
        clientId: trimmedClientId,
        redirectUri: callbackReceiver.redirectUri,
      );
      final launched = await launchUrl(
        authorizationUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('Unable to open Google Drive Picker.');
      }
      final result = await callbackReceiver.result;
      if (result.cancelled) {
        return null;
      }
      final spreadsheetId = result.pickedSpreadsheetIds.firstOrNull;
      if (spreadsheetId == null) {
        return null;
      }
      return SelectedSpreadsheet(
        spreadsheetId: spreadsheetId,
        name: 'Selected Google Sheet',
        webViewLink: googleSheetsUrl(spreadsheetId),
      );
    } finally {
      await callbackReceiver.close();
    }
  }

  @override
  Future<SelectedSpreadsheet?> createSpreadsheet() async {
    throw StateError('Google Drive sheet creation is not connected yet.');
  }

  static Uri _googlePickerAuthorizationUrl({
    required String clientId,
    required Uri redirectUri,
  }) {
    return Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri.toString(),
      'response_type': 'code',
      'scope': 'https://www.googleapis.com/auth/drive.file',
      'trigger_onepick': 'true',
      'allow_multiple': 'false',
      'mimetypes': 'application/vnd.google-apps.spreadsheet',
    });
  }
}

String googleSheetsUrl(String spreadsheetId) {
  return 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit';
}

class _LoopbackGooglePickerCallbackReceiver {
  _LoopbackGooglePickerCallbackReceiver._({
    required this._server,
    required this.redirectUri,
    required Duration timeout,
  }) : _completion = Completer<_GooglePickerCallbackResult>() {
    _subscription = _server.listen(_handleRequest);
    _timeout = Timer(timeout, () {
      if (!_completion.isCompleted) {
        _completion.completeError(
          TimeoutException(
            'Google Drive Picker did not return before the timeout.',
            timeout,
          ),
        );
      }
    });
  }

  final HttpServer _server;
  final Uri redirectUri;
  final Completer<_GooglePickerCallbackResult> _completion;
  late final StreamSubscription<HttpRequest> _subscription;
  late final Timer _timeout;

  Future<_GooglePickerCallbackResult> get result => _completion.future;

  static Future<_LoopbackGooglePickerCallbackReceiver> bind({
    required Duration timeout,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _LoopbackGooglePickerCallbackReceiver._(
      server: server,
      redirectUri: Uri.parse('http://localhost:${server.port}'),
      timeout: timeout,
    );
  }

  Future<void> close() async {
    _timeout.cancel();
    await _subscription.cancel();
    await _server.close(force: true);
  }

  void _handleRequest(HttpRequest request) {
    final result = _GooglePickerCallbackResult.fromQueryParameters(
      request.uri.queryParameters,
    );
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(_callbackHtml(result))
      ..close();

    if (!_completion.isCompleted) {
      if (result.error != null) {
        _completion.completeError(
          StateError('Google Drive Picker failed: ${result.error}.'),
        );
      } else {
        _completion.complete(result);
      }
    }
  }

  String _callbackHtml(_GooglePickerCallbackResult result) {
    final title = result.error == null ? 'Selection received' : 'Picker failed';
    final body = result.error == null
        ? 'You can return to Workout Tracker.'
        : 'Google Drive Picker returned ${htmlEscape.convert(result.error!)}.';
    return '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>$title</title>
    <style>
      body {
        color: #202124;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        margin: 48px;
      }
    </style>
  </head>
  <body>
    <h1>$title</h1>
    <p>$body</p>
  </body>
</html>
''';
  }
}

class _GooglePickerCallbackResult {
  const _GooglePickerCallbackResult({
    required this.pickedSpreadsheetIds,
    this.error,
  });

  final List<String> pickedSpreadsheetIds;
  final String? error;

  bool get cancelled => error == 'access_denied';

  static _GooglePickerCallbackResult fromQueryParameters(
    Map<String, String> queryParameters,
  ) {
    final pickedFileIds = queryParameters['picked_file_ids'] ?? '';
    return _GooglePickerCallbackResult(
      pickedSpreadsheetIds: pickedFileIds
          .split(',')
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
      error: queryParameters['error'],
    );
  }
}
