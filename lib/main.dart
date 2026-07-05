import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appLinks = AppLinks();
  final googlePickerConfig = await loadPickerAppConfig();
  final googleSignInGateway = PickerAuthGateway();
  final googleSpreadsheetService = SpreadsheetAccess(
    GoogleScopedApiAccess(auth: googleSignInGateway),
  );
  runApp(
    WorkoutTrackerApp(
      svc: googleSpreadsheetService,
      accountSession: googleSignInGateway,
      appStateStore: const FileAppStateStore(),
      picker: MobileSpreadsheetPicker(
        config: googlePickerConfig,
        auth: googleSignInGateway,
        callbackFactory: ({required state, required timeout}) async {
          return NativePickerCallbackReceiver(
            state: state,
            config: googlePickerConfig,
            timeout: timeout,
            uriLinkStream: appLinks.uriLinkStream,
          );
        },
        spreadsheetCreator: SpreadsheetCreator(auth: googleSignInGateway),
      ),
    ),
  );
}
