// Proves the local preview harness still loads and still reaches a timed
// exercise through the real screens, so the physical-device acceptance session
// has a working fixture. This is fixture coverage, not a validation tier: it
// establishes nothing about Google, any real workbook, or physical hardware.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/gym_preview.dart';
import '../support/widget.dart';

void main() {
  testWidgets('the preview workbook loads without a Google account', (
    tester,
  ) async {
    await _openPreview(tester);

    expect(find.byKey(const ValueKey('workout-home')), findsOneWidget);
    expect(find.text('2026 Workouts'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('open-spreadsheet-manual-repair')),
      findsNothing,
      reason: 'the fixture is a clean schema 1.1 workbook',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a placed Side Plank times its Seconds field and records it', (
    tester,
  ) async {
    await _openPreview(tester);
    await _openExercise(tester, 'Side Plank');

    expect(
      find.semantics.byLabel('Start Side Plank Seconds timer, 25 seconds'),
      findsOne,
      reason: 'the timer offers the seconds the field already suggests',
    );

    await tester.tap(find.byKey(const ValueKey('set-timer-Seconds')));
    await tester.pump();

    expect(_heading(tester), 'Side Plank');
    expect(
      _dim(tester),
      lessThan(1),
      reason: 'exercise timing dims and locks the app below the bar',
    );

    await tester.pump(const Duration(seconds: 8));
    await tester.tap(find.byKey(const ValueKey('countdown-done')));
    await tester.pump();

    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
    expect(_dim(tester), 1, reason: 'Done restores the app');
    expect(_value(tester, 'Seconds'), '8', reason: 'Done records the hold');
    expect(
      find.text('Save set S1'),
      findsOneWidget,
      reason: 'recording a duration never saves the set',
    );
  });

  testWidgets('the identically labeled Front Plank stays untimed', (
    tester,
  ) async {
    await _openPreview(tester);
    await _openExercise(tester, 'Front Plank');

    expect(_value(tester, 'Seconds'), isNotEmpty);
    expect(
      find.semantics.byLabel(RegExp(r'^Start .+ timer')),
      findsNothing,
      reason: 'a Seconds label never implies a timer',
    );
  });

  testWidgets('a long timed exercise name heads the countdown bar', (
    tester,
  ) async {
    await _openPreview(tester);
    await _openExercise(tester, 'Copenhagen Side Plank (Bench Elevated)');

    await tester.tap(find.byKey(const ValueKey('set-timer-Seconds')));
    await tester.pump();

    expect(_heading(tester), 'Copenhagen Side Plank (Bench Elevated)');
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('countdown-done')));
    await tester.pump();
  });
}

Future<void> _openPreview(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(gymPreviewApp());
  await tester.pumpAndSettle();
}

/// Reaches one placed exercise's logging screen the way an athlete would.
Future<void> _openExercise(WidgetTester tester, String exercise) async {
  await tester.tap(find.bySemanticsLabel(RegExp('^Workout selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Legs').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(exercise));
  await tester.pumpAndSettle();
}

String _value(WidgetTester tester, String label) {
  return editableTextFor(
    find.byKey(ValueKey('set-field-$label')),
  ).controller.text;
}

String _heading(WidgetTester tester) {
  return tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('countdown-heading')),
          matching: find.byType(Text),
        ),
      )
      .data!;
}

/// Effective opacity applied to the app below the countdown bar.
double _dim(WidgetTester tester) {
  return tester
      .widgetList<Opacity>(
        find.ancestor(
          of: find.text('Save set S1'),
          matching: find.byType(Opacity),
        ),
      )
      .fold<double>(1, (dim, layer) => dim * layer.opacity);
}
