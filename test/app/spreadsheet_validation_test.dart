import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  test(
    'explicit development credentials path is used before host ADC lookup',
    () async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'workout-tracker-credentials-test-',
      );
      addTearDown(() {
        tempDirectory.deleteSync(recursive: true);
      });
      final credentialsFile = File('${tempDirectory.path}/credentials.json')
        ..writeAsStringSync('[]');

      await expectLater(
        clientViaWorkoutTrackerDevelopmentCredentials(
          scopes: GoogleApisSheetsSpreadsheetClient.readOnlyScopes,
          credentialsPath: credentialsFile.path,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Google credentials file must contain a JSON object'),
          ),
        ),
      );
    },
  );
}
