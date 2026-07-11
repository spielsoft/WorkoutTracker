import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

void main() {
  testWidgets('keeps phone set entry in task order with targets nearby', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_app(actions: _LogActions()));

    final fields = ['Weight', 'Reps', 'RPE'].map(_field).toList();
    final save = find.text('Save set');

    expect(find.text('Plan 3 x 5 @ 8'), findsOneWidget);
    expect(find.text('Rest 3 min'), findsOneWidget);
    expect(
      tester.getTopLeft(fields[0]).dy,
      lessThan(tester.getTopLeft(fields[1]).dy),
    );
    expect(
      tester.getTopLeft(fields[1]).dy,
      lessThan(tester.getTopLeft(fields[2]).dy),
    );
    expect(
      tester.getBottomLeft(fields[2]).dy,
      lessThan(tester.getTopLeft(save).dy),
    );
    expect(
      (tester.getTopLeft(fields[0]).dy -
              tester.getBottomLeft(find.text('Rest 3 min')).dy)
          .abs(),
      lessThan(80),
    );
  });

  testWidgets(
    'keyboard advances in format order and Done saves decimal and text values',
    (tester) async {
      final actions = _LogActions();
      await tester.pumpWidget(_app(actions: actions, view: _literalView()));

      final load = _field('Load');
      final effort = _field('Effort');
      final cue = _field('Cue');

      await tester.tap(load);
      await tester.enterText(load, '102.5');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(
        tester.widget<EditableText>(_editable(effort)).focusNode.hasFocus,
        isTrue,
      );

      await tester.enterText(effort, '7.5');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(
        tester.widget<EditableText>(_editable(cue)).focusNode.hasFocus,
        isTrue,
      );

      await tester.enterText(cue, 'grindy today');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final save = actions.cmds.single as SaveSetCmd;
      expect(save.fields, {
        'Load': '102.5',
        'Effort': '7.5',
        'Cue': 'grindy today',
      });
    },
  );

  testWidgets('keeps desktop set entry compact in the shared flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_app(actions: _LogActions()));

    final controls = [
      _field('Weight'),
      _field('Reps'),
      _field('RPE'),
      find.text('Save set'),
    ];
    final centers = controls.map(tester.getCenter).toList();

    expect(centers.map((point) => point.dy).toSet(), hasLength(1));
    for (var i = 1; i < centers.length; i += 1) {
      expect(centers[i - 1].dx, lessThan(centers[i].dx));
    }
  });

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

  testWidgets(
    'keeps failed input visible and reports the command-owner error',
    (tester) async {
      final actions = _LogActions(succeeds: false);
      final view = _view();
      await tester.pumpWidget(_app(actions: actions, view: view));

      await tester.enterText(_field('Weight'), '225');
      await tester.tap(find.text('Save set'));
      await tester.pump();
      await tester.pumpWidget(
        _app(
          actions: actions,
          view: _viewState(
            view,
            error:
                'Unable to save set: saved set was not visible after refresh.',
          ),
        ),
      );

      expect(
        find.text(
          'Unable to save set: saved set was not visible after refresh.',
        ),
        findsOneWidget,
      );
      expect(find.text('225'), findsOneWidget);
    },
  );

  testWidgets('typed pending state disables every set mutation', (
    tester,
  ) async {
    final view = _historyView(
      labels: const ['Week 2'],
      setLabels: const ['S1'],
      values: const ['225x5@8'],
      selectedBlock: 'Week 2',
    );
    await tester.pumpWidget(
      _app(actions: _LogActions(), view: _viewState(view, isBusy: true)),
    );

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save set'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('save-S1')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('clear-S1')))
          .onPressed,
      isNull,
    );
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

LogView _viewState(LogView view, {bool isBusy = false, String? error}) {
  return LogView(
    isBusy: isBusy,
    error: error,
    activeSheet: view.activeSheet,
    sheetLabel: view.sheetLabel,
    target: view.target,
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

LogView _literalView() {
  final active = parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Carry',
          '3',
          '20 m',
          '7.5',
          '90s',
          '',
          '',
          '{Load}[x]{Effort}[; ]{Cue}',
          'Conditioning',
          '',
          '',
        ],
      ],
    ),
  );
  return LogView(
    isBusy: false,
    activeSheet: active,
    sheetLabel: 'Development Workouts',
    target: const WorkoutLoggingTarget(
      blockLabel: 'Week 1',
      primaryRow: 3,
      selectedRow: 3,
    ),
  );
}

Finder _field(String label) {
  return find.bySemanticsLabel(label);
}

Finder _editable(Finder field) {
  return find.descendant(of: field, matching: find.byType(EditableText));
}
