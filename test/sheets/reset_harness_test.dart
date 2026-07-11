import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheets.dart';
import 'package:workout_tracker/contract.dart';

import '../support/reset.dart'
    show
        DevelopmentSheetResetFailure,
        DevelopmentSheetResetHarness,
        workoutTrackerDevelopmentSpreadsheetId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'resets only the known development spreadsheet to a deterministic fixture',
    () async {
      final initializer = _FakeWbkInit();
      final harness = DevelopmentSheetResetHarness(initializer: initializer);

      await harness.reset();

      expect(initializer.initializedSpreadsheetIds, [
        workoutTrackerDevelopmentSpreadsheetId,
      ]);
      final workbook = initializer.workbooks.single;
      expect(workbook.activeSheet.title, 'Active Workout');
      expect(workbook.exercisesSheet.title, 'Exercises');

      final activeRows = workbook.activeSheet.rows;
      expect(activeRows.first, [...activeSheetFixedColumns, 'Week 1']);
      expect(activeRows[1].last, 'S1');
      expect(activeRows[2][0], '=Exercises!A2');
      expect(activeRows[2][7], '=Exercises!I2');
      expect(activeRows[2].last, isEmpty);

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
    },
  );

  test('rejects non-development spreadsheet IDs by default', () async {
    final harness = DevelopmentSheetResetHarness(initializer: _FakeWbkInit());

    expect(
      () => harness.reset(spreadsheetId: 'unrelated-spreadsheet'),
      throwsArgumentError,
    );
  });

  test('reports fixture reset failure distinctly', () async {
    final harness = DevelopmentSheetResetHarness(
      initializer: _FailingWbkInit(),
    );

    await expectLater(
      harness.reset(),
      throwsA(
        isA<DevelopmentSheetResetFailure>().having(
          (error) => error.toString(),
          'message',
          contains('Development sheet reset failed'),
        ),
      ),
    );
  });

  test(
    'plans workbook seeding through workbook operations and keeps formatting requests local',
    () {
      final tab = WbkTab(
        title: 'Active Workout',
        rows: [
          ['Exercise', 'Tempo', 'History'],
          ['=Exercises!A2', '3-1-1', ''],
          ['Timed Drill', '45s', '12-15'],
        ],
      );

      final plan = WbkTabPlan(sheetId: 42, tab: tab, frozenRowCount: 1);

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

class _FakeWbkInit implements WbkInit {
  final initializedSpreadsheetIds = <String>[];
  final workbooks = <Wbk>[];

  @override
  Future<void> initializeWorkbook({
    required String spreadsheetId,
    required Wbk workbook,
  }) async {
    initializedSpreadsheetIds.add(spreadsheetId);
    workbooks.add(workbook);
  }
}

class _FailingWbkInit implements WbkInit {
  @override
  Future<void> initializeWorkbook({
    required String spreadsheetId,
    required Wbk workbook,
  }) async {
    throw StateError('fixture unavailable');
  }
}
