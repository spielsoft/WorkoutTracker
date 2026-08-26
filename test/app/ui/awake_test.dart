import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/src/app/awake.dart';

void main() {
  testWidgets('workout activity renews the ten-minute awake lease', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: IdleAwake(
          setAwake: (enabled) async => changes.add(enabled),
          child: const SizedBox.expand(
            child: ColoredBox(key: Key('workout-entry'), color: Colors.black),
          ),
        ),
      ),
    );

    expect(changes, [true]);
    await tester.pump(const Duration(minutes: 9));
    await tester.tap(find.byKey(const Key('workout-entry')));
    await tester.pump(const Duration(minutes: 9));
    expect(changes, [true]);

    await tester.pump(const Duration(minutes: 1, seconds: 1));
    expect(changes, [true, false]);
  });

  testWidgets('leaving workout entry releases the awake override', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: IdleAwake(
          setAwake: (enabled) async => changes.add(enabled),
          child: const Text('Workout entry'),
        ),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: Text('Exercise list')));

    expect(changes, [true, false]);
  });

  testWidgets('backgrounding releases and returning renews the lease', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: IdleAwake(
          setAwake: (enabled) async => changes.add(enabled),
          child: const Text('Workout entry'),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(changes, [true, false, true]);
  });
}
