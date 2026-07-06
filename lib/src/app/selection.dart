import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:url_launcher/url_launcher.dart';
import 'package:workout_tracker/sheets.dart';

import 'account_session.dart';
import 'auth_client.dart';

typedef WbkInitFact = WbkInit Function(sheets.SheetsApi api);
typedef CbReceiverFact =
    Future<PickerCbReceiver> Function({
      required String state,
      required Duration timeout,
    });

const defaultPickerCfgAsset = 'assets/google_picker/app_config.json';
const _callbackStBytes = 16;
final _sheetIdPattern = RegExp(r'^[A-Za-z0-9_-]+$');

class PickerAppCfg {
  PickerAppCfg({
    required this.clientId,
    required this.callbackTimeout,
    required this.nativeCallbackScheme,
    required this.nativeCallbackHost,
    required this.hostedCallbackUri,
    required Iterable<String> pickedIdQueryParameters,
  }) : pickedIdQueryParameters = List<String>.unmodifiable(
         pickedIdQueryParameters,
       );

  final String clientId;
  final Duration callbackTimeout;
  final String nativeCallbackScheme;
  final String nativeCallbackHost;
  final Uri hostedCallbackUri;
  final List<String> pickedIdQueryParameters;

  factory PickerAppCfg.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Google Picker config must be an object.');
    }
    return PickerAppCfg(
      clientId: _requiredConfigString(value, 'clientId'),
      callbackTimeout: Duration(
        seconds: _requiredInt(value, 'callbackTimeoutSeconds'),
      ),
      nativeCallbackScheme: _requiredConfigString(
        value,
        'nativeCallbackScheme',
      ),
      nativeCallbackHost: _requiredConfigString(value, 'nativeCallbackHost'),
      hostedCallbackUri: Uri.parse(
        _requiredConfigString(value, 'hostedCallbackUri'),
      ),
      pickedIdQueryParameters: _requiredStrings(
        value,
        'pickedIdQueryParameters',
      ),
    );
  }
}

String _requiredConfigString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('Google Picker config "$key" must be a string.');
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int && value > 0) {
    return value;
  }
  throw FormatException('Google Picker config "$key" must be a positive int.');
}

List<String> _requiredStrings(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is List<Object?>) {
    final strings = [
      for (final item in value)
        if (item is String && item.trim().isNotEmpty) item,
    ];
    if (strings.length == value.length && strings.isNotEmpty) {
      return strings;
    }
  }
  throw FormatException(
    'Google Picker config "$key" must be a non-empty string list.',
  );
}

Future<PickerAppCfg> loadPickerAppCfg({
  AssetBundle? bundle,
  String assetPath = defaultPickerCfgAsset,
}) async {
  final rawJson = await (bundle ?? rootBundle).loadString(assetPath);
  return PickerAppCfg.fromJson(jsonDecode(rawJson));
}

class SelectedSheet {
  const SelectedSheet({
    required String spreadsheetId,
    required this.name,
    this.drivePath,
    this.webViewLink,
    this.accountEmail,
  }) : id = spreadsheetId;

  final String id;
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
    return trimmedName.isEmpty ? id : trimmedName;
  }

  Map<String, Object?> toJson() {
    return {
      'spreadsheetId': id,
      'name': name,
      if (drivePath != null) 'drivePath': drivePath,
      if (webViewLink != null) 'webViewLink': webViewLink,
      if (accountEmail != null) 'accountEmail': accountEmail,
    };
  }

  static SelectedSheet? fromJson(Object? value) {
    if (value case <String, Object?>{
      'spreadsheetId': final String spreadsheetId,
      'name': final String name,
    }) {
      return SelectedSheet(
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

abstract interface class SheetPicker {
  PickerAvail get availability;

  Future<SelectedSheet?> chooseSheet();

  Future<bool> authorizeSheetCreation();

  Future<SelectedSheet?> createSheet({String? name});

  Future<SelectedSheet> resolveSelection(SelectedSheet selected);
}

class PickerAvail {
  const PickerAvail.available() : chooseReason = null, createReason = null;

  const PickerAvail.unavailable({this.chooseReason, this.createReason});

  final String? chooseReason;
  final String? createReason;

  bool get canChoose => chooseReason == null;

  bool get canCreate => createReason == null;

  String? get summary {
    final reasons = {
      if (chooseReason case final String reason) reason,
      if (createReason case final String reason) reason,
    };
    return reasons.isEmpty ? null : reasons.join(' ');
  }
}

class DisabledPicker implements SheetPicker {
  const DisabledPicker({
    this.reason =
        'Google Drive sheet selection is temporarily disabled for this build.',
  });

  final String reason;

  @override
  PickerAvail get availability {
    return PickerAvail.unavailable(chooseReason: reason, createReason: reason);
  }

  @override
  Future<SelectedSheet?> chooseSheet() async {
    throw StateError(reason);
  }

  @override
  Future<bool> authorizeSheetCreation() async {
    throw StateError(reason);
  }

  @override
  Future<SelectedSheet?> createSheet({String? name}) async {
    throw StateError(reason);
  }

  @override
  Future<SelectedSheet> resolveSelection(SelectedSheet selected) async {
    return selected;
  }
}

class MobileSheetPicker implements SheetPicker {
  const MobileSheetPicker({
    required this.callbackFactory,
    required this.config,
    this.auth,
    this.authClientFactory,
    this.googleAccess,
    this.sheetCreator,
  });

  final PickerAppCfg config;
  final CbReceiverFact callbackFactory;
  final SignInAuthGateway? auth;
  final AuthClientFact? authClientFactory;
  final ApiAccess? googleAccess;
  final SheetCreator? sheetCreator;

  @override
  PickerAvail get availability {
    final trimmedClientId = config.clientId.trim();
    return PickerAvail.unavailable(
      chooseReason: trimmedClientId.isEmpty
          ? 'Google Drive Picker is missing an OAuth client ID.'
          : null,
      createReason: sheetCreator == null
          ? 'Google Drive sheet creation is not connected yet.'
          : null,
    );
  }

  @override
  Future<SelectedSheet?> chooseSheet() async {
    final trimmedClientId = config.clientId.trim();
    if (trimmedClientId.isEmpty) {
      throw StateError('Google Drive Picker is missing an OAuth client ID.');
    }

    final callbackSt = _newPickerCbSt();
    final callbackReceiver = await callbackFactory(
      state: callbackSt,
      timeout: config.callbackTimeout,
    );
    try {
      final authorizationUrl = pickerAuthorizationUrl(
        clientId: trimmedClientId,
        redirectUri: callbackReceiver.redirectUri,
        state: callbackSt,
        loginHint: auth?.currentAccount?.email,
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
      _updatePickerAuth(result);
      final spreadsheetId = result.pickedSheetIds.firstOrNull;
      if (spreadsheetId == null) {
        return null;
      }
      return _pickedSheet(spreadsheetId);
    } finally {
      await callbackReceiver.close();
    }
  }

  @override
  Future<SelectedSheet?> createSheet({String? name}) async {
    final creator = sheetCreator;
    if (creator == null) {
      throw StateError('Google Drive sheet creation is not connected yet.');
    }
    return creator.createSheet(name: name);
  }

  @override
  Future<bool> authorizeSheetCreation() async {
    final trimmedClientId = config.clientId.trim();
    if (trimmedClientId.isEmpty) {
      throw StateError('Google Drive Picker is missing an OAuth client ID.');
    }

    final callbackSt = _newPickerCbSt();
    final callbackReceiver = await callbackFactory(
      state: callbackSt,
      timeout: config.callbackTimeout,
    );
    try {
      final authorizationUrl = pickerAuthorizationUrl(
        clientId: trimmedClientId,
        redirectUri: callbackReceiver.redirectUri,
        state: callbackSt,
        loginHint: auth?.currentAccount?.email,
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
      _updatePickerAuth(result);
      return true;
    } finally {
      await callbackReceiver.close();
    }
  }

  @override
  Future<SelectedSheet> resolveSelection(SelectedSheet selected) {
    return _pickedSheet(selected.id);
  }

  @visibleForTesting
  static Uri pickerAuthorizationUrl({
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

  Future<SelectedSheet> _pickedSheet(String spreadsheetId) async {
    final auth = this.auth;
    if (auth == null) {
      return SelectedSheet(
        spreadsheetId: spreadsheetId,
        name: spreadsheetId,
        webViewLink: sheetUrl(spreadsheetId),
      );
    }

    final access =
        googleAccess ??
        ScopedApiAccess(auth: auth, authClientFactory: authClientFactory);
    return access.run(
      scopes: GoogleApisWbkClient.writeScopes,
      action: (resources) async {
        await _restoreProfile(auth: auth, driveApi: resources.driveApi);
        final spreadsheet = await resources.sheetsApi.spreadsheets.get(
          spreadsheetId,
          includeGridData: false,
          $fields: 'spreadsheetId,spreadsheetUrl,properties/title',
        );
        final title = spreadsheet.properties?.title?.trim();
        return SelectedSheet(
          spreadsheetId: spreadsheetId,
          name: title == null || title.isEmpty ? spreadsheetId : title,
          webViewLink: spreadsheet.spreadsheetUrl ?? sheetUrl(spreadsheetId),
          accountEmail: auth.currentAccount?.email,
        );
      },
    );
  }

  void _updatePickerAuth(PickerCbResult result) {
    final auth = this.auth;
    if (auth case final PickerAuthStore store) {
      final accessToken = result.accessToken?.trim();
      if (accessToken == null || accessToken.isEmpty) {
        return;
      }
      store.updatePickerAuth(
        PickerAuth(
          accessToken: accessToken,
          accountEmail: result.accountEmail,
          displayName: result.accountName,
          photoUrl: result.accountPhotoUrl,
        ),
      );
    }
  }

  Future<void> _restoreProfile({
    required SignInAuthGateway auth,
    required drive.DriveApi driveApi,
  }) async {
    if (auth case final PickerAuthStore store) {
      final current = store.currentAuthorization;
      if (current == null || current.accountEmail?.trim().isNotEmpty == true) {
        return;
      }
      try {
        final about = await driveApi.about.get(
          $fields: 'user(emailAddress,displayName,photoLink)',
        );
        final user = about.user;
        final email = user?.emailAddress?.trim();
        if (email == null || email.isEmpty) {
          return;
        }
        store.updatePickerAuth(
          PickerAuth(
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

class SheetCreator {
  SheetCreator({
    required this.auth,
    AuthClientFact? authClientFactory,
    ApiAccess? googleAccess,
    WbkInitFact? initFactory,
    String Function()? titleFactory,
  }) : googleAccess =
           googleAccess ??
           ScopedApiAccess(auth: auth, authClientFactory: authClientFactory),
       initFactory = initFactory ?? ((api) => GoogleApisWbkInit(api)),
       titleFactory = titleFactory ?? defaultSheetTitle;

  final SignInAuthGateway auth;
  final ApiAccess googleAccess;
  final WbkInitFact initFactory;
  final String Function() titleFactory;

  Future<SelectedSheet> createSheet({String? name}) async {
    final requestedTitle = (name ?? titleFactory()).trim();
    final title = requestedTitle.isEmpty ? defaultSheetTitle() : requestedTitle;
    return googleAccess.run(
      scopes: GoogleApisWbkInit.writeScopes,
      action: (resources) async {
        final created = await resources.sheetsApi.spreadsheets.create(
          sheets.Spreadsheet(
            properties: sheets.SpreadsheetProperties(title: title),
          ),
          $fields: 'spreadsheetId,spreadsheetUrl,properties/title',
        );
        final spreadsheetId = created.spreadsheetId;
        if (spreadsheetId == null || spreadsheetId.trim().isEmpty) {
          throw StateError('Google Sheets did not return a spreadsheet ID.');
        }

        final workbook = await loadWbkTmpl();
        await initFactory(
          resources.sheetsApi,
        ).initializeWorkbook(spreadsheetId: spreadsheetId, workbook: workbook);

        return SelectedSheet(
          spreadsheetId: spreadsheetId,
          name: created.properties?.title ?? title,
          webViewLink: created.spreadsheetUrl ?? sheetUrl(spreadsheetId),
          accountEmail: auth.currentAccount?.email,
        );
      },
    );
  }
}

String defaultSheetTitle() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return 'WorkoutTracker ${now.year}-$month-$day';
}

String sheetUrl(String spreadsheetId) {
  return 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit';
}

String _newPickerCbSt() {
  final random = Random.secure();
  final bytes = List<int>.generate(
    _callbackStBytes,
    (_) => random.nextInt(256),
    growable: false,
  );
  return base64UrlEncode(bytes).replaceAll('=', '');
}

abstract interface class PickerCbReceiver {
  Uri get redirectUri;

  Future<PickerCbResult> get result;

  Future<void> close();
}

final class NativeCbReceiver implements PickerCbReceiver {
  NativeCbReceiver({
    required this.state,
    required this.config,
    required Duration timeout,
    required Stream<Uri> uriLinkStream,
  }) : _completion = Completer<PickerCbResult>() {
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
  final PickerAppCfg config;
  final Completer<PickerCbResult> _completion;
  late final StreamSubscription<Uri> _subscription;
  late final Timer _timeout;

  @override
  Uri get redirectUri => config.hostedCallbackUri;

  @override
  Future<PickerCbResult> get result => _completion.future;

  @override
  Future<void> close() async {
    _timeout.cancel();
    await _subscription.cancel();
  }

  void _handleUri(Uri uri) {
    if (!_isNativeCallbackUri(uri, config) || _completion.isCompleted) {
      return;
    }

    final validation = validatePickerCb(uri, expectedSt: state, config: config);
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

bool _isNativeCallbackUri(Uri uri, PickerAppCfg config) {
  return uri.scheme == config.nativeCallbackScheme &&
      uri.host == config.nativeCallbackHost &&
      (uri.path.isEmpty || uri.path == '/');
}

final class PickerCbVal {
  const PickerCbVal.accepted(this.result) : errorMessage = null;

  const PickerCbVal.rejected({required this.errorMessage}) : result = null;

  final PickerCbResult? result;
  final String? errorMessage;
}

PickerCbVal validatePickerCb(
  Uri callbackUri, {
  required String expectedSt,
  required PickerAppCfg config,
}) {
  if (callbackUri.scheme != config.nativeCallbackScheme ||
      callbackUri.host != config.nativeCallbackHost ||
      (callbackUri.path.isNotEmpty && callbackUri.path != '/')) {
    return PickerCbVal.rejected(
      errorMessage:
          'Unexpected Google Drive Picker callback URL; expected '
          '${config.nativeCallbackScheme}://${config.nativeCallbackHost}.',
    );
  }

  final returnedSt = callbackUri.queryParameters['state'];
  if (returnedSt == null || returnedSt.isEmpty) {
    return const PickerCbVal.rejected(
      errorMessage: 'Google Drive Picker callback is missing request state.',
    );
  }
  if (returnedSt != expectedSt) {
    return const PickerCbVal.rejected(
      errorMessage:
          'Google Drive Picker callback state did not match the active request.',
    );
  }

  final error = callbackUri.queryParameters['error'];
  if (error != null && error.isNotEmpty) {
    return PickerCbVal.accepted(
      PickerCbResult(pickedSheetIds: const [], error: error),
    );
  }

  final pickedSheetIds = _pickedSheetIds(callbackUri.queryParameters, config);
  if (pickedSheetIds == null || pickedSheetIds.isEmpty) {
    return const PickerCbVal.rejected(
      errorMessage:
          'Google Drive Picker callback is missing valid spreadsheet IDs.',
    );
  }

  return PickerCbVal.accepted(
    PickerCbResult(
      pickedSheetIds: pickedSheetIds,
      accessToken: _nonEmptyQueryParameter(callbackUri, 'access_token'),
      accountEmail: _nonEmptyQueryParameter(callbackUri, 'account_email'),
      accountName: _nonEmptyQueryParameter(callbackUri, 'account_name'),
      accountPhotoUrl: _nonEmptyQueryParameter(callbackUri, 'account_photo'),
    ),
  );
}

List<String>? _pickedSheetIds(
  Map<String, String> queryParameters,
  PickerAppCfg config,
) {
  String? pickedFileIds;
  for (final key in config.pickedIdQueryParameters) {
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
  if (ids.any((id) => !_sheetIdPattern.hasMatch(id))) {
    return null;
  }
  return ids;
}

String? _nonEmptyQueryParameter(Uri uri, String key) {
  final value = uri.queryParameters[key]?.trim();
  return value == null || value.isEmpty ? null : value;
}

@visibleForTesting
class PickerCbResult {
  const PickerCbResult({
    required this.pickedSheetIds,
    this.accessToken,
    this.accountEmail,
    this.accountName,
    this.accountPhotoUrl,
    this.error,
  });

  final List<String> pickedSheetIds;
  final String? accessToken;
  final String? accountEmail;
  final String? accountName;
  final String? accountPhotoUrl;
  final String? error;

  bool get cancelled => error == 'access_denied';
}
