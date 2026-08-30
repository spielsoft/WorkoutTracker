import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/src/app/countdown.dart';

import '../../support/widget.dart';

const _longExerciseName = 'Copenhagen Side Plank With A Deliberately Long Name';
const _controlKeys = ['countdown-add', 'countdown-toggle', 'countdown-done'];

void main() {
  testWidgets('a full-width heading row sits above the symmetric controls', (
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

    expect(find.text('REST'), findsOneWidget);
    expect(find.text('117'), findsOneWidget);
    expect(find.text('+30 s'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byKey(const ValueKey('countdown-heading'))),
      matchesSemantics(label: 'REST', isHeader: true),
    );
    expectHeadingLevel(
      tester,
      find.byKey(const ValueKey('countdown-heading')),
      1,
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

    await expectFlutterAccessibilityGuidelines(tester);

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
    expectHeadingLevel(
      tester,
      find.byKey(const ValueKey('countdown-heading')),
      1,
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

    final paused = find.semantics.byLabel(
      'Pause Side Plank timer, 20 seconds remaining',
    );
    expect(paused, findsOne);
    expect(
      paused,
      isSemantics(
        isButton: true,
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('countdown-toggle')));
    await tester.pump();

    final resumed = find.semantics.byLabel(
      'Resume Side Plank timer, 20 seconds remaining',
    );
    expect(resumed, findsOne);
    expect(
      resumed,
      isSemantics(
        isButton: true,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
    );

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
