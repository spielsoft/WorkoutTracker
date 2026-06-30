import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  final appLinks = AppLinks();
  final googleSignInGateway = GooglePickerAuthorizationGateway();
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
        callbackReceiverFactory: ({required state, required timeout}) async {
          return NativeGooglePickerCallbackReceiver(
            state: state,
            timeout: timeout,
            uriLinkStream: appLinks.uriLinkStream,
          );
        },
        spreadsheetCreator: GoogleSheetsSpreadsheetCreator(
          authorizationGateway: googleSignInGateway,
        ),
      ),
    ),
  );
}
