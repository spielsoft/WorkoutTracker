import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

void main() {
  testWidgets('keeps phone set entry in a compact task-first hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_app(actions: _LogActions()));

    expect(find.text('Squat'), findsNWidgets(2));
    expect(find.text('Next set S1'), findsNothing);
    expect(find.text('Training details'), findsNothing);
    expect(find.text('3 sets | 3 min Rest'), findsOneWidget);
    expect(find.text('3 sets | x5@8'), findsNothing);
    expect(find.textContaining('Notes:'), findsNothing);
    expect(_field('Weight'), findsOneWidget);
    expect(_field('Reps'), findsOneWidget);
    expect(_field('RPE'), findsOneWidget);
    expect(find.text('Save set S1'), findsOneWidget);
  });

  testWidgets('forward accessory advances in format order and saves literals', (
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
        const TextInputType.numberWithOptions(decimal: true),
      );
    }

    await tester.tap(load);
    await tester.pump();
    expect(find.bySemanticsLabel('Next field Effort'), findsOneWidget);

    await tester.enterText(load, '102.5 kg');
    await tester.tap(find.bySemanticsLabel('Next field Effort'));
    await tester.pump();
    expect(find.bySemanticsLabel('Next field Cue'), findsOneWidget);
    _expectFieldValue('Load', '102.5 kg');

    await tester.enterText(effort, '7.5');
    await tester.tap(find.bySemanticsLabel('Next field Cue'));
    await tester.pump();
    expect(find.bySemanticsLabel('Save set S1 from keyboard'), findsOneWidget);
    _expectFieldValue('Effort', '7.5');
    await tester.enterText(cue, 'steady');
    await tester.tap(find.bySemanticsLabel('Save set S1 from keyboard'));
    await tester.pump();

    final save = actions.cmds.single as SaveSetCmd;
    expect(save.fields, {'Load': '102.5 kg', 'Effort': '7.5', 'Cue': 'steady'});
  });

  testWidgets('final accessory preserves empty, failed, and busy state', (
    tester,
  ) async {
    final actions = _LogActions(succeeds: false);
    final view = _literalView();
    await tester.pumpWidget(_app(actions: actions, view: view));

    await tester.tap(_field('Cue'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Save set S1 from keyboard'));
    await tester.pump();
    expect(actions.cmds, isEmpty);

    await tester.enterText(_field('Load'), '100.5');
    await tester.enterText(_field('Effort'), '7');
    await tester.enterText(_field('Cue'), 'go');
    await tester.tap(find.bySemanticsLabel('Save set S1 from keyboard'));
    await tester.pump();

    expect(actions.cmds, hasLength(1));
    expect(find.text('Save set S1'), findsOneWidget);
    _expectFieldValue('Load', '100.5');
    _expectFieldValue('Effort', '7');
    _expectFieldValue('Cue', 'go');

    await tester.pumpWidget(
      _app(actions: actions, view: _viewState(view, isBusy: true)),
    );
    await tester.pump();
    final forward = find.bySemanticsLabel('Save set S1 from keyboard');
    expect(forward, findsOneWidget);
    _expectDisabled(tester, forward);
    await tester.tap(forward);
    await tester.pump();
    expect(actions.cmds, hasLength(1));
  });

  testWidgets('forward accessory follows the visible logging context', (
    tester,
  ) async {
    final actions = _LogActions();
    await tester.pumpWidget(_app(actions: actions));

    expect(find.bySemanticsLabel('Next field Reps'), findsNothing);
    await tester.tap(_field('Weight'));
    await tester.pump();
    expect(find.bySemanticsLabel('Next field Reps'), findsOneWidget);

    await tester.tap(find.text('Leg Press'));
    await tester.pump();
    expect(actions.selectedRows, [4]);
    expect(find.bySemanticsLabel('Next field Reps'), findsNothing);

    await tester.tap(_field('Weight'));
    await tester.pump();
    await tester.tap(find.byTooltip('Back to exercises'));
    await tester.pump();
    expect(actions.closed, isTrue);
    expect(find.bySemanticsLabel('Next field Reps'), findsNothing);
  });

  testWidgets('final forward action remains reachable above keyboard insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final actions = _LogActions();
    await tester.pumpWidget(
      _app(
        actions: actions,
        view: _targetView(targets: '240x10-12@8,0'),
      ),
    );
    final field = _field('Pain');
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pump();

    final forward = find.bySemanticsLabel('Save set S1 from keyboard');
    expect(forward, findsOneWidget);
    expect(tester.takeException(), isNull);
    final keyboardTop =
        tester.view.physicalSize.height / tester.view.devicePixelRatio -
        tester.view.viewInsets.bottom;
    expect(tester.getBottomLeft(field).dy, lessThanOrEqualTo(keyboardTop));
    expect(tester.getBottomLeft(forward).dy, lessThanOrEqualTo(keyboardTop));

    await tester.tap(forward);
    await tester.pump();
    expect(actions.cmds, hasLength(1));

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pump();
    expect(find.bySemanticsLabel('Save set S1 from keyboard'), findsNothing);
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

    await tester.pumpWidget(
      _app(
        actions: _LogActions(),
        view: _targetView(targets: '240x10-12@8,0'),
      ),
    );

    expect(tester.takeException(), isNull);
    final controls = [
      for (final label in const ['Weight', 'Reps', 'RPE', 'Pain'])
        _field(label),
      find.text('Save set S1'),
    ];
    final rects = controls.map(tester.getRect).toList();
    final overlapTop = rects
        .map((rect) => rect.top)
        .reduce((a, b) => a > b ? a : b);
    final overlapBottom = rects
        .map((rect) => rect.bottom)
        .reduce((a, b) => a < b ? a : b);
    expect(overlapTop, lessThan(overlapBottom));
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

    await tester.pumpWidget(
      _app(
        actions: _LogActions(),
        view: _targetView(targets: '240x10-12@8,0'),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Next set S1'), findsNothing);
    expect(find.text('Progress 0/3'), findsNothing);
    expect(find.text('Current S1'), findsNothing);
    expect(find.text('Backup'), findsNothing);
    expect(find.text('Save set S1'), findsOneWidget);
    expect(find.text('Reps (10-12)'), findsOneWidget);
    expect(find.text('Pain (0)'), findsOneWidget);
  });

  testWidgets(
    'five DB Step-Up fields and save stay reachable without overlap',
    (tester) async {
      Future<void> check(Size size, {double textScale = 1}) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        await tester.pumpWidget(
          _app(actions: _LogActions(), view: _dbStepUpView()),
        );
        await tester.pump();

        final controls = <Finder>[
          for (final label in const [
            'Height (in)',
            'Weight (lbs)',
            'Reps',
            'RPE',
            'Pain',
          ])
            find.bySemanticsLabel('New set $label'),
          find.widgetWithText(FilledButton, 'Save set S1'),
        ];
        expect(tester.takeException(), isNull);
        for (final control in controls) {
          await tester.ensureVisible(control);
          await tester.pump();
          expect(control.hitTestable(), findsOneWidget);
        }

        final rects = controls.map(tester.getRect).toList();
        for (var i = 0; i < rects.length; i += 1) {
          for (var j = i + 1; j < rects.length; j += 1) {
            expect(rects[i].overlaps(rects[j]), isFalse);
          }
        }
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await check(const Size(320, 1200), textScale: 2);
      await check(const Size(900, 700));
    },
  );

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
    await tester.tap(find.text('Save set S1'));
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
    'shows exact configured targets without changing stable field names',
    (tester) async {
      await tester.pumpWidget(
        _app(
          actions: _LogActions(),
          view: _targetView(targets: '240x10-12@8,0'),
        ),
      );

      for (final label in const ['Weight', 'Reps', 'RPE', 'Pain']) {
        expect(find.bySemanticsLabel('New set $label'), findsOneWidget);
      }
      expect(find.bySemanticsLabel('Weight (240)'), findsNothing);
      expect(find.bySemanticsLabel('New set Weight (240)'), findsNothing);
      expect(find.text('Weight (240)'), findsOneWidget);
      expect(find.text('Reps (10-12)'), findsOneWidget);
      expect(find.text('RPE (8)'), findsOneWidget);
      expect(find.text('Pain (0)'), findsOneWidget);
      _expectFieldValue('Weight', '240');
      _expectFieldValue('Reps', '10-12');
      _expectFieldValue('RPE', '8');
      _expectFieldValue('Pain', '0');
    },
  );

  testWidgets('keeps blank targets plain and never invents zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        actions: _LogActions(),
        view: _targetView(targets: 'x10-12@8,'),
      ),
    );

    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Reps (10-12)'), findsOneWidget);
    expect(find.text('RPE (8)'), findsOneWidget);
    expect(find.text('Pain'), findsOneWidget);
    expect(find.textContaining('(0)'), findsNothing);
  });

  testWidgets(
    'keeps row targets visible when newer history supplies the draft',
    (tester) async {
      await tester.pumpWidget(
        _app(
          actions: _LogActions(),
          view: _targetView(targets: '240x10-12@8,0', history: '225x6@9,2'),
        ),
      );

      expect(find.text('Weight (240)'), findsOneWidget);
      expect(find.text('Reps (10-12)'), findsOneWidget);
      expect(find.text('RPE (8)'), findsOneWidget);
      expect(find.text('Pain (0)'), findsOneWidget);
      _expectFieldValue('Weight', '225');
      _expectFieldValue('Reps', '6');
      _expectFieldValue('RPE', '9');
      _expectFieldValue('Pain', '2');
    },
  );

  testWidgets('uses targets from the active backup or duplicate placement', (
    tester,
  ) async {
    final actions = _LogActions();
    await tester.pumpWidget(
      _app(
        actions: actions,
        view: _placementView(primaryRow: 3, selectedRow: 3),
      ),
    );
    expect(find.text('Weight (100)'), findsOneWidget);
    expect(find.text('Reps (5)'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        actions: actions,
        view: _placementView(primaryRow: 3, selectedRow: 4),
      ),
    );
    expect(find.text('Weight (110)'), findsOneWidget);
    expect(find.text('Reps (6)'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        actions: actions,
        view: _placementView(primaryRow: 5, selectedRow: 5),
      ),
    );
    expect(find.text('Weight (120)'), findsOneWidget);
    expect(find.text('Reps (8)'), findsOneWidget);
  });

  testWidgets('keeps target suffixes off logged-set edit fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        actions: _LogActions(),
        view: _targetView(targets: '240x10-12@8,0', history: '225x6@9,2'),
      ),
    );

    await tester.tap(find.byTooltip('Edit S1'));
    await tester.pump();

    for (final label in const ['Weight', 'Reps', 'RPE', 'Pain']) {
      expect(find.bySemanticsLabel('S1 $label'), findsOneWidget);
    }
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Reps'), findsOneWidget);
    expect(find.text('RPE'), findsOneWidget);
    expect(find.text('Pain'), findsOneWidget);
  });

  testWidgets(
    'keeps failed input visible and reports the command-owner error',
    (tester) async {
      final actions = _LogActions(succeeds: false);
      final view = _view();
      await tester.pumpWidget(_app(actions: actions, view: view));

      await tester.enterText(_field('Weight'), '225');
      await tester.tap(find.text('Save set S1'));
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

    _expectDisabled(tester, find.widgetWithText(FilledButton, 'Save set S2'));
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
          logFormat: '{Load}x{Effort}; {Cue}',
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
      const TextInputType.numberWithOptions(decimal: true),
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
          '3 min',
          '',
          'x5@8',
          '',
          '{Weight}x{Reps}@{RPE}',
          'Legs',
          '',
          'x',
          '',
          '30x5@7',
          '35x5@8',
        ],
        [
          'Leg Press',
          '3',
          '2 min',
          '',
          'x10@8',
          '',
          '{Weight}x{Reps}@{RPE}',
          'Legs',
          'TRUE',
          'x',
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
  String logFormat = '{Weight}x{Reps}@{RPE}',
}) {
  final active = parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, ...labels],
        [...List.filled(activeSheetFixedColumns.length, ''), ...setLabels],
        [
          'Squat',
          '3',
          '3 min',
          '',
          logFormat == '{Weight}x{Reps}@{RPE}' ? 'x5@8' : '',
          '',
          logFormat,
          'Legs',
          '',
          'x',
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
          '90s',
          '',
          '',
          '',
          '{Load}x{Effort}; {Cue}',
          'Conditioning',
          '',
          'x',
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

LogView _targetView({required String targets, String history = ''}) {
  final active = parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Leg Press',
          '3',
          '120s',
          '',
          targets,
          '',
          '{Weight}x{Reps}@{RPE},{Pain}',
          'Legs',
          '',
          'x',
          history,
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

LogView _dbStepUpView() {
  const format = '({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}';
  final active = parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'DB Step-Up',
          '3',
          '90s',
          '3-1-1',
          '(12, 15)x8@8,0',
          'Control the descent.',
          format,
          'Legs',
          '',
          'x',
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

LogView _placementView({required int primaryRow, required int selectedRow}) {
  final active = parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Press',
          '3',
          '2 min',
          '',
          '100x5@6,',
          '',
          '{Weight}x{Reps}@{RPE},{Pain}',
          'Upper',
          '',
          'x',
          '',
        ],
        [
          'Press',
          '3',
          '2 min',
          '',
          '110x6@7,0',
          '',
          '{Weight}x{Reps}@{RPE},{Pain}',
          'Upper',
          'TRUE',
          'x',
          '',
        ],
        [
          'Press',
          '3',
          '2 min',
          '',
          '120x8@9,',
          '',
          '{Weight}x{Reps}@{RPE},{Pain}',
          'Upper',
          '',
          'x',
          '',
        ],
      ],
    ),
  );
  return LogView(
    isBusy: false,
    activeSheet: active,
    sheetLabel: 'Development Workouts',
    target: WorkoutLoggingTarget(
      blockLabel: 'Week 1',
      primaryRow: primaryRow,
      selectedRow: selectedRow,
    ),
  );
}

Finder _field(String label) {
  return find.bySemanticsLabel('New set $label');
}

Finder _editable(Finder field) {
  return find.descendant(of: field, matching: find.byType(EditableText));
}

void _expectFieldValue(String label, String value) {
  expect(
    find.descendant(of: _field(label), matching: find.text(value)),
    findsOneWidget,
  );
}

void _expectDisabled(WidgetTester tester, Finder control) {
  final semantics = tester.getSemantics(control.first).getSemanticsData();
  expect(semantics.hasAction(SemanticsAction.tap), isFalse);
}
