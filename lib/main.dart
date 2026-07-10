import 'package:flutter/material.dart';
import 'package:workout_tracker/app.dart';

import 'src/app/sheet_picker_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final navigatorKey = GlobalKey<NavigatorState>();
  final googleAuth = NativeSignInAuthGateway();
  final sheetSvc = SheetAccess(ScopedApiAccess(auth: googleAuth));
  runApp(
    WorkoutTrackerApp(
      svc: sheetSvc,
      navigatorKey: navigatorKey,
      accountSession: googleAuth,
      appStStore: const FileAppStStore(),
      picker: DriveSheetPicker(
        auth: googleAuth,
        showPicker: (req) async {
          final context = navigatorKey.currentContext;
          if (context == null) {
            throw StateError('Unable to show the Google Drive sheet chooser.');
          }
          return showSheetPickerPage(context, req);
        },
        sheetCreator: SheetCreator(auth: googleAuth),
      ),
    ),
  );
}
