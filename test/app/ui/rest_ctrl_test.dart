import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/src/app/rest_timer.dart';

void main() {
  testWidgets('countdown completion signals exactly once', (tester) async {
    var signals = 0;
    final ctrl = RestCtrl(signal: () async => signals += 1);
    addTearDown(ctrl.dispose);

    ctrl.start(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(signals, 1);
    expect(ctrl.active, isFalse);

    await tester.pump(const Duration(seconds: 2));
    expect(signals, 1);
  });

  testWidgets('done and replacement timers do not signal', (tester) async {
    var signals = 0;
    final ctrl = RestCtrl(signal: () async => signals += 1);
    addTearDown(ctrl.dispose);

    ctrl.start(const Duration(seconds: 10));
    ctrl.done();
    ctrl.start(const Duration(seconds: 10));
    ctrl.start(const Duration(seconds: 1));
    await tester.pump();

    expect(signals, 0);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(signals, 1);
  });

  testWidgets('elapsed background timer signals once on resume', (
    tester,
  ) async {
    var now = DateTime(2026, 8, 27, 10);
    var signals = 0;
    final ctrl = RestCtrl(now: () => now, signal: () async => signals += 1);
    addTearDown(ctrl.dispose);

    ctrl.start(const Duration(seconds: 3));
    ctrl.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 4));
    ctrl.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();

    expect(signals, 1);
    expect(ctrl.active, isFalse);

    ctrl.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(signals, 1);
  });

  testWidgets('missing haptic channel does not stop completion', (
    tester,
  ) async {
    final ctrl = RestCtrl(
      signal: () async => throw MissingPluginException('haptic unavailable'),
    );
    addTearDown(ctrl.dispose);

    ctrl.start(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(ctrl.active, isFalse);
    expect(tester.takeException(), isNull);
  });
}
