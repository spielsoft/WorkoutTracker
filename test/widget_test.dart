import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

import 'app/test_spreadsheet_validation_service.dart';

void main() {
  testWidgets('renders the main logging flow and sends a save to the service', (
    tester,
  ) async {
    final service = TestSpreadsheetValidationService.fromRows([
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
        '',
        'Legs',
        '',
        '',
        '',
      ],
      ['Bench Press', '4', '6', '8', '3 min', '', '', '', 'Upper', '', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    expect(find.text('WorkoutTracker'), findsNothing);
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
    expect(find.text('Legs (0/1 done)'), findsOneWidget);
    expect(find.text('Legs exercises'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);

    await tester.tap(find.text('Week 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week 1').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Legs (0/1 done)').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upper (0/1 done)').last);
    await tester.pumpAndSettle();

    expect(find.text('Upper exercises'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);

    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsWidgets);
    expect(find.text('Bench Press logging'), findsNothing);
    expect(find.byKey(const ValueKey('set-field-Weight')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-field-Reps')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-field-RPE')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('set-field-Weight')),
      '155',
    );
    await tester.enterText(find.byKey(const ValueKey('set-field-Reps')), '6');
    await tester.enterText(find.byKey(const ValueKey('set-field-RPE')), '8');
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save set'));
    await tester.pump();
    await tester.pump();

    expect(service.appliedPlans, hasLength(1));
    expect(service.appliedPlans.single.cellUpdates.single.value, '155x6@8');
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('logged-S1-field-Weight')),
          )
          .controller
          ?.text,
      '155',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('logged-S1-field-Reps')))
          .controller
          ?.text,
      '6',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('logged-S1-field-RPE')))
          .controller
          ?.text,
      '8',
    );
    expect(find.text('Next set S2'), findsOneWidget);
  });

  testWidgets('renders compact spreadsheet controls with desktop scrolling', (
    tester,
  ) async {
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    expect(find.text('Spreadsheet validation'), findsNothing);
    expect(find.byKey(const ValueKey('validate-spreadsheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('use-development-sheet')), findsNothing);
    expect(find.text('Validate'), findsOneWidget);
    expect(find.text('Development'), findsNothing);

    final behavior = ScrollConfiguration.of(
      tester.element(find.byKey(const ValueKey('spreadsheet-selection-input'))),
    );
    expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
    expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
    expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
  });

  testWidgets('restores and persists the spreadsheet field', (tester) async {
    final store = _MemoryAppStateStore('saved-spreadsheet-id');
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        appStateStore: store,
        initialSpreadsheetText: 'initial-spreadsheet-id',
      ),
    );
    await tester.pump();

    final input = find.byKey(const ValueKey('spreadsheet-selection-input'));
    expect(
      tester.widget<TextField>(input).controller?.text,
      'saved-spreadsheet-id',
    );

    await tester.enterText(input, 'edited-spreadsheet-id');
    await tester.pump();

    expect(store.writes.last, 'edited-spreadsheet-id');
  });

  testWidgets('restores the Google account session on startup', (tester) async {
    final accountSession = _FakeGoogleAccountSession(
      null,
      restoredAccount: const GoogleAccountProfile(
        email: 'saved@example.com',
        displayName: 'Saved Account',
      ),
    );
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        accountSession: accountSession,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );
    await tester.pump();

    expect(accountSession.restoreCount, 1);
    expect(find.byTooltip('Google account: saved@example.com'), findsOneWidget);
  });

  testWidgets(
    'labels workouts with selected-block progress and counts backups with parent',
    (tester) async {
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Pull Up',
          '3',
          '8',
          '8',
          '2 min',
          '',
          'Full hang.',
          '{Reps}',
          'Upper',
          '',
          '',
        ],
        [
          'Front Plank',
          '3',
          '45s',
          '8',
          '60s',
          '',
          'Brace hard.',
          '{Seconds}[s@]{RPE}',
          'Upper',
          'TRUE',
          '45s@8',
        ],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: service,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Upper (1/1 done)'), findsOneWidget);
      await tester.tap(find.text('Upper (1/1 done)'));
      await tester.pumpAndSettle();
      expect(find.text('Legs (0/1 done)'), findsOneWidget);
    },
  );

  testWidgets(
    'renders bodyweight logging fields from the selected row format',
    (tester) async {
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Pull Up',
          '3',
          '8',
          '8',
          '2 min',
          '',
          'Full hang.',
          '{Reps}[@]{RPE}',
          'Upper',
          '',
          '',
        ],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: service,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Pull Up'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('set-field-Reps')), findsOneWidget);
      expect(find.byKey(const ValueKey('set-field-RPE')), findsOneWidget);
      expect(find.byKey(const ValueKey('set-field-Weight')), findsNothing);
      expect(find.byKey(const ValueKey('set-field-Pain')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('set-field-Reps')),
        '12',
      );
      await tester.enterText(find.byKey(const ValueKey('set-field-RPE')), '8');
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save set'));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans.single.cellUpdates.single.value, '12@8');
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('logged-S1-field-Reps')),
            )
            .controller
            ?.text,
        '12',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('logged-S1-field-RPE')),
            )
            .controller
            ?.text,
        '8',
      );
      expect(find.text('Next set S2'), findsOneWidget);
    },
  );

  testWidgets('renders height-based and timed sheet-authored labels', (
    tester,
  ) async {
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      [
        'Step Up',
        '3',
        '10',
        '8',
        '2 min',
        '',
        '',
        '{Height}[x]{Reps}[@]{RPE}',
        'Legs',
        '',
        '',
      ],
      [
        'Front Plank',
        '3',
        '45s',
        '8',
        '60s',
        '',
        '',
        '{Seconds}[s@]{RPE}',
        'Legs',
        '',
        '',
      ],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Step Up'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('set-field-Height')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-field-Reps')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-field-RPE')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-field-Weight')), findsNothing);

    await tester.tap(find.text('Back to exercises'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Front Plank'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('set-field-Seconds')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-field-RPE')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-field-Weight')), findsNothing);
    expect(find.byKey(const ValueKey('set-field-Height')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('set-field-Seconds')),
      '45',
    );
    await tester.enterText(find.byKey(const ValueKey('set-field-RPE')), '8');
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save set'));
    await tester.pump();
    await tester.pump();

    expect(service.appliedPlans.single.cellUpdates.single.value, '45s@8');
  });

  testWidgets(
    'keeps exercise context, selected rows, recent history, and raw controls',
    (tester) async {
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 2', 'Week 1', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1', 'S2'],
        [
          'Carry',
          '3',
          '40',
          '8',
          '90s',
          'Smooth',
          'Stay tall.',
          '{Distance}[@]{RPE}',
          'Conditioning',
          '',
          'worked up, grip failed',
          '30@7',
          '35@8',
        ],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: service,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Carry'));
      await tester.pumpAndSettle();

      expect(find.text('Carry'), findsWidgets);
      expect(find.text('Carry logging'), findsNothing);
      expect(find.text('Target: 3 sets x 40 @ 8'), findsOneWidget);
      expect(find.text('Rest: 90s'), findsOneWidget);
      expect(find.text('Tempo: Smooth'), findsOneWidget);
      expect(find.text('Stay tall.'), findsOneWidget);
      expect(find.text('Next set S2'), findsOneWidget);
      expect(find.text('Logged sets'), findsOneWidget);
      expect(find.byKey(const ValueKey('raw-S1')), findsOneWidget);
      expect(find.text('Recent history'), findsOneWidget);
      expect(find.text('Week 1'), findsWidgets);
      expect(find.text('Week 1 S1: 30@7'), findsNothing);
      expect(find.text('S1: 30@7'), findsOneWidget);
      expect(find.text('S2: 35@8'), findsOneWidget);
    },
  );

  testWidgets(
    'switching to a backup row refreshes structured labels and parsed values',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Pull Up',
          '3',
          '8',
          '8',
          '2 min',
          '',
          'Full hang.',
          '{Reps}',
          'Upper',
          '',
          '12',
        ],
        [
          'Front Plank',
          '3',
          '45s',
          '8',
          '60s',
          '',
          'Brace hard.',
          '{Seconds}[s@]{RPE}',
          'Upper',
          'TRUE',
          '45s@8',
        ],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: service,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Pull Up'));
      await tester.pumpAndSettle();

      final rowSelector = tester.widget<SegmentedButton<int>>(
        find.byWidgetPredicate((widget) => widget is SegmentedButton<int>),
      );
      expect(rowSelector.direction, Axis.vertical);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data == 'Front Plank' &&
              widget.maxLines == 1 &&
              widget.overflow == TextOverflow.ellipsis,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('logged-S1-field-Reps')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('logged-S1-field-Reps')),
            )
            .controller
            ?.text,
        '12',
      );

      await tester.tap(find.text('Front Plank'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('set-field-Seconds')), findsOneWidget);
      expect(find.byKey(const ValueKey('set-field-RPE')), findsOneWidget);
      expect(find.byKey(const ValueKey('set-field-Reps')), findsNothing);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('logged-S1-field-Seconds')),
            )
            .controller
            ?.text,
        '45',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('logged-S1-field-RPE')),
            )
            .controller
            ?.text,
        '8',
      );
    },
  );

  testWidgets('shows a top-right Google account menu for account switching', (
    tester,
  ) async {
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
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
  _FakeGoogleAccountSession(this._currentAccount, {this.restoredAccount});

  GoogleAccountProfile? _currentAccount;
  final GoogleAccountProfile? restoredAccount;
  int restoreCount = 0;
  int switchCount = 0;
  final requestedScopes = <List<String>>[];

  @override
  GoogleAccountProfile? get currentAccount => _currentAccount;

  @override
  Future<void> restoreAccount() async {
    restoreCount += 1;
    if (restoredAccount != null) {
      _currentAccount = restoredAccount;
      notifyListeners();
    }
  }

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

class _MemoryAppStateStore implements AppStateStore {
  _MemoryAppStateStore(this.spreadsheetText);

  String? spreadsheetText;
  final writes = <String>[];

  @override
  Future<String?> readSpreadsheetText() async {
    return spreadsheetText;
  }

  @override
  Future<void> writeSpreadsheetText(String value) async {
    spreadsheetText = value;
    writes.add(value);
  }
}
