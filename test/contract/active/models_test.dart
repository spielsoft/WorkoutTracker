import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';

import 'helpers.dart';

void main() {
  test('builds logging context from the selected row-local contract', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow(['Week 1']),
          setLabelRow(['S1']),
          activeRow(
            'Squat',
            sets: '4',
            targets: 'x5@8',
            workout: 'Legs',
            history: const ['225x5@8'],
          ),
          activeRow(
            'Side Plank',
            sets: '2',
            tempo: 'hold',
            targets: '30@8',
            notes: 'Keep hips stacked.',
            logFormat: '{Seconds}@{RPE}',
            workout: 'Legs',
            isBackup: true,
            history: const ['30@8'],
          ),
        ],
      ),
    );

    final context = sheet.buildLoggingContext(
      primaryRow: 3,
      selectedRow: 4,
      blockLabel: 'Week 1',
    );
    expect(context.selectedChoice.exercise, 'Side Plank');
    expect(context.targets.sets, '2');
    expect(context.targets.tempo, 'hold');
    expect(context.targets.values, {'Seconds': '30', 'RPE': '8'});
    expect(context.notes, 'Keep hips stacked.');
    expect(context.selectedHistory.entries.single.rawValue, '30@8');
  });

  test('groups backups beneath their nearest primary in workout order', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow([]),
          setLabelRow([]),
          activeRow('Squat', workout: 'Legs'),
          activeRow('Leg Press', workout: 'Legs', isBackup: true),
          activeRow('Bench Press', workout: 'Upper'),
        ],
      ),
    );

    expect(sheet.selectableWorkouts, ['Legs', 'Upper']);
    final overview = sheet.buildWorkoutOverview(
      workout: 'Legs',
      blockLabel: '',
    );
    expect(overview.slots.single.exercise, 'Squat');
    expect(overview.slots.single.prescribedSets, '3');
    expect(overview.slots.single.backups.single.exercise, 'Leg Press');
  });
}
