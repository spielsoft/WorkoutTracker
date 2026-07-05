import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';

import 'helpers.dart';

void main() {
  test('parses selected history cells with the row-local log format', () {
    final rows = [
      historyHeaderRow(['Session A']),
      setLabelRow(['S1']),
      [
        'Step Up',
        '3',
        '10',
        '8',
        '2 min',
        '',
        '',
        '{Weight}[x]{Reps}[@]{RPE}[,]{Pain}',
        'Legs',
        '',
        '150x10@8,',
      ],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final context = activeSheet.buildLoggingContext(
      primarySheetRowNumber: 3,
      selectedSheetRowNumber: 3,
      historyBlockLabel: 'Session A',
    );

    final logEntry = context.selectedHistory.entries.single.logEntry;
    expect(logEntry, isA<FormattedLogEntry>());
    final formatted = logEntry as FormattedLogEntry;
    expect(formatted.fieldLabels, ['Weight', 'Reps', 'RPE', 'Pain']);
    expect(formatted.fieldValues, {
      'Weight': '150',
      'Reps': '10',
      'RPE': '8',
      'Pain': '',
    });
  });

  test('row history exposes one app-facing log entry representation', () {
    final rows = [
      historyHeaderRow(['Session A']),
      setLabelRow(['S1']),
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '225x5@8'],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final context = activeSheet.buildLoggingContext(
      primarySheetRowNumber: 3,
      selectedSheetRowNumber: 3,
      historyBlockLabel: 'Session A',
    );

    final entry = context.selectedHistory.entries.single;
    expect(entry.logEntry, isA<FormattedLogEntry>());
    expect(() => (entry as dynamic).notation, throwsNoSuchMethodError);
  });

  test('parses repeated delimiters and preserves unparseable raw entries', () {
    final rows = [
      historyHeaderRow(['Session A', '']),
      setLabelRow(['S1', 'S2']),
      [
        'Carry',
        '3',
        '',
        '',
        '2 min',
        '',
        '',
        '{A}[,]{B}[,]{C}',
        'Legs',
        '',
        'left,,right',
        'left,right',
      ],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final context = activeSheet.buildLoggingContext(
      primarySheetRowNumber: 3,
      selectedSheetRowNumber: 3,
      historyBlockLabel: 'Session A',
    );

    final formatted = context.selectedHistory.entries.first.logEntry;
    expect(formatted, isA<FormattedLogEntry>());
    expect((formatted as FormattedLogEntry).fieldValues, {
      'A': 'left',
      'B': '',
      'C': 'right',
    });

    final raw = context.selectedHistory.entries.last.logEntry;
    expect(raw, isA<RawLogEntry>());
    expect((raw as RawLogEntry).text, 'left,right');
    expect(context.selectedHistory.entries.last.rawValue, 'left,right');
  });

  test(
    'parses bodyweight, timed, and height-based row-local history cells',
    () {
      final rows = [
        historyHeaderRow(['Session A']),
        setLabelRow(['S1']),
        [
          'Pull Up',
          '3',
          '',
          '',
          '2 min',
          '',
          '',
          '{Reps}[@]{RPE}',
          'Upper',
          '',
          '15@8',
        ],
        [
          'Plank',
          '3',
          '',
          '',
          '90s',
          '',
          '',
          '{Seconds}[s@]{RPE}',
          'Upper',
          '',
          '45s@8',
        ],
        [
          'Box Jump',
          '3',
          '',
          '',
          '2 min',
          '',
          '',
          '{Height}[in x]{Reps}[@]{RPE}',
          'Upper',
          '',
          '24in x10@8',
        ],
      ];
      final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

      FormattedLogEntry entryFor(int sheetRowNumber) {
        final context = activeSheet.buildLoggingContext(
          primarySheetRowNumber: sheetRowNumber,
          selectedSheetRowNumber: sheetRowNumber,
          historyBlockLabel: 'Session A',
        );
        return context.selectedHistory.entries.single.logEntry
            as FormattedLogEntry;
      }

      expect(entryFor(3).fieldValues, {'Reps': '15', 'RPE': '8'});
      expect(entryFor(4).fieldValues, {'Seconds': '45', 'RPE': '8'});
      expect(entryFor(5).fieldValues, {
        'Height': '24',
        'Reps': '10',
        'RPE': '8',
      });
    },
  );

  test('uses primary and backup row-local formats independently', () {
    final rows = [
      historyHeaderRow(['Session A']),
      setLabelRow(['S1']),
      ['Pull Up', '3', '', '', '2 min', '', '', '{Reps}', 'Upper', '', '12'],
      [
        'Plank',
        '3',
        '',
        '',
        '90s',
        '',
        '',
        '{Seconds}[s@]{RPE}',
        'Upper',
        'TRUE',
        '45s@8',
      ],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final primaryContext = activeSheet.buildLoggingContext(
      primarySheetRowNumber: 3,
      selectedSheetRowNumber: 3,
      historyBlockLabel: 'Session A',
    );
    final backupContext = activeSheet.buildLoggingContext(
      primarySheetRowNumber: 3,
      selectedSheetRowNumber: 4,
      historyBlockLabel: 'Session A',
    );

    final primaryEntry =
        primaryContext.selectedHistory.entries.single.logEntry
            as FormattedLogEntry;
    expect(primaryEntry.fieldLabels, ['Reps']);
    expect(primaryEntry.fieldValues, {'Reps': '12'});

    final backupEntry =
        backupContext.selectedHistory.entries.single.logEntry
            as FormattedLogEntry;
    expect(backupEntry.fieldLabels, ['Seconds', 'RPE']);
    expect(backupEntry.fieldValues, {'Seconds': '45', 'RPE': '8'});
  });

  test('uses the default log format when parsing blank-format history', () {
    final rows = [
      historyHeaderRow(['Session A']),
      setLabelRow(['S1']),
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '225x5@8'],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final context = activeSheet.buildLoggingContext(
      primarySheetRowNumber: 3,
      selectedSheetRowNumber: 3,
      historyBlockLabel: 'Session A',
    );

    final entry =
        context.selectedHistory.entries.single.logEntry as FormattedLogEntry;
    expect(entry.fieldLabels, ['Weight', 'Reps', 'RPE']);
    expect(entry.fieldValues, {'Weight': '225', 'Reps': '5', 'RPE': '8'});
  });

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

      final context = activeSheet.buildLoggingContext(
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

      final context = activeSheet.buildLoggingContext(
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
      final recentEntry =
          context.recentHistoryBlocks.first.entries.last.logEntry
              as FormattedLogEntry;
      expect(recentEntry.fieldValues, {
        'Weight': '235',
        'Reps': '5',
        'RPE': '8',
      });
    },
  );
}
