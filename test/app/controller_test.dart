import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

import '../fixtures/workbook.dart';
import 'service_fake.dart';

void main() {
  test(
    'validates a spreadsheet selection and adopts workout and history ordering',
    () async {
      final service = TestValSvc.fromRows([
        [...activeSheetFixedColumns, 'Week 2', '', 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2', 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '', '', ''],
        [
          'Bench Press',
          '4',
          '6',
          '8',
          '3 min',
          '',
          '',
          '',
          'Upper',
          '',
          '',
          '',
          '',
        ],
      ]);
      final controller = AppCtrl(svc: service);

      controller.openExercise(99);

      final validated = await controller.validateSelection(
        'https://docs.google.com/spreadsheets/d/spreadsheet-id/edit?gid=0#gid=0',
      );

      expect(validated, isTrue);
      expect(service.spreadsheetIds, ['spreadsheet-id']);
      expect(controller.report?.sheetId, 'spreadsheet-id');
      expect(controller.workoutSetup?.selectedWorkout, 'Legs');
      expect(controller.workoutSetup?.selectedHistoryBlock, 'Week 2');
      expect(controller.workoutSetup?.loggingTarget, isNull);
      expect(controller.error, isNull);
    },
  );

  test(
    'blocks workout setup when the selected sheet has structural damage',
    () async {
      final fixtures = [
        loadFixedColumnDamageFixture(),
        loadMalformedHistoryDamageFixture(),
        loadInvalidLogFormatDamageFixture(),
        loadBackupGroupingDamageFixture(),
      ];

      for (final fixture in fixtures) {
        final service = TestValSvc(_parseWorkbookFixture(fixture));
        final controller = AppCtrl(svc: service);

        final validated = await controller.validateSelection('spreadsheet-id');

        expect(validated, isTrue);
        expect(controller.report?.schemaViolations, isNotEmpty);
        expect(controller.workoutSetup, isNull);
      }
    },
  );

  test(
    'changing workout or history clears the current logging selection',
    () async {
      final service = TestValSvc.fromRows([
        [...activeSheetFixedColumns, 'Week 2', '', 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2', 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '', '', ''],
        [
          'Leg Press',
          '3',
          '10',
          '8',
          '2 min',
          '',
          '',
          '',
          'Legs',
          'TRUE',
          '',
          '',
          '',
        ],
        ['Plank', '3', '45s', '8', '60s', '', '', '', '', '', '', '', ''],
      ]);
      final controller = AppCtrl(svc: service);

      await controller.validateSelection('spreadsheet-id');
      controller.openExercise(3);
      controller.selectLoggingRow(4);

      expect(controller.workoutSetup?.loggingTarget?.selectedRow, 4);

      controller.selectHistoryBlock('Week 1');
      expect(controller.workoutSetup?.loggingTarget, isNull);

      controller.openExercise(3);
      controller.selectLoggingRow(4);
      controller.selectWorkout(defaultWorkoutName);

      expect(controller.workoutSetup?.loggingTarget, isNull);
    },
  );

  test(
    'workout setup model repairs stale selections and reports progress',
    () async {
      final service = TestValSvc.fromRows([
        [...activeSheetFixedColumns, 'Week 2', '', 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2', 'S1'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          '',
          '',
          'Legs',
          '',
          '225x5@8',
          '',
          '',
        ],
        [
          'Leg Press',
          '3',
          '10',
          '8',
          '2 min',
          '',
          '',
          '',
          'Legs',
          'TRUE',
          '',
          '180x10@8',
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
          '',
          'Upper',
          '',
          '',
          '',
          '',
        ],
      ]);
      final controller = AppCtrl(svc: service);

      await controller.validateSelection('spreadsheet-id');
      controller.selectWorkout('Missing');
      controller.selectHistoryBlock('Missing');

      final setup = controller.workoutSetup;

      expect(setup, isNotNull);
      expect(setup!.selectedWorkout, 'Legs');
      expect(setup.selectedHistoryBlock, 'Week 2');
      expect(setup.overview?.workout, 'Legs');
      expect(setup.overview?.slots.single.exercise, 'Squat');
      expect(setup.progressByWorkout['Legs']?.done, 1);
      expect(setup.progressByWorkout['Legs']?.total, 1);
      expect(setup.progressByWorkout['Legs']?.label, '(1/1 done)');
      expect(setup.progressByWorkout['Upper']?.done, 0);
      expect(setup.progressByWorkout['Upper']?.total, 1);
    },
  );

  test('workout setup model repairs stale logging row targets', () async {
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ['Leg Press', '3', '10', '8', '2 min', '', '', '', 'Legs', 'TRUE', ''],
    ]);
    final controller = AppCtrl(svc: service);

    await controller.validateSelection('spreadsheet-id');
    controller.openExercise(3);
    controller.selectLoggingRow(99);

    final target = controller.workoutSetup?.loggingTarget;

    expect(target, isNotNull);
    expect(target?.blockLabel, 'Week 1');
    expect(target?.primaryRow, 3);
    expect(target?.selectedRow, 3);
  });

  test(
    'creates a history block and preserves the current workout when it still exists',
    () async {
      final service = TestValSvc.fromRows([
        [...activeSheetFixedColumns, 'Week 2'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '225x5@8'],
        ['Plank', '3', '45s', '8', '60s', '', '', '', '', '', '45s@8'],
      ]);
      final controller = AppCtrl(svc: service);

      await controller.validateSelection('spreadsheet-id');
      controller.selectWorkout('Legs');

      final created = await controller.createHistoryBlock('Week 3');
      final setup = controller.workoutSetup;

      expect(created, isTrue);
      expect(setup?.selectedWorkout, 'Legs');
      expect(setup?.selectedHistoryBlock, 'Week 3');
      expect(
        controller.report?.activeSheet.historyBlocks.map(
          (block) => block.label,
        ),
        contains('Week 3'),
      );
      expect(service.appliedPlans, hasLength(1));
      expect(service.appliedPlans.single.columnInsertions.single.headers, [
        'Week 3',
      ]);
    },
  );

  test(
    'deletes a workout exercise and preserves usable workout and history selections',
    () async {
      final service = TestValSvc.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '225x5@8'],
        [
          'Leg Press',
          '3',
          '10',
          '8',
          '2 min',
          '',
          '',
          '',
          'Legs',
          'TRUE',
          '10@8',
        ],
        ['Lunge', '2', '10', '7', '90s', '', '', '', 'Legs', '', '50x10@7'],
      ]);
      final controller = AppCtrl(svc: service);

      await controller.validateSelection('spreadsheet-id');

      final deleted = await controller.deleteWorkoutExercise(primaryRow: 3);
      final setup = controller.workoutSetup;

      expect(deleted, isTrue);
      expect(service.appliedPlans.single.rowDeletions, const [
        RowDeletion(sheetRowNumber: 3, rowCount: 2),
      ]);
      expect(setup?.selectedWorkout, 'Legs');
      expect(setup?.selectedHistoryBlock, 'Week 1');
      expect(setup?.overview?.slots.map((slot) => slot.exercise), ['Lunge']);
      expect(controller.error, isNull);
    },
  );

  test(
    'blocks duplicate history block labels before applying a write',
    () async {
      final service = TestValSvc.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ]);
      final controller = AppCtrl(svc: service);

      await controller.validateSelection('spreadsheet-id');

      final created = await controller.createHistoryBlock(' Week 1 ');

      expect(created, isFalse);
      expect(controller.error, 'History block Week 1 already exists.');
      expect(service.appliedPlans, isEmpty);
      expect(controller.workoutSetup, isNotNull);
    },
  );

  test('routes to validation when a set write target is rejected', () async {
    final visibleSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          [...activeSheetFixedColumns, 'Week 1'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
          ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
        ],
      ),
    );
    final changedSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          [...activeSheetFixedColumns, 'Week 1'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
          ['Deadlift', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
        ],
      ),
    );
    final service = _ScriptedAccess([visibleSheet, changedSheet]);
    final controller = AppCtrl(svc: service);

    await controller.validateSelection('spreadsheet-id');
    final saved = await controller.execute(
      SaveSetCmd(
        blockLabel: 'Week 1',
        sheetRow: 3,
        fields: const {'Weight': '225', 'Reps': '5', 'RPE': '8'},
      ),
    );

    expect(saved, isTrue);
    expect(controller.report?.hasBlockingIssues, isTrue);
    expect(controller.workoutSetup, isNull);
    expect(service.appliedPlans, isEmpty);
  });

  test(
    'rejects a logged next-set save when refresh does not retain the set',
    () async {
      final visibleSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [...activeSheetFixedColumns, 'Today', ''],
            [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
            [
              'Lat Pulldown',
              '2',
              '10',
              '8',
              '2 min',
              '',
              '',
              '',
              'Pull Day',
              '',
              '100x10@8',
              '',
            ],
          ],
        ),
      );
      final service = _ScriptedAccess([visibleSheet, visibleSheet]);
      final controller = AppCtrl(svc: service);

      await controller.validateSelection('spreadsheet-id');
      controller.openExercise(3);
      final plan = visibleSheet.planSetLoggingWrite(
        blockLabel: 'Today',
        sheetRowNumber: 3,
        fieldValues: const {'Weight': '105', 'Reps': '9', 'RPE': '9'},
      );

      final saved = await controller.execute(
        SaveSetCmd(
          blockLabel: 'Today',
          sheetRow: 3,
          fields: const {'Weight': '105', 'Reps': '9', 'RPE': '9'},
        ),
      );
      final context = controller.report!.activeSheet.buildLoggingContext(
        primaryRow: 3,
        selectedRow: 3,
        blockLabel: 'Today',
      );

      expect(saved, isFalse);
      expect(
        controller.error,
        'Unable to save set: saved set was not visible after refresh.',
      );
      expect(context.selectedHistory.entries[1].rawValue, isEmpty);
      expect(service.appliedPlans, [plan]);
    },
  );

  test(
    'confirms a logged next-set save after several stale post-write refreshes',
    () async {
      final staleRows = [
        [...activeSheetFixedColumns, 'Today', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
        [
          'Lat Pulldown',
          '2',
          '10',
          '8',
          '2 min',
          '',
          '',
          '',
          'Pull Day',
          '',
          '100x10@8',
          '',
        ],
      ];
      final freshRows = [
        [...activeSheetFixedColumns, 'Today', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
        [
          'Lat Pulldown',
          '2',
          '10',
          '8',
          '2 min',
          '',
          '',
          '',
          'Pull Day',
          '',
          '100x10@8',
          '105x9@9',
        ],
      ];
      final staleSheet = parseActiveSheet(ActiveSheetInput(rows: staleRows));
      final freshSheet = parseActiveSheet(ActiveSheetInput(rows: freshRows));
      final service = _ScriptedAccess([
        staleSheet,
        staleSheet,
        staleSheet,
        staleSheet,
        staleSheet,
        freshSheet,
      ]);
      final controller = AppCtrl(svc: service);

      await controller.validateSelection('spreadsheet-id');
      controller.openExercise(3);
      final plan = staleSheet.planSetLoggingWrite(
        blockLabel: 'Today',
        sheetRowNumber: 3,
        fieldValues: const {'Weight': '105', 'Reps': '9', 'RPE': '9'},
      );

      final saved = await controller.execute(
        SaveSetCmd(
          blockLabel: 'Today',
          sheetRow: 3,
          fields: const {'Weight': '105', 'Reps': '9', 'RPE': '9'},
        ),
      );
      final context = controller.report!.activeSheet.buildLoggingContext(
        primaryRow: 3,
        selectedRow: 3,
        blockLabel: 'Today',
      );

      expect(saved, isTrue);
      expect(controller.error, isNull);
      expect(context.selectedHistory.entries[1].rawValue, '105x9@9');
      expect(service.appliedPlans, [plan]);
      expect(service.postWriteReadCount, 4);
    },
  );

  test(
    'rejects a logged next-set save when refresh shows a different set value',
    () async {
      final visibleSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [...activeSheetFixedColumns, 'Today', ''],
            [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
            [
              'Lat Pulldown',
              '2',
              '10',
              '8',
              '2 min',
              '',
              '',
              '',
              'Pull Day',
              '',
              '100x10@8',
              '',
            ],
          ],
        ),
      );
      final refreshedSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [...activeSheetFixedColumns, 'Today', ''],
            [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
            [
              'Lat Pulldown',
              '2',
              '10',
              '8',
              '2 min',
              '',
              '',
              '',
              'Pull Day',
              '',
              '100x10@8',
              '95x10@7',
            ],
          ],
        ),
      );
      final service = _ScriptedAccess([
        visibleSheet,
        visibleSheet,
        refreshedSheet,
      ]);
      final controller = AppCtrl(svc: service);

      await controller.validateSelection('spreadsheet-id');
      controller.openExercise(3);
      final plan = visibleSheet.planSetLoggingWrite(
        blockLabel: 'Today',
        sheetRowNumber: 3,
        fieldValues: const {'Weight': '105', 'Reps': '9', 'RPE': '9'},
      );

      final saved = await controller.execute(
        SaveSetCmd(
          blockLabel: 'Today',
          sheetRow: 3,
          fields: const {'Weight': '105', 'Reps': '9', 'RPE': '9'},
        ),
      );
      final context = controller.report!.activeSheet.buildLoggingContext(
        primaryRow: 3,
        selectedRow: 3,
        blockLabel: 'Today',
      );

      expect(saved, isFalse);
      expect(
        controller.error,
        'Unable to save set: saved set was not visible after refresh.',
      );
      expect(context.selectedHistory.entries[1].rawValue, isEmpty);
      expect(service.appliedPlans, [plan]);
    },
  );

  test(
    'repairs unambiguous formula issues with one flagged-cell write plan',
    () async {
      final damagedSheet = _parseWorkbookFixture(loadFormulaDamageFixture());
      final repairedSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: loadFormulaDamageFixture().activeSheet.rows,
          exercisesRows: loadFormulaDamageFixture().exercisesSheet.rows,
          cellFormulas: const [
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 1,
              formula: '=Exercises!A2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 2,
              formula: '=Exercises!C2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 3,
              formula: '=Exercises!D2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 4,
              formula: '=Exercises!E2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 5,
              formula: '=Exercises!F2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 6,
              formula: '=Exercises!G2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 7,
              formula: '=Exercises!H2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 8,
              formula: '=Exercises!I2',
            ),
          ],
        ),
      );
      final service = _ScriptedAccess([
        damagedSheet,
        damagedSheet,
        repairedSheet,
      ]);
      final controller = AppCtrl(svc: service);

      await controller.validateSelection('spreadsheet-id');

      final repaired = await controller.repairFormulas();

      expect(repaired, isTrue);
      expect(service.appliedPlans.single.cellUpdates, const [
        CellUpdate(
          valueKind: CellUpdateValueKind.formula,
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          value: '=Exercises!A2',
        ),
        CellUpdate(
          valueKind: CellUpdateValueKind.formula,
          sheetRowNumber: 3,
          sheetColumnNumber: 8,
          value: '=Exercises!I2',
        ),
      ]);
      expect(service.appliedPlans.single.expectations, isNotEmpty);
      expect(controller.report?.healingIssues, isEmpty);
      expect(controller.workoutSetup, isNotNull);
    },
  );

  test(
    'repairs an ambiguous formula issue after the user chooses an Exercises row',
    () async {
      final damagedSheet = _parseWorkbookFixture(
        loadAmbiguousFormulaRepairDamageFixture(),
      );
      final service = _ScriptedAccess([
        damagedSheet,
        damagedSheet,
        _parseWorkbookFixture(loadLocalWorkoutWorkbookFixture()),
      ]);
      final controller = AppCtrl(svc: service);

      await controller.validateSelection('spreadsheet-id');

      final repaired = await controller.repairFormulaIssue(
        activeSheetRowNumber: 3,
        selectedRow: 3,
      );

      expect(repaired, isTrue);
      expect(service.appliedPlans.single.cellUpdates, const [
        CellUpdate(
          valueKind: CellUpdateValueKind.formula,
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          value: '=Exercises!A3',
        ),
      ]);
      expect(service.appliedPlans.single.expectations, isNotEmpty);
    },
  );

  test(
    'repairs a no-match formula issue after the user chooses an Exercises row',
    () async {
      final damagedSheet = _parseWorkbookFixture(
        loadNoExactMatchFormulaRepairDamageFixture(),
      );
      final service = _ScriptedAccess([
        damagedSheet,
        damagedSheet,
        _parseWorkbookFixture(loadLocalWorkoutWorkbookFixture()),
      ]);
      final controller = AppCtrl(svc: service);

      await controller.validateSelection('spreadsheet-id');

      final repaired = await controller.repairFormulaIssue(
        activeSheetRowNumber: 3,
        selectedRow: 2,
      );

      expect(repaired, isTrue);
      expect(service.appliedPlans.single.cellUpdates, const [
        CellUpdate(
          valueKind: CellUpdateValueKind.formula,
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          value: '=Exercises!A2',
        ),
      ]);
      expect(service.appliedPlans.single.expectations, isNotEmpty);
    },
  );

  test(
    'blank spreadsheet selection reports a user error without calling the service',
    () async {
      final controller = AppCtrl(
        svc: TestValSvc.fromRows([
          [...activeSheetFixedColumns, 'Week 1'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
          ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
        ]),
      );

      final validated = await controller.validateSelection('   ');

      expect(validated, isFalse);
      expect(controller.error, 'Enter a Google Sheets URL or spreadsheet ID.');
      expect(controller.report, isNull);
      expect((controller.svc as TestValSvc).spreadsheetIds, isEmpty);
    },
  );

  test(
    'disabled Google Sheets API errors explain the project setup action',
    () async {
      final controller = AppCtrl(
        svc: _FailingAccess(
          'DetailedApiRequestError(status: 403, message: Google Sheets API '
          'has not been used in project 657151291920 before or it is disabled. '
          'Enable it by visiting https://console.developers.google.com/apis/'
          'api/sheets.googleapis.com/overview?project=657151291920 then retry.)',
        ),
      );

      final validated = await controller.validateSelection('spreadsheet-id');

      expect(validated, isFalse);
      expect(
        controller.error,
        'Unable to validate spreadsheet: Google Sheets API is disabled for '
        'Google Cloud project 657151291920. Enable the Google Sheets API, wait '
        'a few minutes for Google to propagate the change, then retry: '
        'https://console.cloud.google.com/apis/library/'
        'sheets.googleapis.com?project=657151291920',
      );
    },
  );

  test(
    'pending history block creation can complete after controller disposal',
    () async {
      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [...activeSheetFixedColumns, 'Week 1'],
            [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
            ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
          ],
        ),
      );
      final writeCompleter = Completer<void>();
      final service = _ScriptedAccess([
        activeSheet,
        activeSheet,
        activeSheet,
      ], writeFuture: writeCompleter.future);
      final controller = AppCtrl(svc: service);

      await controller.validateSelection('spreadsheet-id');

      final createFuture = controller.createHistoryBlock('Week 2');
      controller.dispose();
      writeCompleter.complete();

      await expectLater(createFuture, completion(isTrue));
    },
  );
}

class _ScriptedAccess implements WbkAccess {
  _ScriptedAccess(Iterable<ParsedActiveSheet> sheets, {this.writeFuture})
    : _io = _ScriptedIo(sheets);

  final _ScriptedIo _io;
  final Future<void>? writeFuture;

  List<ActiveSheetWritePlan> get appliedPlans => _io.appliedPlans;

  int get postWriteReadCount => _io.postWriteReadCount;

  @override
  WbkSess open(String sheetId) {
    _io.writeFuture = writeFuture;
    return ValSess(sheetId: sheetId, io: _io);
  }
}

class _ScriptedIo implements WbkIo {
  _ScriptedIo(Iterable<ParsedActiveSheet> sheets) : _sheets = sheets.toList();

  final List<ParsedActiveSheet> _sheets;
  final List<ActiveSheetWritePlan> appliedPlans = [];
  Future<void>? writeFuture;
  var _readCount = 0;
  int? _writeReadCount;

  int get postWriteReadCount {
    final writeReadCount = _writeReadCount;
    return writeReadCount == null ? 0 : _readCount - writeReadCount;
  }

  @override
  Future<ParsedActiveSheet> read() async {
    final i = _readCount++;
    return i < _sheets.length ? _sheets[i] : _sheets.last;
  }

  @override
  Future<void> writeActive(ActiveSheetWritePlan plan) async {
    appliedPlans.add(plan);
    _writeReadCount = _readCount;
    await writeFuture;
  }

  @override
  Future<void> writeExercises(ExercisesWritePlan plan) async {
    throw UnimplementedError();
  }
}

class _FailingAccess implements WbkAccess {
  const _FailingAccess(this.message);

  final String message;

  @override
  WbkSess open(String sheetId) => _FailingSess(sheetId, message);
}

class _FailingSess implements WbkSess {
  const _FailingSess(this.sheetId, this.message);

  @override
  final String sheetId;
  final String message;

  @override
  Future<ValReport> read() => Future.error(StateError(message));

  @override
  Future<ValReport> execute(WbkCmd cmd) => throw UnimplementedError();
}

ParsedActiveSheet _parseWorkbookFixture(WorkoutWorkbookFixture fixture) {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: fixture.activeSheet.rows,
      mergedFirstColumnRows: fixture.activeSheet.mergedFirstColumnRows,
      cellFormulas: fixture.activeSheet.cellFormulas.map(
        (formula) => CellFormula(
          sheetRowNumber: formula.sheetRowNumber,
          sheetColumnNumber: formula.sheetColumnNumber,
          formula: formula.formula,
        ),
      ),
      exercisesRows: fixture.exercisesSheet.rows,
    ),
  );
}
