import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';

import '../fixtures/workout_sheet_fixtures.dart';
import 'active_sheet_test_helpers.dart';

void main() {
  test('discovers visible history block labels in sheet order', () {
    final activeSheet = parseFixtureActiveSheet();

    expect(activeSheet.historyBlocks.map((block) => block.label), [
      'Week 2',
      'Week 1',
    ]);
  });

  test('selects an existing history block and exposes its set columns', () {
    final activeSheet = parseFixtureActiveSheet();

    final newestBlock = activeSheet.selectHistoryBlock('Week 2');
    final previousBlock = activeSheet.selectHistoryBlock('Week 1');

    expect(newestBlock?.label, 'Week 2');
    expect(newestBlock?.setColumns.map((column) => column.label), ['S1', 'S2']);
    expect(newestBlock?.setColumns.map((column) => column.sheetColumnNumber), [
      10,
      11,
    ]);
    expect(previousBlock?.setColumns.map((column) => column.label), [
      'S1',
      'S2',
      'S3',
    ]);
  });

  test('treats history block labels as plain visible labels', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow(['Session A', '2026-06-14']),
          setLabelRow(['S1', 'S1']),
          ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', '', '', ''],
        ],
      ),
    );

    expect(activeSheet.historyBlocks.map((block) => block.label), [
      'Session A',
      '2026-06-14',
    ]);
    expect(
      activeSheet.selectHistoryBlock('Session A')?.setColumns.single.label,
      'S1',
    );
    expect(
      activeSheet.selectHistoryBlock('2026-06-14')?.setColumns.single.label,
      'S1',
    );
  });

  test('plans a new history block with only S1 near fixed columns', () {
    final activeSheet = parseFixtureActiveSheet();

    final plan = activeSheet.planNewHistoryBlock(label: 'Week 3');

    expect(plan.columnInsertions, [
      HistoryColumnInsertion(
        sheetColumnNumber: 10,
        headers: const ['Week 3'],
        setLabels: const ['S1'],
      ),
    ]);
  });

  test('plans growth for a selected history block beyond existing sets', () {
    final activeSheet = parseFixtureActiveSheet();

    final plan = activeSheet.planHistoryBlockGrowth(
      label: 'Week 2',
      throughSetNumber: 3,
    );

    expect(plan.columnInsertions, [
      HistoryColumnInsertion(
        sheetColumnNumber: 12,
        headers: const [''],
        setLabels: const ['S3'],
      ),
    ]);
  });

  test('plans multiple growth columns for later set numbers as needed', () {
    final rows = [
      historyHeaderRow(['Session A']),
      setLabelRow(['S1']),
      ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', '', '225x5@8'],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final plan = activeSheet.planHistoryBlockGrowth(
      label: 'Session A',
      throughSetNumber: 4,
    );

    expect(plan.columnInsertions, [
      HistoryColumnInsertion(
        sheetColumnNumber: 11,
        headers: const ['', '', ''],
        setLabels: const ['S2', 'S3', 'S4'],
      ),
    ]);
    expect(plan.previewRowsAfterApplying(rows)[1].skip(9), [
      'S1',
      'S2',
      'S3',
      'S4',
    ]);
  });

  test('previews history insertions without overwriting existing data', () {
    final workbook = loadLocalWorkoutWorkbookFixture();
    final activeSheet = parseFixtureActiveSheet();

    final previewRows = activeSheet
        .planNewHistoryBlock(label: 'Week 3')
        .previewRowsAfterApplying(workbook.activeSheet.rows);

    expect(previewRows.first.skip(9).take(6), [
      'Week 3',
      'Week 2',
      '',
      'Week 1',
      '',
      '',
    ]);
    expect(previewRows[1].skip(9).take(6), [
      'S1',
      'S1',
      'S2',
      'S1',
      'S2',
      'S3',
    ]);
    final benchPressPreviewRow = previewRows.firstWhere(
      (row) => row.first == 'Bench Press',
    );
    expect(benchPressPreviewRow.skip(9).take(6), [
      '',
      '155x6@8',
      '',
      '150x6@8',
      '150x6@8',
      '150x5@9',
    ]);
  });
}
