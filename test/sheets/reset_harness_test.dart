import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheets.dart';
import 'package:workout_tracker/contract.dart';

import '../support/reset.dart'
    show DevelopmentSheetResetHarness, workoutTrackerDevelopmentSpreadsheetId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'resets only the known development spreadsheet to a deterministic fixture',
    () async {
      final initializer = _FakeWorkbookInitializer();
      final harness = DevelopmentSheetResetHarness(initializer: initializer);

      await harness.reset();

      expect(initializer.initializedSpreadsheetIds, [
        workoutTrackerDevelopmentSpreadsheetId,
      ]);
      final workbook = initializer.workbooks.single;
      expect(workbook.activeSheet.title, 'Active Workout');
      expect(workbook.exercisesSheet.title, 'Exercises');

      final activeRows = workbook.activeSheet.rows;
      expect(activeRows, [activeSheetFixedColumns]);
      final parsedActiveSheet = parseActiveSheet(
        ActiveSheetInput(rows: activeRows),
      );

      expect(parsedActiveSheet.schemaViolations, isEmpty);
      expect(parsedActiveSheet.primarySlots, isEmpty);
      expect(parsedActiveSheet.historyBlocks, isEmpty);

      final exercisesRows = workbook.exercisesSheet.rows;
      expect(exercisesRows.first, [
        'Exercise',
        'Description',
        'Default Sets',
        'Default Reps',
        'Default RPE',
        'Default Rest',
        'Default Tempo',
        'Notes',
        'Log Format',
      ]);
      final exerciseNames = exercisesRows.skip(1).map((row) => row.first);
      expect(exerciseNames, everyElement(allOf(isA<String>(), isNotEmpty)));
      expect(exerciseNames.toSet(), hasLength(exercisesRows.length - 1));
      expect(
        exercisesRows.skip(1),
        everyElement(hasLength(exercisesRows.first.length)),
      );
      expect(
        exercisesRows.skip(1).map((row) => parseLogFormat(row[8])),
        everyElement(isA<ParsedLogFormat>()),
      );
      expect(
        activeRows.skip(1).where((row) => row.any((cell) => cell.isNotEmpty)),
        isEmpty,
      );
    },
  );

  test('rejects non-development spreadsheet IDs by default', () async {
    final harness = DevelopmentSheetResetHarness(
      initializer: _FakeWorkbookInitializer(),
    );

    expect(
      () => harness.reset(spreadsheetId: 'unrelated-spreadsheet'),
      throwsArgumentError,
    );
  });

  test(
    'plans workbook seeding through workbook operations and keeps formatting requests local',
    () {
      final tab = WorkbookTab(
        title: 'Active Workout',
        rows: [
          ['Exercise', 'Tempo', 'History'],
          ['=Exercises!A2', '3-1-1', ''],
          ['Timed Drill', '45s', '12-15'],
        ],
      );

      final plan = WorkbookTabPlan(sheetId: 42, tab: tab, frozenRowCount: 1);

      final textFormatRequest = plan.requests.singleWhere(
        (request) =>
            request.repeatCell?.fields == 'userEnteredFormat.numberFormat',
      );
      expect(
        textFormatRequest
            .repeatCell
            ?.cell
            ?.userEnteredFormat
            ?.numberFormat
            ?.type,
        'TEXT',
      );
      expect(textFormatRequest.repeatCell?.range?.sheetId, 42);
      expect(textFormatRequest.repeatCell?.range?.startRowIndex, 0);
      expect(textFormatRequest.repeatCell?.range?.endRowIndex, 50);
      expect(textFormatRequest.repeatCell?.range?.startColumnIndex, 0);
      expect(textFormatRequest.repeatCell?.range?.endColumnIndex, 3);

      expect(
        plan.requests.where((request) => request.updateCells != null),
        isEmpty,
      );
      expect(
        [
          for (final operation in plan.operations)
            if (operation is SheetsCellWrite)
              (
                operation.sheet.sheetId,
                operation.sheet.title,
                operation.sheetRowNumber,
                operation.sheetColumnNumber,
                operation.value,
                operation.mode,
              ),
        ],
        [
          (
            42,
            'Active Workout',
            1,
            1,
            'Exercise',
            SheetsValueInputMode.literalText,
          ),
          (
            42,
            'Active Workout',
            1,
            2,
            'Tempo',
            SheetsValueInputMode.literalText,
          ),
          (
            42,
            'Active Workout',
            1,
            3,
            'History',
            SheetsValueInputMode.literalText,
          ),
          (
            42,
            'Active Workout',
            2,
            1,
            '=Exercises!A2',
            SheetsValueInputMode.userEntered,
          ),
          (
            42,
            'Active Workout',
            2,
            2,
            '3-1-1',
            SheetsValueInputMode.literalText,
          ),
          (
            42,
            'Active Workout',
            3,
            1,
            'Timed Drill',
            SheetsValueInputMode.literalText,
          ),
          (42, 'Active Workout', 3, 2, '45s', SheetsValueInputMode.literalText),
          (
            42,
            'Active Workout',
            3,
            3,
            '12-15',
            SheetsValueInputMode.literalText,
          ),
        ],
      );
    },
  );
}

class _FakeWorkbookInitializer implements WorkbookInit {
  final initializedSpreadsheetIds = <String>[];
  final workbooks = <Workbook>[];

  @override
  Future<void> initializeWorkbook({
    required String spreadsheetId,
    required Workbook workbook,
  }) async {
    initializedSpreadsheetIds.add(spreadsheetId);
    workbooks.add(workbook);
  }
}
