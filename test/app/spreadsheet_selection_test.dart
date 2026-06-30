import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads Google Picker app config from the bundled JSON asset', () async {
    final config = await loadGooglePickerAppConfig();

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
      const picker = DisabledSpreadsheetPicker(reason: 'Selection disabled.');

      expect(picker.availability.canChoose, isFalse);
      expect(picker.availability.canCreate, isFalse);
      expect(picker.availability.summary, 'Selection disabled.');
      await expectLater(picker.chooseSpreadsheet(), throwsA(isA<StateError>()));
      await expectLater(picker.createSpreadsheet(), throwsA(isA<StateError>()));
    },
  );

  test('production picker client ID enables app builds', () {
    final config = _testGooglePickerConfig();

    expect(config.clientId, isNotEmpty);
    expect(
      MobileGoogleDriveSpreadsheetPicker(
        config: config,
        callbackReceiverFactory: _unusedCallbackReceiverFactory,
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

      final authorizationUrl =
          MobileGoogleDriveSpreadsheetPicker.googlePickerAuthorizationUrl(
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

      final success = validateGooglePickerNativeCallback(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&picked_file_ids=first_sheet,second-sheet',
        ),
        expectedState: 'request-state',
        config: config,
      );

      expect(success.result?.pickedSpreadsheetIds, [
        'first_sheet',
        'second-sheet',
      ]);
      expect(success.errorMessage, isNull);

      final successWithToken = validateGooglePickerNativeCallback(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&picked_file_ids=spreadsheet-id'
          '&access_token=oauth-token'
          '&account_email=athlete%40example.com'
          '&account_name=Athlete%20Name'
          '&account_photo=https%3A%2F%2Fexample.com%2Fathlete.png',
        ),
        expectedState: 'request-state',
        config: config,
      );
      expect(successWithToken.result?.pickedSpreadsheetIds, ['spreadsheet-id']);
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
        final aliasSuccess = validateGooglePickerNativeCallback(
          Uri.parse(
            'workouttracker://google-picker-callback'
            '?state=request-state&$alias=spreadsheet-id',
          ),
          expectedState: 'request-state',
          config: config,
        );
        expect(
          aliasSuccess.result?.pickedSpreadsheetIds,
          ['spreadsheet-id'],
          reason: 'callback ID alias $alias should be accepted',
        );
      }

      final cancelled = validateGooglePickerNativeCallback(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&error=access_denied',
        ),
        expectedState: 'request-state',
        config: config,
      );
      expect(cancelled.result?.cancelled, isTrue);

      final pickerError = validateGooglePickerNativeCallback(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&error=server_error',
        ),
        expectedState: 'request-state',
        config: config,
      );
      expect(pickerError.result?.error, 'server_error');

      final missingState = validateGooglePickerNativeCallback(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?picked_file_ids=spreadsheet-id',
        ),
        expectedState: 'request-state',
        config: config,
      );
      expect(missingState.result, isNull);
      expect(missingState.errorMessage, contains('missing request state'));

      final wrongState = validateGooglePickerNativeCallback(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=other-state&picked_file_ids=spreadsheet-id',
        ),
        expectedState: 'request-state',
        config: config,
      );
      expect(wrongState.result, isNull);
      expect(wrongState.errorMessage, contains('state'));

      final malformedSpreadsheetId = validateGooglePickerNativeCallback(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&picked_file_ids=spreadsheet.id',
        ),
        expectedState: 'request-state',
        config: config,
      );
      expect(malformedSpreadsheetId.result, isNull);
      expect(malformedSpreadsheetId.errorMessage, contains('spreadsheet ID'));

      final tokenWithoutSelection = validateGooglePickerNativeCallback(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&access_token=oauth-token',
        ),
        expectedState: 'request-state',
        config: config,
      );
      expect(tokenWithoutSelection.result, isNull);
      expect(tokenWithoutSelection.errorMessage, contains('spreadsheet IDs'));

      final unrelated = validateGooglePickerNativeCallback(
        Uri.parse(
          'com.googleusercontent.apps.client:/oauth2redirect'
          '?state=request-state&picked_file_ids=spreadsheet-id',
        ),
        expectedState: 'request-state',
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
}

GooglePickerAppConfig _testGooglePickerConfig() {
  return GooglePickerAppConfig(
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

Future<GooglePickerCallbackReceiver> _unusedCallbackReceiverFactory({
  required String state,
  required Duration timeout,
}) async {
  throw StateError('Spreadsheet picker callback receiver was not expected.');
}
