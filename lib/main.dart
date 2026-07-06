import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:workout_tracker/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appLinks = AppLinks();
  final googlePickerConfig = await loadPickerAppCfg();
  final googleSignInGateway = PickerAuthGateway();
  final sheetSvc = SheetAccess(ScopedApiAccess(auth: googleSignInGateway));
  runApp(
    WorkoutTrackerApp(
      svc: sheetSvc,
      accountSession: googleSignInGateway,
      appStStore: const FileAppStStore(),
      picker: MobileSheetPicker(
        config: googlePickerConfig,
        auth: googleSignInGateway,
        callbackFactory: ({required state, required timeout}) async {
          return NativeCbReceiver(
            state: state,
            config: googlePickerConfig,
            timeout: timeout,
            uriLinkStream: appLinks.uriLinkStream,
          );
        },
        sheetCreator: SheetCreator(auth: googleSignInGateway),
      ),
    ),
  );
}
