import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';

import 'service_fake.dart';

void main() {
  test(
    'applies write plans through the spreadsheet validation interface and reparses rows',
    () async {
      final service = TestValSvc.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ]);

      final firstReport = await service.validateSheet('spreadsheet-id');
      final overview = firstReport.activeSheet.buildWorkoutOverview(
        workout: 'Legs',
        blockLabel: 'Week 1',
      );
      final plan = firstReport.activeSheet.planSetLoggingWrite(
        blockLabel: 'Week 1',
        sheetRowNumber: overview.slots.single.sheetRowNumber,
        fieldValues: {'Weight': '225', 'Reps': '5', 'RPE': '8'},
      );

      final updatedReport = await service.applyWritePlan(
        spreadsheetId: firstReport.sheetId,
        activeSheet: firstReport.activeSheet,
        plan: plan,
      );

      expect(service.spreadsheetIds, ['spreadsheet-id']);
      expect(service.appliedPlans, [plan]);
      expect(
        updatedReport.activeSheet
            .buildLoggingContext(
              primaryRow: overview.slots.single.sheetRowNumber,
              selectedRow: overview.slots.single.sheetRowNumber,
              blockLabel: 'Week 1',
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
