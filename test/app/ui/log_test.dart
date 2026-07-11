import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

void main() {
  testWidgets('emits typed row, close, and set-save commands', (tester) async {
    final actions = _LogActions();
    await tester.pumpWidget(_app(actions: actions));

    await tester.tap(find.text('Leg Press'));
    expect(actions.selectedRows.single, 4);

    await tester.tap(find.byTooltip('Back to exercises'));
    expect(actions.closed, isTrue);

    await tester.enterText(_field('Weight'), '225');
    await tester.enterText(_field('Reps'), '5');
    await tester.enterText(_field('RPE'), '8');
    await tester.tap(find.text('Save set'));
    await tester.pump();

    final save = actions.cmds.single as SaveSetCmd;
    expect(save.blockLabel, 'Week 2');
    expect(save.sheetRow, 3);
    expect(save.fields, {'Weight': '225', 'Reps': '5', 'RPE': '8'});
  });

  testWidgets('keeps failed input visible and reports the screen-local error', (
    tester,
  ) async {
    await tester.pumpWidget(_app(actions: _LogActions(succeeds: false)));

    await tester.enterText(_field('Weight'), '225');
    await tester.tap(find.text('Save set'));
    await tester.pump();

    expect(find.text('Unable to save set. Try again.'), findsOneWidget);
    expect(find.text('225'), findsOneWidget);
  });

  testWidgets('uses the newest non-empty set across gaps and trailing blanks', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        actions: _LogActions(),
        view: _historyView(
          labels: const ['Week 2', 'Week 1', '', '', ''],
          setLabels: const ['S1', 'S1', 'S2', 'S3', 'S4'],
          values: const ['40x5@8', '30x5@7', '', '35x5@8', ''],
          selectedBlock: 'Week 2',
        ),
      ),
    );

    await tester.tap(find.text('Training details'));
    await tester.pumpAndSettle();

    expect(find.text('Latest history: 35x5@8'), findsOneWidget);
  });

  testWidgets('uses the newest prior block when several contain history', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        actions: _LogActions(),
        view: _historyView(
          labels: const ['Week 3', 'Week 2', 'Week 1'],
          setLabels: const ['S1', 'S1', 'S1'],
          values: const ['300x5@8', '200x5@8', '100x5@8'],
          selectedBlock: 'Week 3',
        ),
      ),
    );

    await tester.tap(find.text('Training details'));
    await tester.pumpAndSettle();

    expect(find.text('Latest history: 200x5@8'), findsOneWidget);
  });

  testWidgets('excludes the selected block from latest history', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        actions: _LogActions(),
        view: _historyView(
          labels: const ['Week 2', 'Week 1'],
          setLabels: const ['S1', 'S1'],
          values: const ['999x5@9', '35x5@8'],
          selectedBlock: 'Week 2',
        ),
      ),
    );

    await tester.tap(find.text('Training details'));
    await tester.pumpAndSettle();

    expect(find.text('Latest history: 35x5@8'), findsOneWidget);
    expect(find.textContaining('999x5@9'), findsNothing);
  });

  testWidgets('omits latest history when no prior block has data', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        actions: _LogActions(),
        view: _historyView(
          labels: const ['Week 1'],
          setLabels: const ['S1'],
          values: const ['40x5@8'],
          selectedBlock: 'Week 1',
        ),
      ),
    );

    await tester.tap(find.text('Training details'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Latest history:'), findsNothing);
  });
}

Widget _app({required LogActions actions, LogView? view}) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [LogScreen(view: view ?? _view(), actions: actions)],
      ),
    ),
  );
}

final class _LogActions implements LogActions {
  _LogActions({this.succeeds = true});

  final bool succeeds;
  final cmds = <WbkCmd>[];
  final selectedRows = <int>[];
  bool closed = false;

  @override
  Future<void> close() async => closed = true;

  @override
  Future<bool> execute(WbkCmd cmd) async {
    cmds.add(cmd);
    return succeeds;
  }

  @override
  Future<void> selectRow(int sheetRow) async => selectedRows.add(sheetRow);
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
    activeSheet: setup.activeSheet,
    sheetLabel: 'Development Workouts',
    target: setup.loggingTarget!,
  );
}

LogView _historyView({
  required List<String> labels,
  required List<String> setLabels,
  required List<String> values,
  required String selectedBlock,
}) {
  final active = parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, ...labels],
        [...List.filled(activeSheetFixedColumns.length, ''), ...setLabels],
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
          ...values,
        ],
      ],
    ),
  );
  return LogView(
    isBusy: false,
    activeSheet: active,
    sheetLabel: 'Development Workouts',
    target: WorkoutLoggingTarget(
      blockLabel: selectedBlock,
      primaryRow: 3,
      selectedRow: 3,
    ),
  );
}

Finder _field(String label) {
  return find.bySemanticsLabel(label);
}
