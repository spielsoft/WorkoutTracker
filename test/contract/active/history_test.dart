import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';

import 'helpers.dart';

void main() {
  test('discovers visible history blocks and their ordered sets', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow(['Week 2', '', 'Week 1']),
          setLabelRow(['S1', 'S2', 'S1']),
          activeRow('Squat', history: const ['', '', '225x5@8']),
        ],
      ),
    );

    expect(sheet.historyBlocks.map((block) => block.label), [
      'Week 2',
      'Week 1',
    ]);
    expect(
      sheet
          .selectHistoryBlock('Week 2')!
          .setColumns
          .map((column) => column.label),
      ['S1', 'S2'],
    );
  });

  test('plans a new history block after fixed metadata', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(rows: [historyHeaderRow([]), setLabelRow([])]),
    );

    final plan = sheet.planNewHistoryBlock(label: 'Week 1');
    expect(plan.columnInsertions.single.sheetColumnNumber, 11);
    expect(plan.columnInsertions.single.headers, ['Week 1']);
    expect(plan.columnInsertions.single.setLabels, ['S1']);
  });
}
