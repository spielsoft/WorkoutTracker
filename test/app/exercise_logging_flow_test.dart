import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  test(
    'switching rows refreshes row-local controllers and plans selected-row writes',
    () {
      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [
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
          ],
        ),
      );
      final flow = ExerciseLoggingFlow(
        activeSheet: activeSheet,
        historyBlockLabel: 'Week 1',
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 3,
      );
      addTearDown(flow.dispose);

      expect(flow.viewModel.selectedChoice.exercise, 'Pull Up');
      expect(flow.viewModel.newSetControllers.keys, ['Reps']);
      expect(flow.viewModel.loggedEntries.single.setLabel, 'S1');
      expect(flow.viewModel.loggedFormattedControllers[1]?['Reps']?.text, '12');

      flow.update(
        activeSheet: activeSheet,
        historyBlockLabel: 'Week 1',
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 4,
      );

      expect(flow.viewModel.selectedChoice.exercise, 'Front Plank');
      expect(flow.viewModel.newSetControllers.keys, ['Seconds', 'RPE']);
      expect(
        flow.viewModel.loggedFormattedControllers[1]?['Seconds']?.text,
        '45',
      );
      expect(flow.viewModel.loggedFormattedControllers[1]?['RPE']?.text, '8');
      expect(flow.viewModel.loggedFormattedControllers[1]?['Reps'], isNull);

      flow.viewModel.newSetControllers['Seconds']?.text = '60';
      flow.viewModel.newSetControllers['RPE']?.text = '9';

      final plan = flow.planStructuredSetSave();

      expect(plan?.columnInsertions.single.setLabels, ['S2']);
      expect(
        plan?.cellUpdates.single,
        const CellUpdate(
          sheetRowNumber: 4,
          sheetColumnNumber: 12,
          value: '60s@9',
        ),
      );
    },
  );

  test(
    'plans structured edits, raw edits, and clears through the active sheet',
    () {
      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [...activeSheetFixedColumns, 'Week 1', ''],
            [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
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
              '',
              '45s@8',
              'manual note',
            ],
          ],
        ),
      );
      final flow = ExerciseLoggingFlow(
        activeSheet: activeSheet,
        historyBlockLabel: 'Week 1',
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 3,
      );
      addTearDown(flow.dispose);

      final formattedEntry = flow.viewModel.loggedEntries.singleWhere(
        (entry) => entry.setNumber == 1,
      );
      final rawEntry = flow.viewModel.loggedEntries.singleWhere(
        (entry) => entry.setNumber == 2,
      );

      expect(
        () => flow.viewModel.loggedEntries.clear(),
        throwsUnsupportedError,
      );

      flow.viewModel.loggedFormattedControllers[1]?['Seconds']?.text = '50';
      flow.viewModel.rawControllers[2]?.text = 'skip, mat busy';

      expect(
        flow.planStructuredSetEdit(formattedEntry)?.cellUpdates.single,
        const CellUpdate(
          sheetRowNumber: 3,
          sheetColumnNumber: 11,
          value: '50s@8',
        ),
      );
      expect(
        flow.planRawSetEdit(rawEntry).cellUpdates.single,
        const CellUpdate(
          sheetRowNumber: 3,
          sheetColumnNumber: 12,
          value: 'skip, mat busy',
        ),
      );
      expect(
        flow.planSetClear(formattedEntry).cellUpdates.single,
        const CellUpdate(sheetRowNumber: 3, sheetColumnNumber: 11, value: ''),
      );
    },
  );
}
