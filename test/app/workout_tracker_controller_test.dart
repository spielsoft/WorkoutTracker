import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

import 'test_spreadsheet_validation_service.dart';

void main() {
  test(
    'validates a spreadsheet selection and adopts workout and history ordering',
    () async {
      final service = TestSpreadsheetValidationService.fromRows([
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
      final service = TestSpreadsheetValidationService.fromRows([
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
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 2'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '225x5@8'],
        ['Plank', '3', '45s', '8', '60s', '', '', '', '', '', '45s@8'],
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
        validationService: TestSpreadsheetValidationService.fromRows([
          [...activeSheetFixedColumns, 'Week 1'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
          ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
        ]),
      );

      final validated = await controller.validateSpreadsheetSelection('   ');

      expect(validated, isFalse);
      expect(controller.error, 'Enter a Google Sheets URL or spreadsheet ID.');
      expect(controller.report, isNull);
      expect(
        (controller.validationService as TestSpreadsheetValidationService)
            .spreadsheetIds,
        isEmpty,
      );
    },
  );

  test(
    'disabled Google Sheets API errors explain the project setup action',
    () async {
      final controller = WorkoutTrackerController(
        validationService: _FailingSpreadsheetValidationService(
          'DetailedApiRequestError(status: 403, message: Google Sheets API '
          'has not been used in project 657151291920 before or it is disabled. '
          'Enable it by visiting https://console.developers.google.com/apis/'
          'api/sheets.googleapis.com/overview?project=657151291920 then retry.)',
        ),
      );

      final validated = await controller.validateSpreadsheetSelection(
        'spreadsheet-id',
      );

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

class _FailingSpreadsheetValidationService
    implements SpreadsheetValidationService {
  const _FailingSpreadsheetValidationService(this.message);

  final String message;

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) {
    throw StateError(message);
  }

  @override
  Future<SpreadsheetValidationReport> createHistoryBlock({
    required String spreadsheetId,
    required String label,
    required ParsedActiveSheet activeSheet,
  }) {
    throw UnimplementedError();
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
