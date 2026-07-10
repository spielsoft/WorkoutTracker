import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

void main() {
  testWidgets('emits typed row, close, and set-save commands', (tester) async {
    final cmds = <LogCmd>[];
    await tester.pumpWidget(
      _app(
        run: (cmd) async {
          cmds.add(cmd);
          return const CmdResult.done();
        },
      ),
    );

    await tester.tap(find.text('Leg Press'));
    expect(cmds.single, isA<SelectLogRow>());
    expect((cmds.single as SelectLogRow).sheetRow, 4);

    cmds.clear();
    await tester.tap(find.byTooltip('Back to exercises'));
    expect(cmds.single, isA<CloseLog>());

    cmds.clear();
    await tester.enterText(_field('Weight'), '225');
    await tester.enterText(_field('Reps'), '5');
    await tester.enterText(_field('RPE'), '8');
    await tester.tap(find.text('Save set'));
    await tester.pump();

    final execute = cmds.single as ExecuteWbk;
    final save = execute.cmd as SaveSetCmd;
    expect(save.blockLabel, 'Week 2');
    expect(save.sheetRow, 3);
    expect(save.fields, {'Weight': '225', 'Reps': '5', 'RPE': '8'});
  });

  testWidgets('keeps failed input visible and reports the screen-local error', (
    tester,
  ) async {
    await tester.pumpWidget(_app(run: (_) async => const CmdResult.failed()));

    await tester.enterText(_field('Weight'), '225');
    await tester.tap(find.text('Save set'));
    await tester.pump();

    expect(find.text('Unable to save set. Try again.'), findsOneWidget);
    expect(tester.widget<TextField>(_field('Weight')).controller!.text, '225');
  });

  testWidgets('shows the newest non-empty set from the latest prior block', (
    tester,
  ) async {
    await tester.pumpWidget(_app(run: (_) async => const CmdResult.done()));

    await tester.tap(find.text('Training details'));
    await tester.pumpAndSettle();

    expect(find.text('Latest history: 35x5@8'), findsOneWidget);
  });
}

Widget _app({required Future<CmdResult> Function(LogCmd cmd) run}) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [LogScreen(view: _view(), run: run)],
      ),
    ),
  );
}

LogView _view() {
  final active = parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 2', 'Week 1', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1', 'S2'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          '',
          '{Weight}[x]{Reps}[@]{RPE}',
          'Legs',
          '',
          '',
          '30x5@7',
          '35x5@8',
        ],
        [
          'Leg Press',
          '3',
          '10',
          '8',
          '2 min',
          '',
          '',
          '{Weight}[x]{Reps}[@]{RPE}',
          'Legs',
          'TRUE',
          '',
          '',
          '',
        ],
      ],
    ),
  );
  final overview = active.buildWorkoutOverview(
    workout: 'Legs',
    blockLabel: 'Week 2',
  );
  final setup = WorkoutSetupReadModel(
    activeSheet: active,
    workouts: const ['Legs'],
    historyBlocks: active.historyBlocks,
    selectedWorkout: 'Legs',
    selectedHistoryBlock: 'Week 2',
    overview: overview,
    progressByWorkout: const {'Legs': WorkoutSetupProgress(done: 0, total: 6)},
    loggingTarget: const WorkoutLoggingTarget(
      blockLabel: 'Week 2',
      primaryRow: 3,
      selectedRow: 3,
    ),
  );
  return LogView(
    isBusy: false,
    setup: setup,
    sheetLabel: 'Development Workouts',
    target: setup.loggingTarget!,
  );
}

Finder _field(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}
