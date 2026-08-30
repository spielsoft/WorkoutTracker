import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workout_tracker/app.dart';

import 'src/app/sheet_picker_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final navigatorKey = GlobalKey<NavigatorState>();
  final googleAuth = NativeSignInAuthGateway();
  final google = ScopedApiAccess(auth: googleAuth);
  final sheetSvc = SheetAccess(google);
  runApp(
    WorkoutTrackerApp(
      svc: sheetSvc,
      navigatorKey: navigatorKey,
      accountSession: googleAuth,
      appStStore: const FileAppStStore(getApplicationSupportDirectory),
      picker: DriveSheetPicker(
        googleAccess: google,
        showPicker: (req) async {
          final context = navigatorKey.currentContext;
          if (context == null) {
            throw StateError('Unable to show the Google Drive sheet chooser.');
          }
          return showSheetPickerPage(context, req);
        },
        sheetCreator: SheetCreator(googleAccess: google),
      ),
    ),
  );
}
