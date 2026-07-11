import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/sheets.dart';

import '../test/support/reset.dart'
    show DevelopmentSheetResetHarness, workoutTrackerDevelopmentSpreadsheetId;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final enabled =
      Platform.environment['WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS'] == '1';

  testWidgets('destructively logs through production composition and resets '
      'the WorkoutTracker development fixture', (_) async {
    final auth = NativeSignInAuthGateway();
    final google = ScopedApiAccess(auth: auth);
    final workspace = WorkspaceCtrl(
      accountSession: auth,
      picker: DriveSheetPicker(
        googleAccess: google,
        showPicker: _resolveFixture,
      ),
    );
    final entry = LiveLoggingEntry(
      workspace: workspace,
      svc: SheetAccess(google),
    );
    addTearDown(() {
      workspace.dispose();
      auth.dispose();
    });

    var fixtureWasReset = false;
    addTearDown(() async {
      if (fixtureWasReset) {
        await _resetFixture(google);
      }
    });

    final report = await entry.run(
      const LiveSet(
        blockLabel: 'Week 1',
        primaryRow: 3,
        selectedRow: 3,
        fields: {'Weight': '80', 'Reps': '8', 'RPE': '8'},
        expectedRaw: '80x8@8',
      ),
      beforeValidation: () async {
        await _resetFixture(google);
        fixtureWasReset = true;
      },
    );

    final logged = report.activeSheet.buildLoggingContext(
      primaryRow: 3,
      selectedRow: 3,
      blockLabel: 'Week 1',
    );
    expect(logged.selectedHistory.entries.single.rawValue, '80x8@8');
  }, skip: !enabled);
}

Future<SheetEntry?> _resolveFixture(SheetViewReq req) async {
  final entries = await req.load('WorkoutTracker development');
  for (final entry in entries) {
    if (entry.id == workoutTrackerDevelopmentSpreadsheetId) {
      return entry;
    }
  }
  throw StateError(
    'The destructive WorkoutTracker development fixture is not accessible.',
  );
}

Future<void> _resetFixture(ApiAccess google) {
  return google.run(
    scopes: GoogleApisWbkInit.writeScopes,
    action: (resources) {
      return DevelopmentSheetResetHarness(
        initializer: GoogleApisWbkInit(resources.sheetsApi),
      ).reset();
    },
  );
}
