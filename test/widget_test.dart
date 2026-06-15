import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  testWidgets('renders the main logging flow and sends a save to the service', (
    tester,
  ) async {
    final service = _FakeSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 2', 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1'],
      [
        'Squat',
        '3',
        '5',
        '8',
        '3 min',
        'Controlled',
        'Stay braced.',
        'Legs',
        '',
        '',
        '',
      ],
      ['Bench Press', '4', '6', '8', '3 min', '', '', 'Upper', '', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    expect(find.text('WorkoutTracker'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('spreadsheet-selection-input')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    expect(service.spreadsheetIds, ['spreadsheet-id']);
    expect(find.text('Workout setup'), findsOneWidget);
    expect(find.text('Workout'), findsOneWidget);
    expect(find.text('History block'), findsOneWidget);
    expect(find.text('Legs exercises'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);

    await tester.tap(find.text('Week 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week 1').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Legs').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upper').last);
    await tester.pumpAndSettle();

    expect(find.text('Upper exercises'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);

    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press logging'), findsOneWidget);
    expect(find.byKey(const ValueKey('set-weight')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-reps')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-rpe')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('set-weight')), '155');
    await tester.enterText(find.byKey(const ValueKey('set-reps')), '6');
    await tester.enterText(find.byKey(const ValueKey('set-rpe')), '8');
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save set'));
    await tester.pump();
    await tester.pump();

    expect(service.appliedPlans, hasLength(1));
  });

  testWidgets('renders compact spreadsheet controls with desktop scrolling', (
    tester,
  ) async {
    final service = _FakeSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    expect(find.text('Spreadsheet validation'), findsNothing);
    expect(find.byKey(const ValueKey('validate-spreadsheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('use-development-sheet')), findsOneWidget);
    expect(find.text('Validate'), findsOneWidget);
    expect(find.text('Development'), findsOneWidget);

    final validateTop = tester
        .getTopLeft(find.byKey(const ValueKey('validate-spreadsheet')))
        .dy;
    final developmentTop = tester
        .getTopLeft(find.byKey(const ValueKey('use-development-sheet')))
        .dy;
    expect(validateTop, developmentTop);

    final behavior = ScrollConfiguration.of(
      tester.element(find.byKey(const ValueKey('spreadsheet-selection-input'))),
    );
    expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
    expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
    expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
  });

  testWidgets('shows a top-right Google account menu for account switching', (
    tester,
  ) async {
    final service = _FakeSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', '', ''],
    ]);
    final accountSession = _FakeGoogleAccountSession(
      const GoogleAccountProfile(
        email: 'wrong@example.com',
        displayName: 'Wrong Account',
      ),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        accountSession: accountSession,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byTooltip('Google account: wrong@example.com'));
    await tester.pumpAndSettle();

    expect(find.text('Wrong Account'), findsOneWidget);
    expect(find.text('wrong@example.com'), findsOneWidget);

    await tester.tap(find.text('Switch account'));
    await tester.pumpAndSettle();

    expect(accountSession.switchCount, 1);
    expect(accountSession.requestedScopes.single, [
      'https://www.googleapis.com/auth/spreadsheets',
    ]);
    expect(accountSession.currentAccount?.email, 'right@example.com');
  });
}

class _FakeGoogleAccountSession extends ChangeNotifier
    implements GoogleAccountSession {
  _FakeGoogleAccountSession(this._currentAccount);

  GoogleAccountProfile? _currentAccount;
  int switchCount = 0;
  final requestedScopes = <List<String>>[];

  @override
  GoogleAccountProfile? get currentAccount => _currentAccount;

  @override
  Future<void> switchAccount({List<String> scopes = const []}) async {
    switchCount += 1;
    requestedScopes.add(scopes);
    _currentAccount = const GoogleAccountProfile(
      email: 'right@example.com',
      displayName: 'Right Account',
    );
    notifyListeners();
  }
}

class _FakeSpreadsheetValidationService
    implements SpreadsheetValidationService {
  _FakeSpreadsheetValidationService(this.activeSheet);

  _FakeSpreadsheetValidationService.fromRows(List<List<String>> rows)
    : activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

  ParsedActiveSheet activeSheet;
  final spreadsheetIds = <String>[];
  final appliedPlans = <ActiveSheetWritePlan>[];

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    spreadsheetIds.add(spreadsheetId);
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
    );
  }

  @override
  Future<SpreadsheetValidationReport> createHistoryBlock({
    required String spreadsheetId,
    required String label,
    required ParsedActiveSheet activeSheet,
  }) async {
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: this.activeSheet,
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    appliedPlans.add(plan);
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: this.activeSheet,
    );
  }
}
