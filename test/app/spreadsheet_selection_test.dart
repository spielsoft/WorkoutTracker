import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
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
    expect(workoutTrackerGooglePickerClientId, isNotEmpty);
    expect(
      MobileGoogleDriveSpreadsheetPicker(
        callbackReceiverFactory: _unusedCallbackReceiverFactory,
      ).availability.canChoose,
      isTrue,
    );
  });

  test(
    'Google Picker authorization URL carries the app callback path and request state',
    () {
      final authorizationUrl =
          MobileGoogleDriveSpreadsheetPicker.googlePickerAuthorizationUrl(
            clientId: 'client-id.apps.googleusercontent.com',
            redirectUri: workoutTrackerGooglePickerHostedCallbackUri,
            state: 'request-state',
          );

      expect(authorizationUrl.host, 'accounts.google.com');
      expect(
        authorizationUrl.queryParameters['redirect_uri'],
        workoutTrackerGooglePickerHostedCallbackUri.toString(),
      );
      expect(authorizationUrl.queryParameters['state'], 'request-state');
    },
  );

  test(
    'native Google Picker callback parser accepts only app-owned results',
    () {
      final success = validateGooglePickerNativeCallback(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&picked_file_ids=first_sheet,second-sheet',
        ),
        expectedState: 'request-state',
      );

      expect(success.result?.pickedSpreadsheetIds, [
        'first_sheet',
        'second-sheet',
      ]);
      expect(success.errorMessage, isNull);

      final cancelled = validateGooglePickerNativeCallback(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&error=access_denied',
        ),
        expectedState: 'request-state',
      );
      expect(cancelled.result?.cancelled, isTrue);

      final pickerError = validateGooglePickerNativeCallback(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&error=server_error',
        ),
        expectedState: 'request-state',
      );
      expect(pickerError.result?.error, 'server_error');

      final missingState = validateGooglePickerNativeCallback(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?picked_file_ids=spreadsheet-id',
        ),
        expectedState: 'request-state',
      );
      expect(missingState.result, isNull);
      expect(missingState.errorMessage, contains('missing request state'));

      final wrongState = validateGooglePickerNativeCallback(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=other-state&picked_file_ids=spreadsheet-id',
        ),
        expectedState: 'request-state',
      );
      expect(wrongState.result, isNull);
      expect(wrongState.errorMessage, contains('state'));

      final malformedSpreadsheetId = validateGooglePickerNativeCallback(
        Uri.parse(
          'workouttracker://google-picker-callback'
          '?state=request-state&picked_file_ids=spreadsheet.id',
        ),
        expectedState: 'request-state',
      );
      expect(malformedSpreadsheetId.result, isNull);
      expect(malformedSpreadsheetId.errorMessage, contains('spreadsheet ID'));

      final unrelated = validateGooglePickerNativeCallback(
        Uri.parse(
          'com.googleusercontent.apps.client:/oauth2redirect'
          '?state=request-state&picked_file_ids=spreadsheet-id',
        ),
        expectedState: 'request-state',
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

Future<GooglePickerCallbackReceiver> _unusedCallbackReceiverFactory({
  required String state,
  required Duration timeout,
}) async {
  throw StateError('Spreadsheet picker callback receiver was not expected.');
}
