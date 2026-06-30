import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:workout_tracker/google_sheets.dart';

import 'google_account_session.dart';
import 'google_authorization_client.dart';

typedef WorkoutTrackerWorkbookInitializerFactory =
    WorkoutTrackerWorkbookInitializer Function(sheets.SheetsApi api);
typedef GooglePickerCallbackReceiverFactory =
    Future<GooglePickerCallbackReceiver> Function({
      required String state,
      required Duration timeout,
    });

const workoutTrackerGooglePickerClientId =
    '657151291920-la859t7i7i8b0kjs1f4cn6c09kd72376.apps.googleusercontent.com';
const workoutTrackerGooglePickerCallbackTimeout = Duration(minutes: 5);
const workoutTrackerGooglePickerNativeCallbackScheme = 'workouttracker';
const workoutTrackerGooglePickerNativeCallbackHost = 'google-picker-callback';
final workoutTrackerGooglePickerHostedCallbackUri = Uri.parse(
  'https://workouttracker-16285.firebaseapp.com/google-picker-callback/',
);
const _googlePickerCallbackStateBytes = 16;
const _googlePickerPickedIdQueryParameters = [
  'picked_file_ids',
  'picked_file_id',
  'picked_folder_ids',
  'picked_folder_id',
  'file_ids',
  'file_id',
  'folder_ids',
  'folder_id',
  'ids',
  'id',
];
final _googlePickerSpreadsheetIdPattern = RegExp(r'^[A-Za-z0-9_-]+$');

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

abstract interface class SpreadsheetPicker {
  SpreadsheetPickerAvailability get availability;

  Future<SelectedSpreadsheet?> chooseSpreadsheet();

  Future<SelectedSpreadsheet?> createSpreadsheet({String? name});
}

abstract interface class SpreadsheetCreationAuthorizer {
  Future<bool> authorizeSpreadsheetCreation();
}

abstract interface class GoogleSpreadsheetCreator {
  Future<SelectedSpreadsheet> createWorkoutSpreadsheet({String? name});
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
  Future<SelectedSpreadsheet?> createSpreadsheet({String? name}) async {
    throw StateError(reason);
  }
}

class MobileGoogleDriveSpreadsheetPicker
    implements
        SpreadsheetPicker,
        SpreadsheetCreationAuthorizer,
        SelectedSpreadsheetResolver {
  const MobileGoogleDriveSpreadsheetPicker({
    required this.callbackReceiverFactory,
    this.clientId = workoutTrackerGooglePickerClientId,
    this.callbackTimeout = workoutTrackerGooglePickerCallbackTimeout,
    this.authorizationGateway,
    this.authorizationClientFactory,
    this.spreadsheetCreator,
  });

  final String clientId;
  final Duration callbackTimeout;
  final GooglePickerCallbackReceiverFactory callbackReceiverFactory;
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
    final callbackReceiver = await callbackReceiverFactory(
      state: callbackState,
      timeout: callbackTimeout,
    );
    try {
      final authorizationUrl = googlePickerAuthorizationUrl(
        clientId: trimmedClientId,
        redirectUri: callbackReceiver.redirectUri,
        state: callbackState,
        loginHint: authorizationGateway?.currentAccount?.email,
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
      _updateGooglePickerAuthorization(result);
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
  Future<SelectedSpreadsheet?> createSpreadsheet({String? name}) async {
    final creator = spreadsheetCreator;
    if (creator == null) {
      throw StateError('Google Drive sheet creation is not connected yet.');
    }
    return creator.createWorkoutSpreadsheet(name: name);
  }

  @override
  Future<bool> authorizeSpreadsheetCreation() async {
    final trimmedClientId = clientId.trim();
    if (trimmedClientId.isEmpty) {
      throw StateError('Google Drive Picker is missing an OAuth client ID.');
    }

    final callbackState = _newGooglePickerCallbackState();
    final callbackReceiver = await callbackReceiverFactory(
      state: callbackState,
      timeout: callbackTimeout,
    );
    try {
      final authorizationUrl = googlePickerAuthorizationUrl(
        clientId: trimmedClientId,
        redirectUri: callbackReceiver.redirectUri,
        state: callbackState,
        loginHint: authorizationGateway?.currentAccount?.email,
        mimetypes: 'application/vnd.google-apps.folder',
        allowFolderSelection: true,
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
        return false;
      }
      final accessToken = result.accessToken;
      if (accessToken == null || accessToken.trim().isEmpty) {
        throw StateError('Google Drive Picker did not return authorization.');
      }
      _updateGooglePickerAuthorization(result);
      return true;
    } finally {
      await callbackReceiver.close();
    }
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
    String? loginHint,
    String mimetypes = 'application/vnd.google-apps.spreadsheet',
    bool allowFolderSelection = false,
  }) {
    final queryParameters = {
      'client_id': clientId,
      'redirect_uri': redirectUri.toString(),
      'response_type': 'token',
      'state': state,
      'scope': 'https://www.googleapis.com/auth/drive.file',
      'prompt': 'consent',
      'trigger_onepick': 'true',
      'allow_multiple': 'false',
      'mimetypes': mimetypes,
    };
    if (allowFolderSelection) {
      queryParameters['allow_folder_selection'] = 'true';
    }
    final trimmedLoginHint = loginHint?.trim();
    if (trimmedLoginHint != null && trimmedLoginHint.isNotEmpty) {
      queryParameters['login_hint'] = trimmedLoginHint;
    }
    return Uri.https(
      'accounts.google.com',
      '/o/oauth2/v2/auth',
      queryParameters,
    );
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
      await _restoreAccountProfileFromDrive(
        authorizationGateway: authorizationGateway,
        client: client,
      );
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

  void _updateGooglePickerAuthorization(GooglePickerCallbackResult result) {
    final authorizationGateway = this.authorizationGateway;
    if (authorizationGateway case final GooglePickerAuthorizationStore store) {
      final accessToken = result.accessToken?.trim();
      if (accessToken == null || accessToken.isEmpty) {
        return;
      }
      store.updateGooglePickerAuthorization(
        GooglePickerAuthorizationSnapshot(
          accessToken: accessToken,
          accountEmail: result.accountEmail,
          displayName: result.accountName,
          photoUrl: result.accountPhotoUrl,
        ),
      );
    }
  }

  Future<void> _restoreAccountProfileFromDrive({
    required GoogleSignInAuthorizationGateway authorizationGateway,
    required http.Client client,
  }) async {
    if (authorizationGateway case final GooglePickerAuthorizationStore store) {
      final current = store.currentAuthorization;
      if (current == null || current.accountEmail?.trim().isNotEmpty == true) {
        return;
      }
      try {
        final about = await drive.DriveApi(
          client,
        ).about.get($fields: 'user(emailAddress,displayName,photoLink)');
        final user = about.user;
        final email = user?.emailAddress?.trim();
        if (email == null || email.isEmpty) {
          return;
        }
        store.updateGooglePickerAuthorization(
          GooglePickerAuthorizationSnapshot(
            accessToken: current.accessToken,
            accountEmail: email,
            displayName: user?.displayName,
            photoUrl: user?.photoLink,
          ),
        );
      } on Object {
        // Account display is best-effort; selected-sheet validation still owns
        // the user-visible success or failure for this flow.
      }
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
       titleFactory = titleFactory ?? defaultWorkoutSpreadsheetTitle;

  final GoogleSignInAuthorizationGateway authorizationGateway;
  final GoogleAuthorizationClientFactory authorizationClientFactory;
  final WorkoutTrackerWorkbookInitializerFactory workbookInitializerFactory;
  final String Function() titleFactory;

  @override
  Future<SelectedSpreadsheet> createWorkoutSpreadsheet({String? name}) async {
    final requestedTitle = (name ?? titleFactory()).trim();
    final title = requestedTitle.isEmpty
        ? defaultWorkoutSpreadsheetTitle()
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
}

String defaultWorkoutSpreadsheetTitle() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return 'WorkoutTracker ${now.year}-$month-$day';
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

abstract interface class GooglePickerCallbackReceiver {
  Uri get redirectUri;

  Future<GooglePickerCallbackResult> get result;

  Future<void> close();
}

final class NativeGooglePickerCallbackReceiver
    implements GooglePickerCallbackReceiver {
  NativeGooglePickerCallbackReceiver({
    required this.state,
    required Duration timeout,
    required Stream<Uri> uriLinkStream,
  }) : _completion = Completer<GooglePickerCallbackResult>() {
    _subscription = uriLinkStream.listen(_handleUri);
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

  final String state;
  final Completer<GooglePickerCallbackResult> _completion;
  late final StreamSubscription<Uri> _subscription;
  late final Timer _timeout;

  @override
  Uri get redirectUri => workoutTrackerGooglePickerHostedCallbackUri;

  @override
  Future<GooglePickerCallbackResult> get result => _completion.future;

  @override
  Future<void> close() async {
    _timeout.cancel();
    await _subscription.cancel();
  }

  void _handleUri(Uri uri) {
    if (!_isGooglePickerNativeCallbackUri(uri) || _completion.isCompleted) {
      return;
    }

    final validation = validateGooglePickerNativeCallback(
      uri,
      expectedState: state,
    );
    final result = validation.result;
    if (result == null) {
      _completion.completeError(
        StateError('Google Drive Picker failed: ${validation.errorMessage}.'),
      );
    } else if (result.error != null && !result.cancelled) {
      _completion.completeError(
        StateError('Google Drive Picker failed: ${result.error}.'),
      );
    } else {
      _completion.complete(result);
    }
  }
}

bool _isGooglePickerNativeCallbackUri(Uri uri) {
  return uri.scheme == workoutTrackerGooglePickerNativeCallbackScheme &&
      uri.host == workoutTrackerGooglePickerNativeCallbackHost &&
      (uri.path.isEmpty || uri.path == '/');
}

final class GooglePickerNativeCallbackValidation {
  const GooglePickerNativeCallbackValidation.accepted(this.result)
    : errorMessage = null;

  const GooglePickerNativeCallbackValidation.rejected({
    required this.errorMessage,
  }) : result = null;

  final GooglePickerCallbackResult? result;
  final String? errorMessage;
}

GooglePickerNativeCallbackValidation validateGooglePickerNativeCallback(
  Uri callbackUri, {
  required String expectedState,
}) {
  if (callbackUri.scheme != workoutTrackerGooglePickerNativeCallbackScheme ||
      callbackUri.host != workoutTrackerGooglePickerNativeCallbackHost ||
      (callbackUri.path.isNotEmpty && callbackUri.path != '/')) {
    return const GooglePickerNativeCallbackValidation.rejected(
      errorMessage:
          'Unexpected Google Drive Picker callback URL; expected '
          'workouttracker://google-picker-callback.',
    );
  }

  final returnedState = callbackUri.queryParameters['state'];
  if (returnedState == null || returnedState.isEmpty) {
    return const GooglePickerNativeCallbackValidation.rejected(
      errorMessage: 'Google Drive Picker callback is missing request state.',
    );
  }
  if (returnedState != expectedState) {
    return const GooglePickerNativeCallbackValidation.rejected(
      errorMessage:
          'Google Drive Picker callback state did not match the active request.',
    );
  }

  final error = callbackUri.queryParameters['error'];
  if (error != null && error.isNotEmpty) {
    return GooglePickerNativeCallbackValidation.accepted(
      GooglePickerCallbackResult(pickedSpreadsheetIds: const [], error: error),
    );
  }

  final pickedSpreadsheetIds = _pickedSpreadsheetIds(
    callbackUri.queryParameters,
  );
  if (pickedSpreadsheetIds == null || pickedSpreadsheetIds.isEmpty) {
    return const GooglePickerNativeCallbackValidation.rejected(
      errorMessage:
          'Google Drive Picker callback is missing valid spreadsheet IDs.',
    );
  }

  return GooglePickerNativeCallbackValidation.accepted(
    GooglePickerCallbackResult(
      pickedSpreadsheetIds: pickedSpreadsheetIds,
      accessToken: _nonEmptyQueryParameter(callbackUri, 'access_token'),
      accountEmail: _nonEmptyQueryParameter(callbackUri, 'account_email'),
      accountName: _nonEmptyQueryParameter(callbackUri, 'account_name'),
      accountPhotoUrl: _nonEmptyQueryParameter(callbackUri, 'account_photo'),
    ),
  );
}

List<String>? _pickedSpreadsheetIds(Map<String, String> queryParameters) {
  String? pickedFileIds;
  for (final key in _googlePickerPickedIdQueryParameters) {
    if (queryParameters.containsKey(key)) {
      pickedFileIds = queryParameters[key];
      break;
    }
  }
  if (pickedFileIds == null) {
    return null;
  }
  final ids = pickedFileIds
      .split(',')
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  if (ids.any((id) => !_googlePickerSpreadsheetIdPattern.hasMatch(id))) {
    return null;
  }
  return ids;
}

String? _nonEmptyQueryParameter(Uri uri, String key) {
  final value = uri.queryParameters[key]?.trim();
  return value == null || value.isEmpty ? null : value;
}

@visibleForTesting
class GooglePickerCallbackResult {
  const GooglePickerCallbackResult({
    required this.pickedSpreadsheetIds,
    this.accessToken,
    this.accountEmail,
    this.accountName,
    this.accountPhotoUrl,
    this.error,
  });

  final List<String> pickedSpreadsheetIds;
  final String? accessToken;
  final String? accountEmail;
  final String? accountName;
  final String? accountPhotoUrl;
  final String? error;

  bool get cancelled => error == 'access_denied';
}
