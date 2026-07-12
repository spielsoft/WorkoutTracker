import 'dart:ui' show SemanticsAction;

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

  testWidgets('keyboard advances in format order and saves decimal values', (
    tester,
  ) async {
    final actions = _LogActions();
    await tester.pumpWidget(_app(actions: actions, view: _literalView()));

    final load = _field('Load');
    final effort = _field('Effort');
    final cue = _field('Cue');

    for (final label in ['Load', 'Effort', 'Cue']) {
      expect(
        tester
            .widget<TextField>(find.byKey(ValueKey('set-field-$label')))
            .keyboardType,
        const TextInputType.numberWithOptions(decimal: true, signed: true),
      );
    }

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

    await tester.enterText(cue, '9');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final save = actions.cmds.single as SaveSetCmd;
    expect(save.fields, {'Load': '102.5', 'Effort': '7.5', 'Cue': '9'});
  });

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

  testWidgets('logging remains usable at narrow width with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(_app(actions: _LogActions()));

    expect(tester.takeException(), isNull);
    expect(find.text('Next set S1'), findsOneWidget);
    expect(find.text('Progress 0/3'), findsNothing);
    expect(find.text('Current S1'), findsNothing);
    expect(find.text('Backup'), findsNothing);
    expect(find.text('Save set'), findsOneWidget);
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
    'prefills a new set from the latest result in the current block',
    (tester) async {
      await tester.pumpWidget(
        _app(
          actions: _LogActions(),
          view: _historyView(
            labels: const ['Week 2', '', 'Week 1'],
            setLabels: const ['S1', 'S2', 'S1'],
            values: const ['135x5@8', '', '125x4@7'],
            selectedBlock: 'Week 2',
          ),
        ),
      );

      expect(
        tester
            .widget<EditableText>(_editable(_field('Weight')))
            .controller
            .text,
        '135',
      );
      expect(
        tester.widget<EditableText>(_editable(_field('Reps'))).controller.text,
        '5',
      );
      expect(
        tester.widget<EditableText>(_editable(_field('RPE'))).controller.text,
        '8',
      );
    },
  );

  testWidgets('prefills a new set from the latest prior-block result', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        actions: _LogActions(),
        view: _historyView(
          labels: const ['Week 2', 'Week 1', '', ''],
          setLabels: const ['S1', 'S1', 'S2', 'S3'],
          values: const ['', '120x5@7', '', '125x4@8'],
          selectedBlock: 'Week 2',
        ),
      ),
    );

    expect(
      tester.widget<EditableText>(_editable(_field('Weight'))).controller.text,
      '125',
    );
    expect(
      tester.widget<EditableText>(_editable(_field('Reps'))).controller.text,
      '4',
    );
    expect(
      tester.widget<EditableText>(_editable(_field('RPE'))).controller.text,
      '8',
    );
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

    _expectDisabled(tester, find.widgetWithText(FilledButton, 'Save set'));
    _expectDisabled(tester, find.byTooltip('Edit S1'));
    _expectDisabled(tester, find.byTooltip('Clear set'));
  });

  testWidgets('shows formatted and raw sets as compact summaries', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        actions: _LogActions(),
        view: _historyView(
          labels: const ['Week 2', ''],
          setLabels: const ['S1', 'S2'],
          values: const ['225x5@8', 'manual note'],
          selectedBlock: 'Week 2',
        ),
      ),
    );

    expect(find.text('225x5@8'), findsOneWidget);
    expect(find.text('manual note'), findsOneWidget);
    expect(find.bySemanticsLabel('S1 Weight'), findsNothing);
    expect(find.bySemanticsLabel('S2 raw set text'), findsNothing);
  });

  testWidgets('expands one saved set and save or cancel collapses it', (
    tester,
  ) async {
    final actions = _LogActions();
    await tester.pumpWidget(
      _app(
        actions: actions,
        view: _historyView(
          labels: const ['Week 2', ''],
          setLabels: const ['S1', 'S2'],
          values: const ['225x5@8', 'manual note'],
          selectedBlock: 'Week 2',
        ),
      ),
    );

    await tester.tap(find.byTooltip('Edit S1'));
    await tester.pump();
    expect(find.bySemanticsLabel('S1 Weight'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit S2'));
    await tester.pump();
    expect(find.bySemanticsLabel('S1 Weight'), findsNothing);
    expect(find.bySemanticsLabel('S2 raw set text'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel set edit'));
    await tester.pump();
    expect(find.bySemanticsLabel('S2 raw set text'), findsNothing);

    await tester.tap(find.byTooltip('Edit S1'));
    await tester.pump();
    await tester.enterText(find.bySemanticsLabel('S1 Weight'), '230');
    await tester.tap(find.byTooltip('Save structured set'));
    await tester.pump();

    expect(find.bySemanticsLabel('S1 Weight'), findsNothing);
    expect(actions.cmds.single, isA<EditSetCmd>());
  });

  testWidgets('saved structured fields use numeric entry and accept decimals', (
    tester,
  ) async {
    final actions = _LogActions();
    await tester.pumpWidget(
      _app(
        actions: actions,
        view: _historyView(
          labels: const ['Week 2'],
          setLabels: const ['S1'],
          values: const ['102.5x7.5; 2'],
          selectedBlock: 'Week 2',
          logFormat: '{Load}[x]{Effort}[; ]{Cue}',
        ),
      ),
    );

    await tester.tap(find.byTooltip('Edit S1'));
    await tester.pump();
    final cue = find.bySemanticsLabel('S1 Cue');

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('logged-S1-field-Cue')))
          .keyboardType,
      const TextInputType.numberWithOptions(decimal: true, signed: true),
    );
    await tester.enterText(find.bySemanticsLabel('S1 Load'), '103.25');
    await tester.enterText(cue, '3');
    await tester.tap(find.byTooltip('Save structured set'));
    await tester.pump();

    final edit = actions.cmds.single as EditSetCmd;
    expect(edit.fields, {'Load': '103.25', 'Effort': '7.5', 'Cue': '3'});
  });

  testWidgets('clear offers time-limited undo with exact raw restoration', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final actions = _LogActions();
    await tester.pumpWidget(
      _app(
        actions: actions,
        view: _historyView(
          labels: const ['Week 2'],
          setLabels: const ['S1'],
          values: const ['  manual; note  '],
          selectedBlock: 'Week 2',
        ),
      ),
    );

    await tester.tap(find.byTooltip('Clear set'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(actions.cmds.single, isA<ClearSetCmd>());
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final undo = actions.cmds.last as EditRawSetCmd;
    expect(undo.rawText, '  manual; note  ');
    expect(find.text('S1 restored.'), findsOneWidget);
  });

  testWidgets('clear undo expires', (tester) async {
    await tester.pumpWidget(
      _app(
        actions: _LogActions(),
        view: _historyView(
          labels: const ['Week 2'],
          setLabels: const ['S1'],
          values: const ['225x5@8'],
          selectedBlock: 'Week 2',
        ),
      ),
    );

    await tester.tap(find.byTooltip('Clear set'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('failed clear and undo show errors without claiming success', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final failedClear = _LogActions(outcomes: const [false]);
    final view = _historyView(
      labels: const ['Week 2'],
      setLabels: const ['S1'],
      values: const ['manual note'],
      selectedBlock: 'Week 2',
    );
    await tester.pumpWidget(_app(actions: failedClear, view: view));

    await tester.tap(find.byTooltip('Clear set'));
    await tester.pump();

    expect(find.text('S1 was not cleared.'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);

    final failedUndo = _LogActions(outcomes: const [true, false]);
    await tester.pumpWidget(_app(actions: failedUndo, view: view));
    await tester.tap(find.byTooltip('Clear set'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('S1 was not restored.'), findsOneWidget);
    expect(find.text('S1 restored.'), findsNothing);
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
  _LogActions({this.succeeds = true, this.outcomes = const []});

  final bool succeeds;
  final List<bool> outcomes;
  final cmds = <WbkCmd>[];
  final selectedRows = <int>[];
  bool closed = false;

  @override
  Future<void> close() async => closed = true;

  @override
  Future<bool> execute(WbkCmd cmd) async {
    cmds.add(cmd);
    final index = cmds.length - 1;
    return index < outcomes.length ? outcomes[index] : succeeds;
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
  String logFormat = '{Weight}[x]{Reps}[@]{RPE}',
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
          logFormat,
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

void _expectDisabled(WidgetTester tester, Finder control) {
  final semantics = tester.getSemantics(control.first).getSemanticsData();
  expect(semantics.hasAction(SemanticsAction.tap), isFalse);
}
