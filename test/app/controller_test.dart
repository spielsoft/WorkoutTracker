import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

import 'service_fake.dart';

void main() {
  test(
    'adopts workbook workout and history ordering after validation',
    () async {
      final service = TestValSvc.fromRows([
        [...activeSheetFixedColumns, 'Week 2', 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1'],
        _row('Squat', workout: 'Legs', history: const ['', '225x5@8']),
        _row('Bench Press', workout: 'Upper', history: const ['', '135x8@8']),
      ]);
      final controller = AppCtrl(svc: service);

      expect(await controller.validateSelection('spreadsheet-id'), isTrue);
      expect(controller.workoutSetup?.selectedWorkout, 'Legs');
      expect(controller.workoutSetup?.selectedHistoryBlock, 'Week 2');
      expect(controller.error, isNull);
    },
  );

  test(
    'discards a validation result superseded by a newer selection',
    () async {
      final access = _DelayedAccess();
      final controller = AppCtrl(svc: access);
      final first = controller.validateSelection('first');
      final second = controller.validateSelection('second');

      access.complete('second', _report('second', 'Deadlift'));
      expect(await second, isTrue);
      access.complete('first', _report('first', 'Squat'));
      expect(await first, isFalse);
      expect(controller.report?.sheetId, 'second');
    },
  );

  test(
    'keeps an emptied workout selected after deleting its last row',
    () async {
      final service = TestValSvc.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        _row('Squat', workout: 'Legs', history: const ['225x5@8']),
        _row('Bench Press', workout: 'Upper', history: const ['135x8@8']),
      ]);
      final controller = AppCtrl(svc: service);
      await controller.validateSelection('spreadsheet-id');
      controller.selectWorkout('Upper');

      expect(await controller.deleteWorkoutExercise(primaryRow: 4), isTrue);
      expect(controller.workoutSetup?.selectedWorkout, 'Upper');
      expect(controller.workoutSetup?.overview?.slots, isEmpty);
    },
  );

  test('blocks duplicate history labels before writing', () async {
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      _row('Squat', workout: 'Legs', history: const ['']),
    ]);
    final controller = AppCtrl(svc: service);
    await controller.validateSelection('spreadsheet-id');

    expect(await controller.createHistoryBlock(' Week 1 '), isFalse);
    expect(service.appliedPlans, isEmpty);
  });
}

List<String> _row(
  String exercise, {
  required String workout,
  required List<String> history,
}) => [
  exercise,
  '3',
  '2 min',
  '2-1-1',
  'x8@8',
  '',
  '',
  workout,
  '',
  'x',
  ...history,
];

class _DelayedAccess implements WbkAccess {
  final _reads = <String, Completer<ValReport>>{};

  @override
  WbkSess open(String sheetId) {
    final completer = Completer<ValReport>();
    _reads[sheetId] = completer;
    return _DelayedSess(sheetId, completer.future);
  }

  void complete(String sheetId, ValReport report) {
    _reads[sheetId]!.complete(report);
  }
}

class _DelayedSess implements WbkSess {
  const _DelayedSess(this.sheetId, this.report);

  @override
  final String sheetId;
  final Future<ValReport> report;

  @override
  Future<ValReport> read() => report;

  @override
  Future<ValReport> execute(WbkCmd cmd) => throw UnimplementedError();
}

ValReport _report(String sheetId, String exercise) {
  return ValReport(
    spreadsheetId: sheetId,
    activeSheet: parseActiveSheet(
      ActiveSheetInput(
        rows: [
          activeSheetFixedColumns,
          _row(exercise, workout: 'Default', history: const []),
        ],
      ),
    ),
  );
}
