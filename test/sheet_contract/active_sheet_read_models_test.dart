import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'active_sheet_test_helpers.dart';

void main() {
  test('builds a primary-only workout overview with nested backups', () {
    final rows = [
      historyHeaderRow(['Session A', '']),
      setLabelRow(['S1', 'S2']),
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '225x5@8', ''],
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
        '360x10@8',
        '',
      ],
      ['Deadlift', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '', ''],
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
        '155x6@8',
        '',
      ],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final overview = activeSheet.buildWorkoutOverview(
      workout: 'Legs',
      historyBlockLabel: 'Session A',
    );

    expect(overview.workout, 'Legs');
    expect(overview.slots.map((slot) => slot.exercise), ['Squat', 'Deadlift']);
    expect(overview.slots.map((slot) => slot.sheetRowNumber), [3, 5]);
    expect(overview.slots.first.setCount, 2);
    expect(overview.slots.first.backups.map((choice) => choice.exercise), [
      'Leg Press',
    ]);
    expect(overview.slots.first.backups.single.sheetRowNumber, 4);
    expect(overview.slots.last.setCount, 0);
    expect(overview.slots.last.backups, isEmpty);
  });

  test('lists selectable workouts from active sheet row order', () {
    final activeSheet = parseFixtureActiveSheet();

    expect(activeSheet.selectableWorkouts, [
      'Legs',
      'Upper',
      defaultWorkoutName,
    ]);
  });

  test(
    'builds exercise logging context for a selected primary or backup row',
    () {
      final rows = [
        historyHeaderRow(['Session B', '', 'Session A']),
        setLabelRow(['S1', 'S2', 'S1']),
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          'Stay braced.',
          '{Weight}[x]{Reps}[@]{RPE}',
          'Legs',
          '',
          '225x5@8',
          '',
          '215x5@8',
        ],
        [
          'Leg Press',
          '3',
          '10',
          '8',
          '2 min',
          '',
          'Backup if racks are taken.',
          '{Reps}[@]{RPE}',
          'Legs',
          'TRUE',
          '',
          '360x10@8',
          '',
        ],
      ];
      final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

      final context = activeSheet.buildExerciseLoggingContext(
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 4,
        historyBlockLabel: 'Session B',
      );

      expect(context.selectedChoice.exercise, 'Leg Press');
      expect(context.selectedChoice.isBackup, isTrue);
      expect(
        (context.selectedChoice.logFormat as ParsedLogFormat).fieldLabels,
        ['Reps', 'RPE'],
      );
      expect(context.choices.map((choice) => choice.exercise), [
        'Squat',
        'Leg Press',
      ]);
      expect((context.logFormat as ParsedLogFormat).fieldLabels, [
        'Reps',
        'RPE',
      ]);
      expect(context.notes, 'Backup if racks are taken.');
      expect(context.rest, '2 min');
      expect(context.targets.sets, '3');
      expect(context.targets.reps, '10');
      expect(context.targets.rpe, '8');
      expect(context.targets.tempo, '');
      expect(context.selectedHistory.label, 'Session B');
      expect(context.selectedHistory.entries.map((entry) => entry.rawValue), [
        '',
        '360x10@8',
      ]);
    },
  );

  test(
    'defaults exercise history to the last three non-empty row-local blocks',
    () {
      final rows = [
        historyHeaderRow([
          'Session D',
          '',
          'Session C',
          'Session B',
          'Session A',
        ]),
        setLabelRow(['S1', 'S2', 'S1', 'S1', 'S1']),
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          '',
          '',
          'Legs',
          '',
          '',
          '235x5@8',
          '230x5@8',
          '',
          '225x5@8',
        ],
        [
          'Deadlift',
          '3',
          '5',
          '8',
          '3 min',
          '',
          '',
          '',
          'Legs',
          '',
          '',
          '',
          '',
          '315x5@8',
          '',
        ],
      ];
      final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

      final context = activeSheet.buildExerciseLoggingContext(
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 3,
        historyBlockLabel: 'Session D',
      );

      expect(context.recentHistoryBlocks.map((block) => block.label), [
        'Session D',
        'Session C',
        'Session A',
      ]);
      expect(
        context.recentHistoryBlocks.first.entries.map(
          (entry) => entry.rawValue,
        ),
        ['', '235x5@8'],
      );
    },
  );
}
