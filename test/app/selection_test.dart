import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:workout_tracker/sheets.dart';
import 'package:workout_tracker/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads Google Picker app config from the bundled JSON asset', () async {
    final config = await loadPickerAppCfg();

    expect(config.clientId, isNotEmpty);
    expect(config.callbackTimeout, const Duration(minutes: 5));
    expect(
      config.hostedCallbackUri.toString(),
      'https://workouttracker-16285.firebaseapp.com/google-picker-callback/',
    );
    expect(config.nativeCallbackScheme, 'workouttracker');
    expect(config.nativeCallbackHost, 'google-picker-callback');
  });

  test(
    'disabled spreadsheet picker reports both actions unavailable',
    () async {
      const picker = DisabledPicker(reason: 'Selection disabled.');

      expect(picker.availability.canChoose, isFalse);
      expect(picker.availability.canCreate, isFalse);
      expect(picker.availability.summary, 'Selection disabled.');
      await expectLater(picker.chooseSheet(), throwsA(isA<StateError>()));
      await expectLater(picker.createSheet(), throwsA(isA<StateError>()));
    },
  );

  test('production picker client ID enables app builds', () {
    final config = _testGooglePickerConfig();

    expect(config.clientId, isNotEmpty);
    expect(
      MobileSheetPicker(
        config: config,
        callbackFactory: _unusedCallbackReceiverFactory,
      ).availability.canChoose,
      isTrue,
    );
  });

  test(
    'Google Picker authorization URL carries the app callback path and request state',
    () {
      final config = _testGooglePickerConfig();

      expect(
        config.hostedCallbackUri.toString(),
        'https://workouttracker-16285.firebaseapp.com/google-picker-callback/',
      );

      final authorizationUrl = MobileSheetPicker.pickerAuthorizationUrl(
        clientId: 'client-id.apps.googleusercontent.com',
        redirectUri: config.hostedCallbackUri,
        state: 'request-state',
        loginHint: 'athlete@example.com',
      );

      expect(authorizationUrl.host, 'accounts.google.com');
      expect(
        authorizationUrl.queryParameters['client_id'],
        'client-id.apps.googleusercontent.com',
      );
      expect(
        authorizationUrl.queryParameters['redirect_uri'],
        config.hostedCallbackUri.toString(),
      );
      expect(authorizationUrl.queryParameters['response_type'], 'token');
      expect(authorizationUrl.queryParameters['state'], 'request-state');
      expect(
        authorizationUrl.queryParameters['scope'],
        'https://www.googleapis.com/auth/drive.file',
      );
      expect(authorizationUrl.queryParameters['prompt'], 'consent');
      expect(
        authorizationUrl.queryParameters['include_granted_scopes'],
        isNull,
      );
      expect(authorizationUrl.queryParameters['trigger_onepick'], 'true');
      expect(
        authorizationUrl.queryParameters['mimetypes'],
        'application/vnd.google-apps.spreadsheet',
      );
      expect(
        authorizationUrl.queryParameters['login_hint'],
        'athlete@example.com',
      );
    },
  );

  test(
    'native Google Picker callback parser accepts only app-owned results',
    () {
      final config = _testGooglePickerConfig();

      final success = validatePickerCb(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&picked_file_ids=first_sheet,second-sheet',
        ),
        expectedSt: 'request-state',
        config: config,
      );

      expect(success.result?.pickedSheetIds, ['first_sheet', 'second-sheet']);
      expect(success.errorMessage, isNull);

      final successWithToken = validatePickerCb(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&picked_file_ids=spreadsheet-id'
          '&access_token=oauth-token'
          '&account_email=athlete%40example.com'
          '&account_name=Athlete%20Name'
          '&account_photo=https%3A%2F%2Fexample.com%2Fathlete.png',
        ),
        expectedSt: 'request-state',
        config: config,
      );
      expect(successWithToken.result?.pickedSheetIds, ['spreadsheet-id']);
      expect(successWithToken.result?.accessToken, 'oauth-token');
      expect(successWithToken.result?.accountEmail, 'athlete@example.com');
      expect(successWithToken.result?.accountName, 'Athlete Name');
      expect(
        successWithToken.result?.accountPhotoUrl,
        'https://example.com/athlete.png',
      );

      for (final alias in [
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
      ]) {
        final aliasSuccess = validatePickerCb(
          Uri.parse(
            'workouttracker://google-picker-callback'
            '?state=request-state&$alias=spreadsheet-id',
          ),
          expectedSt: 'request-state',
          config: config,
        );
        expect(
          aliasSuccess.result?.pickedSheetIds,
          ['spreadsheet-id'],
          reason: 'callback ID alias $alias should be accepted',
        );
      }

      final cancelled = validatePickerCb(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&error=access_denied',
        ),
        expectedSt: 'request-state',
        config: config,
      );
      expect(cancelled.result?.cancelled, isTrue);

      final pickerError = validatePickerCb(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&error=server_error',
        ),
        expectedSt: 'request-state',
        config: config,
      );
      expect(pickerError.result?.error, 'server_error');

      final missingSt = validatePickerCb(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?picked_file_ids=spreadsheet-id',
        ),
        expectedSt: 'request-state',
        config: config,
      );
      expect(missingSt.result, isNull);
      expect(missingSt.errorMessage, contains('missing request state'));

      final wrongSt = validatePickerCb(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=other-state&picked_file_ids=spreadsheet-id',
        ),
        expectedSt: 'request-state',
        config: config,
      );
      expect(wrongSt.result, isNull);
      expect(wrongSt.errorMessage, contains('state'));

      final malformedSpreadsheetId = validatePickerCb(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&picked_file_ids=spreadsheet.id',
        ),
        expectedSt: 'request-state',
        config: config,
      );
      expect(malformedSpreadsheetId.result, isNull);
      expect(malformedSpreadsheetId.errorMessage, contains('spreadsheet ID'));

      final tokenWithoutSelection = validatePickerCb(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&access_token=oauth-token',
        ),
        expectedSt: 'request-state',
        config: config,
      );
      expect(tokenWithoutSelection.result, isNull);
      expect(tokenWithoutSelection.errorMessage, contains('spreadsheet IDs'));

      final unrelated = validatePickerCb(
        Uri.parse(
          'com.googleusercontent.apps.client:/oauth2redirect'
          '?state=request-state&picked_file_ids=spreadsheet-id',
        ),
        expectedSt: 'request-state',
        config: config,
      );
      expect(unrelated.result, isNull);
      expect(unrelated.errorMessage, contains('workouttracker'));
    },
  );

  test('native google picker callback scheme is app-owned', () {
    final iosInfoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final macosInfoPlist = File('macos/Runner/Info.plist').readAsStringSync();
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(iosInfoPlist, contains('<string>workouttracker</string>'));
    expect(macosInfoPlist, contains('<string>workouttracker</string>'));
    expect(androidManifest, contains('android:scheme="workouttracker"'));
    expect(
      iosInfoPlist,
      contains(
        '<string>\$(WORKOUT_TRACKER_GOOGLE_REVERSED_CLIENT_ID)</string>',
      ),
    );
    expect(
      macosInfoPlist,
      contains(
        '<string>\$(WORKOUT_TRACKER_GOOGLE_REVERSED_CLIENT_ID)</string>',
      ),
    );
  });

  test(
    'Google Sheets creator runs workbook creation through scoped Sheets access',
    () async {
      final client = _SheetsCreateClient();
      final access = _RecordingScopedGoogleApiAccess(client);
      final initializer = _RecordingWbkInit(client);
      final creator = SheetCreator(
        auth: _UnusedSignInAuthGateway(),
        googleAccess: access,
        initFactory: (_) => initializer,
        titleFactory: () => 'Workout Log',
      );

      final selected = await creator.createSheet();

      expect(access.requestedScopes.single, [
        sheets.SheetsApi.spreadsheetsScope,
      ]);
      expect(initializer.initializedSpreadsheetIds, ['created-spreadsheet-id']);
      expect(initializer.clientWasOpenDuringInitialization, isTrue);
      expect(client.closed, isTrue);
      expect(selected.id, 'created-spreadsheet-id');
      expect(selected.name, 'Workout Log');
    },
  );
}

PickerAppCfg _testGooglePickerConfig() {
  return PickerAppCfg(
    clientId:
        '657151291920-la859t7i7i8b0kjs1f4cn6c09kd72376.apps.googleusercontent.com',
    callbackTimeout: const Duration(minutes: 5),
    nativeCallbackScheme: 'workouttracker',
    nativeCallbackHost: 'google-picker-callback',
    hostedCallbackUri: Uri.parse(
      'https://workouttracker-16285.firebaseapp.com/google-picker-callback/',
    ),
    pickedIdQueryParameters: const [
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
    ],
  );
}

Future<PickerCbReceiver> _unusedCallbackReceiverFactory({
  required String state,
  required Duration timeout,
}) async {
  throw StateError('Spreadsheet picker callback receiver was not expected.');
}

class _RecordingScopedGoogleApiAccess implements ApiAccess {
  _RecordingScopedGoogleApiAccess(this.client);

  final http.Client client;
  final List<List<String>> requestedScopes = [];

  @override
  Future<T> run<T>({
    required List<String> scopes,
    required Future<T> Function(ApiResources resources) action,
  }) async {
    requestedScopes.add(scopes);
    try {
      return await action(ApiResources(client));
    } finally {
      client.close();
    }
  }
}

class _SheetsCreateClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (closed) {
      throw StateError('Client was closed before the Google action finished.');
    }
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'spreadsheetId': 'created-spreadsheet-id',
            'spreadsheetUrl':
                'https://docs.google.com/spreadsheets/d/created-spreadsheet-id/edit',
            'properties': {'title': 'Workout Log'},
          }),
        ),
      ),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }

  @override
  void close() {
    closed = true;
  }
}

class _RecordingWbkInit implements WbkInit {
  _RecordingWbkInit(this.client);

  final _SheetsCreateClient client;
  final List<String> initializedSpreadsheetIds = [];
  bool clientWasOpenDuringInitialization = false;

  @override
  Future<void> initializeWorkbook({
    required String spreadsheetId,
    required Wbk workbook,
  }) async {
    initializedSpreadsheetIds.add(spreadsheetId);
    clientWasOpenDuringInitialization = !client.closed;
  }
}

class _UnusedSignInAuthGateway implements SignInAuthGateway {
  @override
  GoogleAccountProfile? get currentAccount => null;

  @override
  Future<Map<String, String>> authorizationHeaders(List<String> scopes) {
    throw StateError('Creator should use injected scoped access.');
  }

  @override
  Future<void> restoreAccount() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> switchAccount({List<String> scopes = const []}) async {}

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
