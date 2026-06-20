import 'package:flutter/material.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  final googleSignInGateway = NativeGoogleSignInAuthorizationGateway();
  final googleSpreadsheetService = GoogleSignInSpreadsheetValidationService(
    authorizationGateway: googleSignInGateway,
  );
  runApp(
    WorkoutTrackerApp(
      validationService: googleSpreadsheetService,
      exerciseAuthoringService: googleSpreadsheetService,
      accountSession: googleSignInGateway,
      appStateStore: const FileAppStateStore(),
      spreadsheetPicker: MobileGoogleDriveSpreadsheetPicker(
        authorizationGateway: googleSignInGateway,
        spreadsheetCreator: GoogleSheetsSpreadsheetCreator(
          authorizationGateway: googleSignInGateway,
        ),
      ),
    ),
  );
}
