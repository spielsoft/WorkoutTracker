import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:url_launcher/url_launcher.dart';
import 'package:workout_tracker/google_sheets.dart';

import 'google_account_session.dart';
import 'google_authorization_client.dart';

typedef WorkoutTrackerWorkbookInitializerFactory =
    WorkoutTrackerWorkbookInitializer Function(sheets.SheetsApi api);

const workoutTrackerGooglePickerClientIdDartDefine =
    'WORKOUT_TRACKER_GOOGLE_PICKER_CLIENT_ID';
const workoutTrackerGooglePickerClientId = String.fromEnvironment(
  workoutTrackerGooglePickerClientIdDartDefine,
);
const workoutTrackerGooglePickerCallbackTimeout = Duration(minutes: 5);
const _googlePickerCallbackPath = '/google-picker-callback';
const _googlePickerCallbackStateBytes = 16;

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

abstract interface class GoogleSpreadsheetCreator {
  Future<SelectedSpreadsheet> createWorkoutSpreadsheet();
}

abstract interface class SelectedSpreadsheetResolver {
  Future<SelectedSpreadsheet> resolveSelectedSpreadsheet(
    SelectedSpreadsheet selected,
  );
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

class MobileGoogleDriveSpreadsheetPicker
    implements SpreadsheetPicker, SelectedSpreadsheetResolver {
  const MobileGoogleDriveSpreadsheetPicker({
    this.clientId = workoutTrackerGooglePickerClientId,
    this.callbackTimeout = workoutTrackerGooglePickerCallbackTimeout,
    this.authorizationGateway,
    this.authorizationClientFactory,
    this.spreadsheetCreator,
  });

  final String clientId;
  final Duration callbackTimeout;
  final GoogleSignInAuthorizationGateway? authorizationGateway;
  final GoogleAuthorizationClientFactory? authorizationClientFactory;
  final GoogleSpreadsheetCreator? spreadsheetCreator;

  @override
  SpreadsheetPickerAvailability get availability {
    final trimmedClientId = clientId.trim();
    return SpreadsheetPickerAvailability.unavailable(
      chooseUnavailableReason: trimmedClientId.isEmpty
          ? 'Google Drive Picker is missing an OAuth client ID.'
          : null,
      createUnavailableReason: spreadsheetCreator == null
          ? 'Google Drive sheet creation is not connected yet.'
          : null,
    );
  }

  @override
  Future<SelectedSpreadsheet?> chooseSpreadsheet() async {
    final trimmedClientId = clientId.trim();
    if (trimmedClientId.isEmpty) {
      throw StateError('Google Drive Picker is missing an OAuth client ID.');
    }

    final callbackState = _newGooglePickerCallbackState();
    final callbackReceiver = await _LoopbackGooglePickerCallbackReceiver.bind(
      timeout: callbackTimeout,
      state: callbackState,
    );
    try {
      final authorizationUrl = googlePickerAuthorizationUrl(
        clientId: trimmedClientId,
        redirectUri: callbackReceiver.redirectUri,
        state: callbackState,
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
      return _selectedSpreadsheetForPickedId(spreadsheetId);
    } finally {
      await callbackReceiver.close();
    }
  }

  @override
  Future<SelectedSpreadsheet?> createSpreadsheet() async {
    final creator = spreadsheetCreator;
    if (creator == null) {
      throw StateError('Google Drive sheet creation is not connected yet.');
    }
    return creator.createWorkoutSpreadsheet();
  }

  @override
  Future<SelectedSpreadsheet> resolveSelectedSpreadsheet(
    SelectedSpreadsheet selected,
  ) {
    return _selectedSpreadsheetForPickedId(selected.spreadsheetId);
  }

  @visibleForTesting
  static Uri googlePickerAuthorizationUrl({
    required String clientId,
    required Uri redirectUri,
    required String state,
  }) {
    return Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri.toString(),
      'response_type': 'code',
      'state': state,
      'scope': 'https://www.googleapis.com/auth/drive.file',
      'trigger_onepick': 'true',
      'allow_multiple': 'false',
      'mimetypes': 'application/vnd.google-apps.spreadsheet',
    });
  }

  Future<SelectedSpreadsheet> _selectedSpreadsheetForPickedId(
    String spreadsheetId,
  ) async {
    final authorizationGateway = this.authorizationGateway;
    if (authorizationGateway == null) {
      return SelectedSpreadsheet(
        spreadsheetId: spreadsheetId,
        name: spreadsheetId,
        webViewLink: googleSheetsUrl(spreadsheetId),
      );
    }

    final headers = await authorizationGateway.authorizationHeaders(
      GoogleApisSheetsWriteClient.writeScopes,
    );
    final clientFactory =
        authorizationClientFactory ??
        ((headers) => GoogleAuthorizationHeadersClient(headers: headers));
    final client = clientFactory(headers);
    try {
      final api = sheets.SheetsApi(client);
      final spreadsheet = await api.spreadsheets.get(
        spreadsheetId,
        includeGridData: false,
        $fields: 'spreadsheetId,spreadsheetUrl,properties/title',
      );
      final title = spreadsheet.properties?.title?.trim();
      return SelectedSpreadsheet(
        spreadsheetId: spreadsheetId,
        name: title == null || title.isEmpty ? spreadsheetId : title,
        webViewLink:
            spreadsheet.spreadsheetUrl ?? googleSheetsUrl(spreadsheetId),
        accountEmail: authorizationGateway.currentAccount?.email,
      );
    } finally {
      client.close();
    }
  }
}

class GoogleSheetsSpreadsheetCreator implements GoogleSpreadsheetCreator {
  GoogleSheetsSpreadsheetCreator({
    required this.authorizationGateway,
    GoogleAuthorizationClientFactory? authorizationClientFactory,
    WorkoutTrackerWorkbookInitializerFactory? workbookInitializerFactory,
    String Function()? titleFactory,
  }) : authorizationClientFactory =
           authorizationClientFactory ??
           ((headers) => GoogleAuthorizationHeadersClient(headers: headers)),
       workbookInitializerFactory =
           workbookInitializerFactory ??
           ((api) => GoogleApisWorkoutTrackerWorkbookInitializer(api)),
       titleFactory = titleFactory ?? _defaultWorkoutSpreadsheetTitle;

  final GoogleSignInAuthorizationGateway authorizationGateway;
  final GoogleAuthorizationClientFactory authorizationClientFactory;
  final WorkoutTrackerWorkbookInitializerFactory workbookInitializerFactory;
  final String Function() titleFactory;

  @override
  Future<SelectedSpreadsheet> createWorkoutSpreadsheet() async {
    final requestedTitle = titleFactory().trim();
    final title = requestedTitle.isEmpty
        ? _defaultWorkoutSpreadsheetTitle()
        : requestedTitle;
    final headers = await authorizationGateway.authorizationHeaders(
      GoogleApisWorkoutTrackerWorkbookInitializer.writeScopes,
    );
    final client = authorizationClientFactory(headers);
    try {
      final api = sheets.SheetsApi(client);
      final created = await api.spreadsheets.create(
        sheets.Spreadsheet(
          properties: sheets.SpreadsheetProperties(title: title),
        ),
        $fields: 'spreadsheetId,spreadsheetUrl,properties/title',
      );
      final spreadsheetId = created.spreadsheetId;
      if (spreadsheetId == null || spreadsheetId.trim().isEmpty) {
        throw StateError('Google Sheets did not return a spreadsheet ID.');
      }

      await workbookInitializerFactory(api).initializeWorkbook(
        spreadsheetId: spreadsheetId,
        workbook: workoutTrackerWorkbookTemplate(),
      );

      return SelectedSpreadsheet(
        spreadsheetId: spreadsheetId,
        name: created.properties?.title ?? title,
        webViewLink: created.spreadsheetUrl ?? googleSheetsUrl(spreadsheetId),
        accountEmail: authorizationGateway.currentAccount?.email,
      );
    } finally {
      client.close();
    }
  }

  static String _defaultWorkoutSpreadsheetTitle() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return 'WorkoutTracker ${now.year}-$month-$day';
  }
}

String googleSheetsUrl(String spreadsheetId) {
  return 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit';
}

String _newGooglePickerCallbackState() {
  final random = Random.secure();
  final bytes = List<int>.generate(
    _googlePickerCallbackStateBytes,
    (_) => random.nextInt(256),
    growable: false,
  );
  return base64UrlEncode(bytes).replaceAll('=', '');
}

class _LoopbackGooglePickerCallbackReceiver {
  _LoopbackGooglePickerCallbackReceiver._({
    required this._server,
    required this.redirectUri,
    required this._state,
    required Duration timeout,
  }) : _completion = Completer<GooglePickerCallbackResult>() {
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
  final String _state;
  final Completer<GooglePickerCallbackResult> _completion;
  late final StreamSubscription<HttpRequest> _subscription;
  late final Timer _timeout;

  Future<GooglePickerCallbackResult> get result => _completion.future;

  static Future<_LoopbackGooglePickerCallbackReceiver> bind({
    required Duration timeout,
    required String state,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _LoopbackGooglePickerCallbackReceiver._(
      server: server,
      redirectUri: Uri.parse(
        'http://localhost:${server.port}$_googlePickerCallbackPath',
      ),
      state: state,
      timeout: timeout,
    );
  }

  Future<void> close() async {
    _timeout.cancel();
    await _subscription.cancel();
    await _server.close(force: true);
  }

  void _handleRequest(HttpRequest request) {
    final validation = validateGooglePickerLoopbackCallback(
      request.uri,
      expectedState: _state,
    );
    final result = validation.result;
    request.response
      ..statusCode = validation.statusCode
      ..headers.contentType = ContentType.html
      ..write(
        result == null
            ? _callbackErrorHtml(validation.errorMessage!)
            : _callbackHtml(result),
      )
      ..close();

    if (!_completion.isCompleted &&
        request.uri.path == _googlePickerCallbackPath) {
      if (result == null) {
        _completion.completeError(
          StateError('Google Drive Picker failed: ${validation.errorMessage}.'),
        );
      } else if (result.error != null) {
        _completion.completeError(
          StateError('Google Drive Picker failed: ${result.error}.'),
        );
      } else {
        _completion.complete(result);
      }
    }
  }

  String _callbackHtml(GooglePickerCallbackResult result) {
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

  String _callbackErrorHtml(String errorMessage) {
    final escapedError = htmlEscape.convert(errorMessage);
    return '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Picker failed</title>
    <style>
      body {
        color: #202124;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        margin: 48px;
      }
    </style>
  </head>
  <body>
    <h1>Picker failed</h1>
    <p>$escapedError</p>
  </body>
</html>
''';
  }
}

@visibleForTesting
final class GooglePickerLoopbackCallbackValidation {
  const GooglePickerLoopbackCallbackValidation.accepted(this.result)
    : errorMessage = null,
      statusCode = HttpStatus.ok;

  const GooglePickerLoopbackCallbackValidation.rejected({
    required this.errorMessage,
    required this.statusCode,
  }) : result = null;

  final GooglePickerCallbackResult? result;
  final String? errorMessage;
  final int statusCode;
}

@visibleForTesting
GooglePickerLoopbackCallbackValidation validateGooglePickerLoopbackCallback(
  Uri requestUri, {
  required String expectedState,
}) {
  if (requestUri.path != _googlePickerCallbackPath) {
    return GooglePickerLoopbackCallbackValidation.rejected(
      errorMessage:
          'Unexpected Google Drive Picker callback path '
          '${requestUri.path}; expected $_googlePickerCallbackPath.',
      statusCode: HttpStatus.notFound,
    );
  }

  final returnedState = requestUri.queryParameters['state'];
  if (returnedState == null || returnedState.isEmpty) {
    return const GooglePickerLoopbackCallbackValidation.rejected(
      errorMessage: 'Google Drive Picker callback is missing request state.',
      statusCode: HttpStatus.badRequest,
    );
  }
  if (returnedState != expectedState) {
    return const GooglePickerLoopbackCallbackValidation.rejected(
      errorMessage:
          'Google Drive Picker callback state did not match the active request.',
      statusCode: HttpStatus.badRequest,
    );
  }

  return GooglePickerLoopbackCallbackValidation.accepted(
    GooglePickerCallbackResult.fromQueryParameters(requestUri.queryParameters),
  );
}

@visibleForTesting
class GooglePickerCallbackResult {
  const GooglePickerCallbackResult({
    required this.pickedSpreadsheetIds,
    this.error,
  });

  final List<String> pickedSpreadsheetIds;
  final String? error;

  bool get cancelled => error == 'access_denied';

  static GooglePickerCallbackResult fromQueryParameters(
    Map<String, String> queryParameters,
  ) {
    final pickedFileIds = queryParameters['picked_file_ids'] ?? '';
    return GooglePickerCallbackResult(
      pickedSpreadsheetIds: pickedFileIds
          .split(',')
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
      error: queryParameters['error'],
    );
  }
}
