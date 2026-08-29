import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/src/app/countdown.dart';
import 'package:workout_tracker/src/app/ui/shared/status.dart';

import '../../support/widget.dart';

const _longExerciseName = 'Copenhagen Side Plank With A Deliberately Long Name';
const _controlKeys = ['countdown-add', 'countdown-toggle', 'countdown-done'];

void main() {
  testWidgets('countdown bar draws from distinct theme roles with contrast', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final ctrl = CountdownCtrl(signal: () async {});
    addTearDown(ctrl.dispose);
    ctrl.start(
      const Countdown(heading: 'REST', duration: Duration(seconds: 117)),
    );

    await tester.pumpWidget(_barApp(ctrl));

    final colors = _colors;
    final bar = tester.widget<Material>(
      find.byKey(const ValueKey('countdown-bar')),
    );
    final countdown = tester.widget<Text>(find.text('117'));
    final heading = tester.widget<Text>(find.text('REST'));
    final add = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '+30 s'),
    );
    final done = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Done'),
    );

    expect(bar.color, colors.tertiaryContainer);
    expect(bar.color, isNot(colors.surface));
    expect(bar.color, isNot(stateStyle(colors, VisualSt.warning).background));
    expect(countdown.style?.color, colors.onTertiaryContainer);
    expect(heading.style?.color, colors.onTertiaryContainer);
    expect(
      add.style?.foregroundColor?.resolve(const <WidgetState>{}),
      colors.onTertiaryContainer,
    );
    expect(
      add.style?.side?.resolve(const <WidgetState>{})?.color,
      colors.tertiary,
    );
    expect(
      done.style?.backgroundColor?.resolve(const <WidgetState>{}),
      colors.tertiary,
    );
    expect(
      done.style?.foregroundColor?.resolve(const <WidgetState>{}),
      colors.onTertiary,
    );
    await expectFlutterAccessibilityGuidelines(tester);
    ctrl.done();
    await tester.pump();
  });

  testWidgets('a full-width heading row sits above the symmetric controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final ctrl = CountdownCtrl(signal: () async {});
    addTearDown(ctrl.dispose);
    ctrl.start(
      const Countdown(heading: 'REST', duration: Duration(seconds: 90)),
    );
    await tester.pumpWidget(_barApp(ctrl));

    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byKey(const ValueKey('countdown-heading'))),
      matchesSemantics(label: 'REST', isHeader: true),
    );
    semantics.dispose();

    final heading = tester.getRect(
      find.byKey(const ValueKey('countdown-heading')),
    );
    final add = tester.getRect(find.byKey(const ValueKey('countdown-add')));
    final done = tester.getRect(find.byKey(const ValueKey('countdown-done')));
    final toggle = tester.getRect(
      find.byKey(const ValueKey('countdown-toggle')),
    );

    expect(heading.left, lessThanOrEqualTo(add.left));
    expect(heading.right, greaterThanOrEqualTo(done.right));
    for (final control in [add, toggle, done]) {
      expect(heading.bottom, lessThanOrEqualTo(control.top));
    }

    ctrl.done();
    await tester.pump();
  });

  testWidgets('a long exercise heading wraps without shifting the controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final rest = CountdownCtrl(signal: () async {});
    addTearDown(rest.dispose);
    rest.start(
      const Countdown(heading: 'REST', duration: Duration(seconds: 90)),
    );
    await tester.pumpWidget(_barApp(rest));
    final restColumns = _controlColumns(tester);
    final restHeadingHeight = tester.getSize(find.text('REST')).height;
    rest.done();
    await tester.pump();

    final exercise = CountdownCtrl(signal: () async {});
    addTearDown(exercise.dispose);
    exercise.start(
      const Countdown(
        heading: _longExerciseName,
        duration: Duration(seconds: 90),
      ),
    );
    await tester.pumpWidget(_barApp(exercise));

    expect(find.text(_longExerciseName), findsOneWidget);
    expect(
      tester.getSize(find.text(_longExerciseName)).height,
      greaterThan(restHeadingHeight),
      reason: 'the full name wraps instead of truncating away identity',
    );
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byKey(const ValueKey('countdown-heading'))),
      matchesSemantics(label: _longExerciseName, isHeader: true),
    );
    semantics.dispose();
    expect(_controlColumns(tester), restColumns);
    expect(tester.takeException(), isNull);
    await expectFlutterAccessibilityGuidelines(tester);

    exercise.done();
    await tester.pump();
  });

  testWidgets('the countdown button names the timer, its state, and its time', (
    tester,
  ) async {
    final ctrl = CountdownCtrl(signal: () async {});
    addTearDown(ctrl.dispose);
    ctrl.start(
      const Countdown(
        heading: 'Side Plank',
        duration: Duration(milliseconds: 20400),
      ),
    );
    await tester.pumpWidget(_barApp(ctrl));

    Semantics countdown() {
      return tester.widget<Semantics>(
        find.byKey(const ValueKey('countdown-toggle')),
      );
    }

    expect(
      countdown().properties.label,
      'Pause Side Plank timer, 20 seconds remaining',
    );
    expect(countdown().properties.toggled, isFalse);

    await tester.tap(find.byKey(const ValueKey('countdown-toggle')));
    await tester.pump();

    expect(
      countdown().properties.label,
      'Resume Side Plank timer, 20 seconds remaining',
    );
    expect(countdown().properties.toggled, isTrue);

    ctrl.done();
    await tester.pump();
  });
}

final _colors = ColorScheme.fromSeed(
  seedColor: const Color(0xFF0E7C66),
  brightness: Brightness.dark,
);

Widget _barApp(CountdownCtrl ctrl) {
  return MaterialApp(
    theme: ThemeData(colorScheme: _colors, useMaterial3: true),
    home: Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ListenableBuilder(
            listenable: ctrl,
            builder: (context, _) => CountdownBar(ctrl: ctrl),
          ),
        ),
      ),
    ),
  );
}

List<double> _controlColumns(WidgetTester tester) {
  return [
    for (final control in _controlKeys)
      tester.getCenter(find.byKey(ValueKey(control))).dx,
  ];
}
