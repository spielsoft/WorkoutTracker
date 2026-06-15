import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  testWidgets(
    'logs a primary set before switching to backup logging in the same flow',
    (tester) async {
      final rows = [
        [...activeSheetFixedColumns, 'Week 3', '', 'Week 2', 'Week 1'],
        [
          ...List.filled(activeSheetFixedColumns.length, ''),
          'S1',
          'S2',
          'S1',
          'S1',
        ],
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
          '225x5@8',
          'manual heavy single',
          '215x5@8',
          '205x5@8',
        ],
        [
          'Leg Press',
          '3',
          '10',
          '8',
          '2 min',
          '',
          'Backup if racks are full.',
          'Legs',
          'TRUE',
          '',
          '',
          '360x10@8',
          '',
        ],
      ];
      final service = _FakeSpreadsheetValidationService.fromRows(rows);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: service,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -320));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Squat'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('set-weight')), '230');
      await tester.enterText(find.byKey(const ValueKey('set-reps')), '5');
      await tester.enterText(find.byKey(const ValueKey('set-rpe')), '8');
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save set'));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans.first.columnInsertions, [
        HistoryColumnInsertion(
          sheetColumnNumber: 12,
          headers: const [''],
          setLabels: const ['S3'],
        ),
      ]);
      expect(service.appliedPlans.first.cellUpdates, [
        const CellUpdate(
          sheetRowNumber: 3,
          sheetColumnNumber: 12,
          value: '230x5@8',
        ),
      ]);
      expect(find.text('Next set S4'), findsOneWidget);
      expect(find.text('230x5@8'), findsOneWidget);

      await tester.tap(find.text('Leg Press'));
      await tester.pumpAndSettle();

      expect(find.text('Leg Press logging'), findsOneWidget);
      expect(find.text('Next set S1'), findsOneWidget);
      expect(find.text('Latest history: 360x10@8'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('set-weight')), '400');
      await tester.enterText(find.byKey(const ValueKey('set-reps')), '10');
      await tester.enterText(find.byKey(const ValueKey('set-rpe')), '8');
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save set'));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans.last.cellUpdates.single.value, '400x10@8');
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text('Next set S2'), findsOneWidget);
      expect(find.text('400x10@8'), findsOneWidget);
    },
  );

  testWidgets('accepts simulator mouse and trackpad drag scrolling', (
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

  testWidgets('logs edits clears and switches row-local exercise history', (
    tester,
  ) async {
    final rows = [
      [...activeSheetFixedColumns, 'Week 3', '', 'Week 2', 'Week 1'],
      [
        ...List.filled(activeSheetFixedColumns.length, ''),
        'S1',
        'S2',
        'S1',
        'S1',
      ],
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
        '225x5@8',
        'manual heavy single',
        '215x5@8',
        '205x5@8',
      ],
      [
        'Leg Press',
        '3',
        '10',
        '8',
        '2 min',
        '',
        'Backup if racks are full.',
        'Legs',
        'TRUE',
        '',
        '',
        '360x10@8',
        '',
      ],
    ];
    final service = _FakeSpreadsheetValidationService.fromRows(rows);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();

    expect(find.text('Squat logging'), findsOneWidget);
    expect(find.text('Stay braced.'), findsOneWidget);
    expect(find.text('Rest: 3 min'), findsOneWidget);
    expect(find.text('Target: 3 sets x 5 @ 8'), findsOneWidget);
    expect(find.text('Next set S3'), findsOneWidget);
    expect(find.text('manual heavy single'), findsOneWidget);

    final nextSetTop = tester.getTopLeft(find.text('Next set S3')).dy;
    final priorSetTop = tester.getTopLeft(find.text('S2')).dy;
    final historyTop = tester.getTopLeft(find.text('Recent history')).dy;
    expect(nextSetTop, lessThan(priorSetTop));
    expect(priorSetTop, lessThan(historyTop));

    await tester.tap(find.text('Leg Press'));
    await tester.pumpAndSettle();

    expect(find.text('Leg Press logging'), findsOneWidget);
    expect(find.text('Backup if racks are full.'), findsOneWidget);
    expect(find.text('Rest: 2 min'), findsOneWidget);
    expect(find.text('Next set S1'), findsOneWidget);
    expect(find.text('Latest history: 360x10@8'), findsOneWidget);
    expect(find.textContaining('215x5@8'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('set-weight')), '400');
    await tester.enterText(find.byKey(const ValueKey('set-reps')), '10');
    await tester.enterText(find.byKey(const ValueKey('set-rpe')), '8');
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save set'));
    await tester.pump();
    await tester.pump();

    expect(service.appliedPlans.last.cellUpdates.single.value, '400x10@8');
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('Next set S2'), findsOneWidget);
    expect(find.text('400x10@8'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('raw-S1')),
      'sled felt sticky',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-S1')));
    await tester.pump();
    await tester.pump();

    expect(
      service.appliedPlans.last.cellUpdates.single.value,
      'sled felt sticky',
    );
    expect(find.text('sled felt sticky'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clear-S1')));
    await tester.pump();
    await tester.pump();

    expect(service.appliedPlans.last.cellUpdates.single.value, '');
    expect(find.text('Next set S1'), findsOneWidget);
    expect(find.text('sled felt sticky'), findsNothing);
  });

  testWidgets('selects a workout and history block before showing overview', (
    tester,
  ) async {
    final service = _FakeSpreadsheetValidationService(
      parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [...activeSheetFixedColumns, 'Week 2', '', 'Week 1'],
            [
              ...List.filled(activeSheetFixedColumns.length, ''),
              'S1',
              'S2',
              'S1',
            ],
            [
              'Squat',
              '3',
              '5',
              '8',
              '3 min',
              '',
              '',
              'Legs',
              '',
              '225x5@8',
              '',
              '205x5@8',
            ],
            [
              'Leg Press',
              '3',
              '10',
              '8',
              '2 min',
              '',
              'Backup if racks are full.',
              'Legs',
              'TRUE',
              '360x10@8',
              '',
              '',
            ],
            [
              'Deadlift',
              '3',
              '5',
              '8',
              '3 min',
              '',
              '',
              'Legs',
              '',
              '',
              '',
              '',
            ],
            [
              'Bench Press',
              '4',
              '6',
              '8',
              '3 min',
              '',
              '',
              'Upper',
              '',
              '155x6@8',
              '',
              '',
            ],
            ['Plank', '3', '45s', '8', '60s', '', '', '', '', '', '', ''],
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Workout'), findsOneWidget);
    expect(find.text('History block'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Leg Press'), findsOneWidget);
    expect(find.text('Deadlift'), findsOneWidget);
    expect(find.text('Bench Press'), findsNothing);
    expect(find.text('2 sets'), findsOneWidget);
    expect(find.text('0 sets'), findsOneWidget);

    final squatTop = tester.getTopLeft(find.text('Squat')).dy;
    final deadliftTop = tester.getTopLeft(find.text('Deadlift')).dy;
    expect(squatTop, lessThan(deadliftTop));

    await tester.tap(find.text('Week 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week 1').last);
    await tester.pumpAndSettle();

    expect(find.text('1 set'), findsOneWidget);

    await tester.tap(find.text('Legs').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(defaultWorkoutName).last);
    await tester.pumpAndSettle();

    expect(find.text('Plank'), findsOneWidget);
    expect(find.text('Squat'), findsNothing);
  });

  testWidgets('creates and selects a new visible history block', (
    tester,
  ) async {
    final rows = [
      [...activeSheetFixedColumns, 'Week 2'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', '', '225x5@8'],
    ];
    final service = _FakeSpreadsheetValidationService.fromRows(rows);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('new-history-block-label')),
      'Week 3',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create history block'));
    await tester.pump();
    await tester.pump();

    expect(service.createdHistoryBlockLabels, ['Week 3']);
    expect(find.text('Week 3'), findsOneWidget);
    expect(find.text('0 sets'), findsOneWidget);
  });

  testWidgets('validates a selected spreadsheet and shows backend issues', (
    tester,
  ) async {
    final service = _FakeSpreadsheetValidationService(
      parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [...activeSheetFixedColumns, 'Week 1'],
            [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
            [
              'Reverse Lunge',
              '3',
              '10/side',
              '8',
              '90s',
              '',
              'Backup if benches are taken.',
              'Legs',
              'TRUE',
              '',
            ],
          ],
          exercisesRows: const [
            [
              'Exercise',
              'Description',
              'Default Sets',
              'Default Reps',
              'Default RPE',
              'Default Rest',
              'Default Tempo',
              'Notes',
            ],
            [
              'Reverse Lunge',
              'Dumbbell reverse lunge',
              '3',
              '10/side',
              '8',
              '90s',
              '',
              'Backup if benches are taken.',
            ],
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText:
            'https://docs.google.com/spreadsheets/d/'
            '$workoutTrackerDevelopmentSpreadsheetId/edit?gid=0#gid=0',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    expect(service.spreadsheetIds, [workoutTrackerDevelopmentSpreadsheetId]);
    expect(find.text('Sheet contract issues'), findsOneWidget);
    expect(
      find.textContaining(
        'Row 3, Legs: Backup row has no preceding primary row',
      ),
      findsOneWidget,
    );
    expect(find.text('Formula repair needed'), findsOneWidget);
    expect(find.textContaining('Row 3, Reverse Lunge'), findsOneWidget);
    expect(find.textContaining('Exercise: missing formula'), findsOneWidget);
  });

  testWidgets('shows workflow without success panels for a valid spreadsheet', (
    tester,
  ) async {
    final service = _FakeSpreadsheetValidationService(
      parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [
              'Exercise',
              'Sets',
              'Reps',
              'RPE',
              'Rest',
              'Tempo',
              'Notes',
              'Workout',
              'is_backup',
              'Week 1',
            ],
            ['', '', '', '', '', '', '', '', '', 'S1'],
            [
              'Squat',
              '3',
              '5',
              '8',
              '3 min',
              '',
              'Stay braced.',
              'Legs',
              '',
              '',
            ],
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    expect(service.spreadsheetIds, ['spreadsheet-id']);
    expect(find.text('Sheet contract valid'), findsNothing);
    expect(find.text('Formulas valid'), findsNothing);
    expect(find.text('Sheet contract issues'), findsNothing);
    expect(find.text('Formula repair needed'), findsNothing);
    expect(find.text('Workout setup'), findsOneWidget);
  });

  testWidgets('uses compact spreadsheet controls on mobile', (tester) async {
    final service = _FakeSpreadsheetValidationService(
      parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [...activeSheetFixedColumns, 'Week 1'],
            [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
            ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', '', ''],
          ],
        ),
      ),
    );

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
    : activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows)),
      _sourceRows = rows;

  ParsedActiveSheet activeSheet;
  List<List<String>>? _sourceRows;
  final spreadsheetIds = <String>[];
  final createdHistoryBlockLabels = <String>[];
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
    createdHistoryBlockLabels.add(label);
    final sourceRows = _sourceRows;
    if (sourceRows != null) {
      final previewRows = activeSheet
          .planNewHistoryBlock(label: label)
          .previewRowsAfterApplying(sourceRows);
      this.activeSheet = parseActiveSheet(ActiveSheetInput(rows: previewRows));
      _sourceRows = previewRows;
    }
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
    final sourceRows = _sourceRows;
    if (sourceRows != null) {
      final previewRows = plan.previewRowsAfterApplying(sourceRows);
      this.activeSheet = parseActiveSheet(ActiveSheetInput(rows: previewRows));
      _sourceRows = previewRows;
    }
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: this.activeSheet,
    );
  }
}
