import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  test(
    'validates a spreadsheet selection and adopts workout and history ordering',
    () async {
      final service = _FakeSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 2', '', 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2', 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', '', '', '', ''],
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
          '',
          '',
          '',
        ],
      ]);
      final controller = WorkoutTrackerController(validationService: service);

      controller.openExercise(99);

      final validated = await controller.validateSpreadsheetSelection(
        'https://docs.google.com/spreadsheets/d/spreadsheet-id/edit?gid=0#gid=0',
      );

      expect(validated, isTrue);
      expect(service.spreadsheetIds, ['spreadsheet-id']);
      expect(controller.report?.spreadsheetId, 'spreadsheet-id');
      expect(controller.selectedWorkout, 'Legs');
      expect(controller.selectedHistoryBlock, 'Week 2');
      expect(controller.loggingPrimarySheetRowNumber, isNull);
      expect(controller.selectedLoggingSheetRowNumber, isNull);
      expect(controller.error, isNull);
    },
  );

  test(
    'changing workout or history clears the current logging selection',
    () async {
      final service = _FakeSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 2', '', 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2', 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', '', '', '', ''],
        [
          'Leg Press',
          '3',
          '10',
          '8',
          '2 min',
          '',
          '',
          'Legs',
          'TRUE',
          '',
          '',
          '',
        ],
        ['Plank', '3', '45s', '8', '60s', '', '', '', '', '', '', ''],
      ]);
      final controller = WorkoutTrackerController(validationService: service);

      await controller.validateSpreadsheetSelection('spreadsheet-id');
      controller.openExercise(3);
      controller.selectLoggingRow(4);

      controller.selectHistoryBlock('Week 1');
      expect(controller.loggingPrimarySheetRowNumber, isNull);
      expect(controller.selectedLoggingSheetRowNumber, isNull);

      controller.openExercise(3);
      controller.selectLoggingRow(4);
      controller.selectWorkout(defaultWorkoutName);

      expect(controller.loggingPrimarySheetRowNumber, isNull);
      expect(controller.selectedLoggingSheetRowNumber, isNull);
    },
  );

  test(
    'creates a history block and preserves the current workout when it still exists',
    () async {
      final service = _FakeSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 2'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', '', '225x5@8'],
        ['Plank', '3', '45s', '8', '60s', '', '', '', '', '45s@8'],
      ]);
      final controller = WorkoutTrackerController(validationService: service);

      await controller.validateSpreadsheetSelection('spreadsheet-id');
      controller.selectWorkout('Legs');

      final created = await controller.createHistoryBlock('Week 3');

      expect(created, isTrue);
      expect(controller.selectedWorkout, 'Legs');
      expect(controller.selectedHistoryBlock, 'Week 3');
      expect(
        controller.report?.activeSheet.historyBlocks.map(
          (block) => block.label,
        ),
        contains('Week 3'),
      );
      expect(service.createdHistoryBlockLabels, ['Week 3']);
    },
  );

  test(
    'blank spreadsheet selection reports a user error without calling the service',
    () async {
      final controller = WorkoutTrackerController(
        validationService: _FakeSpreadsheetValidationService.fromRows([
          [...activeSheetFixedColumns, 'Week 1'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
          ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', '', ''],
        ]),
      );

      final validated = await controller.validateSpreadsheetSelection('   ');

      expect(validated, isFalse);
      expect(controller.error, 'Enter a Google Sheets URL or spreadsheet ID.');
      expect(controller.report, isNull);
      expect(
        (controller.validationService as _FakeSpreadsheetValidationService)
            .spreadsheetIds,
        isEmpty,
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
            ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', '', ''],
          ],
        ),
      );
      final createCompleter = Completer<SpreadsheetValidationReport>();
      final service = _PendingCreateHistoryBlockService(
        activeSheet: activeSheet,
        createCompleter: createCompleter,
      );
      final controller = WorkoutTrackerController(validationService: service);

      await controller.validateSpreadsheetSelection('spreadsheet-id');

      final createFuture = controller.createHistoryBlock('Week 2');
      controller.dispose();
      createCompleter.complete(
        SpreadsheetValidationReport(
          spreadsheetId: 'spreadsheet-id',
          activeSheet: activeSheet,
        ),
      );

      await expectLater(createFuture, completion(isTrue));
    },
  );
}

class _PendingCreateHistoryBlockService
    implements SpreadsheetValidationService {
  _PendingCreateHistoryBlockService({
    required this.activeSheet,
    required this.createCompleter,
  });

  final ParsedActiveSheet activeSheet;
  final Completer<SpreadsheetValidationReport> createCompleter;

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
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
  }) {
    return createCompleter.future;
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) {
    throw UnimplementedError();
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
