import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'test_spreadsheet_validation_service.dart';

void main() {
  test(
    'applies write plans through the spreadsheet validation interface and reparses rows',
    () async {
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ]);

      final firstReport = await service.validateSpreadsheet('spreadsheet-id');
      final overview = firstReport.activeSheet.buildWorkoutOverview(
        workout: 'Legs',
        historyBlockLabel: 'Week 1',
      );
      final plan = firstReport.activeSheet.planSetLoggingWrite(
        historyBlockLabel: 'Week 1',
        sheetRowNumber: overview.slots.single.sheetRowNumber,
        fieldValues: {'Weight': '225', 'Reps': '5', 'RPE': '8'},
      );

      final updatedReport = await service.applyWritePlan(
        spreadsheetId: firstReport.spreadsheetId,
        activeSheet: firstReport.activeSheet,
        plan: plan,
      );

      expect(service.spreadsheetIds, ['spreadsheet-id']);
      expect(service.appliedPlans, [plan]);
      expect(
        updatedReport.activeSheet
            .buildLoggingContext(
              primarySheetRowNumber: overview.slots.single.sheetRowNumber,
              selectedSheetRowNumber: overview.slots.single.sheetRowNumber,
              historyBlockLabel: 'Week 1',
            )
            .selectedHistory
            .entries
            .single
            .rawValue,
        '225x5@8',
      );
    },
  );
}
