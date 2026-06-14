import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';

import '../fixtures/workout_sheet_fixtures.dart';

void main() {
  test('parses app-readable active sheet rows into ordered workout slots', () {
    final workbook = loadLocalWorkoutWorkbookFixture();

    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: workbook.activeSheet.rows,
        mergedFirstColumnRows: workbook.activeSheet.mergedFirstColumnRows,
      ),
    );

    expect(activeSheet.slots.map((slot) => slot.exercise), [
      'Bulgarian Split Squat',
      'Reverse Lunge',
      'Bench Press',
      'Push-Up',
      'Plank',
    ]);
    expect(activeSheet.slots.map((slot) => slot.sheetRowNumber), [
      3,
      4,
      6,
      7,
      8,
    ]);

    expect(
      activeSheet.slots.first,
      WorkoutSlot(
        sheetRowNumber: 3,
        exercise: 'Bulgarian Split Squat',
        sets: '3',
        reps: '8/side',
        rpe: '8',
        rest: '2 min',
        tempo: '3-1-1',
        notes: 'Use straps if grip limits load.',
        workout: 'Legs',
        isBackup: false,
      ),
    );
    expect(activeSheet.slots[1].isBackup, isTrue);
    expect(activeSheet.slots[3].isBackup, isTrue);
    expect(activeSheet.slots.last.workout, defaultWorkoutName);
  });

  test('discovers visible history block labels in sheet order', () {
    final workbook = loadLocalWorkoutWorkbookFixture();

    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: workbook.activeSheet.rows,
        mergedFirstColumnRows: workbook.activeSheet.mergedFirstColumnRows,
      ),
    );

    expect(activeSheet.historyBlocks.map((block) => block.label), [
      'Week 2',
      'Week 1',
    ]);
  });

  test('selects an existing history block and exposes its set columns', () {
    final workbook = loadLocalWorkoutWorkbookFixture();

    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: workbook.activeSheet.rows,
        mergedFirstColumnRows: workbook.activeSheet.mergedFirstColumnRows,
      ),
    );

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
          [...activeSheetFixedColumns, 'Session A', '2026-06-14'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1'],
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
    final workbook = loadLocalWorkoutWorkbookFixture();

    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: workbook.activeSheet.rows,
        mergedFirstColumnRows: workbook.activeSheet.mergedFirstColumnRows,
      ),
    );

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
    final workbook = loadLocalWorkoutWorkbookFixture();

    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: workbook.activeSheet.rows,
        mergedFirstColumnRows: workbook.activeSheet.mergedFirstColumnRows,
      ),
    );

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
      [...activeSheetFixedColumns, 'Session A'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
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

    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: workbook.activeSheet.rows,
        mergedFirstColumnRows: workbook.activeSheet.mergedFirstColumnRows,
      ),
    );

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
    expect(previewRows[5].skip(9).take(6), [
      '',
      '155x6@8',
      '',
      '150x6@8',
      '150x6@8',
      '150x5@9',
    ]);
  });

  test(
    'ignores merged first-column human rows even when they contain text',
    () {
      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [
            activeSheetFixedColumns,
            [
              'Leg Day',
              '',
              '',
              '',
              '',
              '',
              'Human section label spanning columns.',
              '',
              '',
            ],
            ['Squat', '3', '5', '8', '3 min', '', '', '', ''],
          ],
          mergedFirstColumnRows: {2},
        ),
      );

      expect(activeSheet.slots.map((slot) => slot.exercise), ['Squat']);
      expect(activeSheet.slots.single.sheetRowNumber, 3);
    },
  );

  test(
    'groups backup rows under the nearest preceding primary in a workout',
    () {
      final workbook = loadLocalWorkoutWorkbookFixture();

      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: workbook.activeSheet.rows,
          mergedFirstColumnRows: workbook.activeSheet.mergedFirstColumnRows,
        ),
      );

      expect(activeSheet.schemaViolations, isEmpty);
      expect(activeSheet.primarySlots.map((slot) => slot.exercise), [
        'Bulgarian Split Squat',
        'Bench Press',
        'Plank',
      ]);

      final legsSlot = activeSheet.primarySlots.first;
      expect(legsSlot.isBackup, isFalse);
      expect(legsSlot.backups.map((slot) => slot.exercise), ['Reverse Lunge']);
      expect(legsSlot.backups.single.isBackup, isTrue);
      expect(legsSlot.backups.single.workout, 'Legs');

      final upperSlot = activeSheet.primarySlots[1];
      expect(upperSlot.backups.map((slot) => slot.exercise), ['Push-Up']);

      final defaultSlot = activeSheet.primarySlots.last;
      expect(defaultSlot.workout, defaultWorkoutName);
      expect(defaultSlot.backups, isEmpty);
    },
  );

  test('does not attach backups across an intervening workout group', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          activeSheetFixedColumns,
          ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', ''],
          ['Bench Press', '3', '8', '8', '2 min', '', '', 'Upper', ''],
          ['Reverse Lunge', '3', '10/side', '8', '90s', '', '', 'Legs', 'TRUE'],
        ],
      ),
    );

    expect(activeSheet.primarySlots.first.exercise, 'Squat');
    expect(activeSheet.primarySlots.first.backups, isEmpty);
    expect(activeSheet.schemaViolations, [
      SchemaViolation(
        sheetRowNumber: 4,
        workout: 'Legs',
        message: 'Backup row has no preceding primary row in the same workout.',
      ),
    ]);
  });

  test('attaches backups to the nearest preceding primary in row order', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          activeSheetFixedColumns,
          ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', ''],
          ['Deadlift', '3', '5', '8', '3 min', '', '', 'Legs', ''],
          ['Hip Thrust', '3', '10', '8', '2 min', '', '', 'Legs', 'TRUE'],
        ],
      ),
    );

    expect(activeSheet.schemaViolations, isEmpty);
    expect(activeSheet.primarySlots.map((slot) => slot.exercise), [
      'Squat',
      'Deadlift',
    ]);
    expect(activeSheet.primarySlots.first.backups, isEmpty);
    expect(activeSheet.primarySlots.last.backups.map((slot) => slot.exercise), [
      'Hip Thrust',
    ]);
  });

  test(
    'reports a schema violation when a workout starts with a backup row',
    () {
      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [
            activeSheetFixedColumns,
            ['Step-Up', '3', '10/side', '8', '90s', '', '', 'Legs', 'TRUE'],
            ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', ''],
          ],
        ),
      );

      expect(activeSheet.primarySlots.map((slot) => slot.exercise), ['Squat']);
      expect(activeSheet.schemaViolations, [
        SchemaViolation(
          sheetRowNumber: 2,
          workout: 'Legs',
          message:
              'Backup row has no preceding primary row in the same workout.',
        ),
      ]);
    },
  );
}
