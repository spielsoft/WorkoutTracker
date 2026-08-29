import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/src/app/countdown.dart';
import 'package:workout_tracker/src/app/exercise_timer.dart';
import 'package:workout_tracker/src/app/rest.dart';

// The injected signal proves only that the app asks the platform for one full
// vibration. Neither it nor the injected clock can establish real haptic
// hardware or execution while iOS has suspended the process; both remain
// physical-device acceptance work.
void main() {
  testWidgets('each policy decides on its own whether it locks the app', (
    tester,
  ) async {
    final ctrl = CountdownCtrl(signal: () async {});
    addTearDown(ctrl.dispose);

    expect(ctrl.modal, isFalse);

    ctrl.start(restCountdown(const Duration(seconds: 90)));
    expect(ctrl.heading, 'REST');
    expect(ctrl.modal, isFalse, reason: 'rest stays nonmodal');

    ctrl.start(
      exerciseCountdown(
        exercise: 'Side Plank',
        duration: const Duration(seconds: 20),
      ),
    );
    expect(ctrl.heading, 'Side Plank');
    expect(ctrl.modal, isTrue);

    ctrl.toggle();
    expect(ctrl.modal, isTrue, reason: 'pausing does not release the lock');

    ctrl.done();
    expect(ctrl.modal, isFalse);
  });

  testWidgets(
    'a fractional countdown expires at its exact deadline while displaying '
    'rounded whole seconds',
    (tester) async {
      var signals = 0;
      final ctrl = CountdownCtrl(signal: () async => signals += 1);
      addTearDown(ctrl.dispose);

      ctrl.start(
        const Countdown(
          heading: 'Side Plank',
          duration: Duration(milliseconds: 2600),
        ),
      );

      expect(ctrl.seconds, 3);
      await tester.pump(const Duration(seconds: 1));
      expect(ctrl.seconds, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(ctrl.seconds, 1);

      await tester.pump(const Duration(milliseconds: 599));
      expect(ctrl.active, isTrue, reason: 'the exact deadline is 2.6 seconds');
      expect(signals, 0);

      await tester.pump(const Duration(milliseconds: 1));
      expect(ctrl.active, isFalse);
      expect(signals, 1);
    },
  );

  testWidgets('expiry requests one full vibration and clears the countdown', (
    tester,
  ) async {
    var signals = 0;
    final ctrl = CountdownCtrl(signal: () async => signals += 1);
    addTearDown(ctrl.dispose);

    ctrl.start(
      const Countdown(heading: 'REST', duration: Duration(seconds: 1)),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(signals, 1);
    expect(ctrl.active, isFalse);
    expect(ctrl.heading, isEmpty);

    await tester.pump(const Duration(seconds: 5));
    expect(signals, 1);
  });

  testWidgets('done clears the countdown without asking for a vibration', (
    tester,
  ) async {
    var signals = 0;
    final ctrl = CountdownCtrl(signal: () async => signals += 1);
    addTearDown(ctrl.dispose);

    ctrl.start(
      const Countdown(heading: 'REST', duration: Duration(seconds: 10)),
    );
    ctrl.done();
    await tester.pump(const Duration(seconds: 20));

    expect(ctrl.active, isFalse);
    expect(signals, 0);
  });

  testWidgets('ending reports the elapsed duration for done and for expiry', (
    tester,
  ) async {
    final elapsed = <Duration>[];
    final ctrl = CountdownCtrl(signal: () async {});
    addTearDown(ctrl.dispose);

    ctrl.start(
      Countdown(
        heading: 'Side Plank',
        duration: const Duration(seconds: 45),
        onEnd: elapsed.add,
      ),
    );
    await tester.pump(const Duration(milliseconds: 30500));
    ctrl.done();

    expect(elapsed, [const Duration(milliseconds: 30500)]);

    ctrl.start(
      Countdown(
        heading: 'Side Plank',
        duration: const Duration(milliseconds: 2600),
        onEnd: elapsed.add,
      ),
    );
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();

    expect(elapsed.last, const Duration(milliseconds: 2600));
  });

  testWidgets('pause holds the exact remaining time and resume continues it', (
    tester,
  ) async {
    var signals = 0;
    final ctrl = CountdownCtrl(signal: () async => signals += 1);
    addTearDown(ctrl.dispose);

    ctrl.start(
      const Countdown(
        heading: 'Side Plank',
        duration: Duration(milliseconds: 2600),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    ctrl.toggle();

    expect(ctrl.paused, isTrue);
    expect(ctrl.remaining, const Duration(milliseconds: 1700));

    await tester.pump(const Duration(minutes: 5));
    expect(ctrl.active, isTrue);
    expect(ctrl.remaining, const Duration(milliseconds: 1700));
    expect(signals, 0);

    ctrl.toggle();
    expect(ctrl.paused, isFalse);
    await tester.pump(const Duration(milliseconds: 1699));
    expect(ctrl.active, isTrue);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(ctrl.active, isFalse);
    expect(signals, 1);
  });

  testWidgets('added time extends the deadline by exactly thirty seconds', (
    tester,
  ) async {
    final elapsed = <Duration>[];
    final ctrl = CountdownCtrl(signal: () async {});
    addTearDown(ctrl.dispose);

    ctrl.start(
      Countdown(
        heading: 'REST',
        duration: const Duration(seconds: 90),
        onEnd: elapsed.add,
      ),
    );
    await tester.pump(const Duration(seconds: 10));
    expect(ctrl.seconds, 80);

    ctrl.addTime();
    expect(ctrl.remaining, const Duration(seconds: 110));
    expect(ctrl.seconds, 110);

    ctrl.done();
    expect(elapsed, [const Duration(seconds: 10)]);
  });

  testWidgets('added time also extends a paused countdown', (tester) async {
    final ctrl = CountdownCtrl(signal: () async {});
    addTearDown(ctrl.dispose);

    ctrl.start(
      const Countdown(heading: 'REST', duration: Duration(seconds: 90)),
    );
    await tester.pump(const Duration(seconds: 10));
    ctrl.toggle();
    ctrl.addTime();

    expect(ctrl.remaining, const Duration(seconds: 110));

    ctrl.toggle();
    await tester.pump(const Duration(seconds: 5));
    expect(ctrl.remaining, const Duration(seconds: 105));

    ctrl.done();
  });

  testWidgets('a replaced countdown never reports or signals later', (
    tester,
  ) async {
    var signals = 0;
    final elapsed = <Duration>[];
    final ctrl = CountdownCtrl(signal: () async => signals += 1);
    addTearDown(ctrl.dispose);

    ctrl.start(
      Countdown(
        heading: 'REST',
        duration: const Duration(seconds: 5),
        onEnd: elapsed.add,
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    ctrl.start(
      const Countdown(heading: 'Side Plank', duration: Duration(seconds: 1)),
    );

    expect(elapsed, isEmpty);
    expect(ctrl.heading, 'Side Plank');
    expect(ctrl.seconds, 1);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();

    expect(signals, 1, reason: 'only the replacement countdown may signal');
    expect(elapsed, isEmpty);
  });

  testWidgets('suspension keeps the exact deadline and resume signals once', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 8, 27, 10);
    var signals = 0;
    final ctrl = CountdownCtrl(
      now: () => now,
      signal: () async => signals += 1,
    );
    addTearDown(ctrl.dispose);

    ctrl.start(
      const Countdown(heading: 'REST', duration: Duration(milliseconds: 3500)),
    );
    ctrl.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 2));
    ctrl.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(ctrl.active, isTrue);
    expect(
      ctrl.remaining,
      const Duration(milliseconds: 1500),
      reason: 'suspension must not lose the fractional half second',
    );
    expect(signals, 0);

    ctrl.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 2));
    ctrl.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();

    expect(signals, 1);
    expect(ctrl.active, isFalse);

    ctrl.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(signals, 1);
  });

  testWidgets('suspending a paused countdown leaves its remaining time held', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 8, 27, 10);
    var signals = 0;
    final ctrl = CountdownCtrl(
      now: () => now,
      signal: () async => signals += 1,
    );
    addTearDown(ctrl.dispose);

    ctrl.start(
      const Countdown(heading: 'REST', duration: Duration(seconds: 30)),
    );
    ctrl.toggle();
    ctrl.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 5));
    ctrl.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(ctrl.active, isTrue);
    expect(ctrl.paused, isTrue);
    expect(ctrl.remaining, const Duration(seconds: 30));
    expect(signals, 0);

    ctrl.done();
  });

  testWidgets('an unusable platform haptic cannot strand either countdown', (
    tester,
  ) async {
    final failures = [
      MissingPluginException('haptic unavailable'),
      PlatformException(code: 'haptic-unavailable'),
    ];

    for (final failure in failures) {
      final ctrl = CountdownCtrl(signal: () async => throw failure);
      addTearDown(ctrl.dispose);

      for (final heading in ['REST', 'Side Plank']) {
        ctrl.start(
          Countdown(heading: heading, duration: const Duration(seconds: 1)),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();

        expect(ctrl.active, isFalse, reason: '$heading after $failure');
        expect(
          tester.takeException(),
          isNull,
          reason: '$heading after $failure',
        );
      }
    }
  });
}
