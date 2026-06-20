import 'package:flutter/material.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  final googleSignInGateway = NativeGoogleSignInAuthorizationGateway();
  runApp(
    WorkoutTrackerApp(
      validationService: GoogleSignInSpreadsheetValidationService(
        authorizationGateway: googleSignInGateway,
      ),
      accountSession: googleSignInGateway,
      appStateStore: const FileAppStateStore(),
      spreadsheetPicker: const MobileGoogleDriveSpreadsheetPicker(),
    ),
  );
}
