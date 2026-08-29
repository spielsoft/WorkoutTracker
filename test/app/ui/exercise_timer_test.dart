import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/src/app/exercise_timer.dart';
import 'package:workout_tracker/src/app/ui/shared/status.dart';

import '../service_fake.dart';
import '../../support/widget.dart';

// The recorded platform calls prove only which signal the app requests. They
// establish neither real haptic hardware nor execution while iOS has
// suspended the process; both stay physical-device acceptance work.
void main() {
  test('only a positive finite number of seconds can start a countdown', () {
    expect(timerDuration('30'), const Duration(seconds: 30));
    expect(timerDuration(' 2.6 '), const Duration(milliseconds: 2600));
    expect(timerDuration('0.25'), const Duration(milliseconds: 250));

    for (final unusable in [
      '',
      '   ',
      '0',
      '0.0',
      '-1',
      '-0.5',
      'NaN',
      'Infinity',
      '-Infinity',
      '1e400',
      '9.3e12',
      'thirty',
      '30s',
      '1:30',
    ]) {
      expect(timerDuration(unusable), isNull, reason: 'rejects "$unusable"');
    }
  });

  testWidgets('a differently named canonical field is timeable', (
    tester,
  ) async {
    await _openLog(tester, exercise: 'Wall Sit');

    expect(find.byKey(const ValueKey('set-timer-Hold')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-timer-RPE')), findsNothing);
  });

  testWidgets('the timer control names its exercise, field, and readiness', (
    tester,
  ) async {
    await _openLog(tester);

    final control = find.byKey(const ValueKey('set-timer-Seconds'));
    expect(
      tester.getSemantics(control),
      matchesSemantics(
        label: 'Start Side Plank Seconds timer, 30 seconds',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    await tester.enterText(_field('Seconds'), '0');
    await tester.pump();

    expect(
      tester.getSemantics(control),
      matchesSemantics(
        label:
            'Start Side Plank Seconds timer, unavailable because Seconds is '
            'not a positive number of seconds',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
  });

  testWidgets('timer controls stay out of logged set editing and placement', (
    tester,
  ) async {
    await _openLog(tester, history: '20s@8');

    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edit-S1')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('logged-S1-field-Seconds')),
      findsOneWidget,
    );
    expect(
      find.byIcon(Icons.timer_outlined),
      findsOneWidget,
      reason: 'only the new set editor may start a timer',
    );

    await tester.tap(find.byTooltip('Back to exercises'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.timer_outlined), findsNothing);

    await tester.tap(find.byKey(const ValueKey('add-primary-exercise')));
    await tester.pumpAndSettle();

    expect(find.text('Choose exercise'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
  });

  testWidgets('the icon starts the exact value in the field when pressed', (
    tester,
  ) async {
    final vibrations = _recordPlatformCalls(tester);
    await _openLog(tester);

    await tester.enterText(_field('Seconds'), '2.6');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('set-timer-Seconds')));
    await tester.pump();

    expect(find.byKey(const ValueKey('countdown-bar')), findsOneWidget);
    expect(_heading(tester), 'Side Plank');
    expect(_countdown(tester), '3');

    await tester.pump(const Duration(milliseconds: 2599));
    expect(
      find.byKey(const ValueKey('countdown-bar')),
      findsOneWidget,
      reason: 'the exact deadline is 2.6 seconds',
    );
    expect(vibrations, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
    expect(vibrations, ['HapticFeedback.vibrate']);
  });

  testWidgets('Done partway through a hold records the time actually held', (
    tester,
  ) async {
    final service = await _openLog(tester);
    await _startTimer(tester, '45');

    await tester.pump(const Duration(seconds: 30));
    await tester.tap(find.byKey(const ValueKey('countdown-done')));
    await tester.pump();

    expect(_value('Seconds'), '30');
    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
    expect(service.appliedPlans, isEmpty, reason: 'recording never saves');
    expect(find.text('Save set S1'), findsOneWidget);
  });

  testWidgets('a hold that runs to expiry records its full duration', (
    tester,
  ) async {
    final service = await _openLog(tester);

    expect(_value('Seconds'), '30', reason: 'the prescription is suggested');
    expect(_hint(tester, 'Seconds'), contains('Suggested'));

    await tester.tap(find.byKey(const ValueKey('set-timer-Seconds')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();

    expect(_value('Seconds'), '30');
    expect(
      _hint(tester, 'Seconds'),
      contains('Recorded'),
      reason: 'a completed hold stops reading as an unconfirmed suggestion',
    );
    expect(
      find.byKey(const ValueKey('countdown-bar')),
      findsNothing,
      reason: 'recording never starts rest',
    );
    expect(service.appliedPlans, isEmpty);

    await tester.tap(find.byKey(const ValueKey('set-timer-Seconds')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('countdown-add')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();

    expect(
      _value('Seconds'),
      '60',
      reason: 'an extended hold records the whole length it ran',
    );
  });

  testWidgets('a recorded duration rounds exactly as the visible countdown', (
    tester,
  ) async {
    await _openLog(tester);
    await _startTimer(tester, '9.5');

    expect(_countdown(tester), '10', reason: 'the display rounds to nearest');

    await tester.pump(const Duration(milliseconds: 2400));
    await tester.tap(find.byKey(const ValueKey('countdown-done')));
    await tester.pump();

    expect(_value('Seconds'), '2', reason: '2.4 seconds held rounds down');

    await _startTimer(tester, '9.5');
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.tap(find.byKey(const ValueKey('countdown-done')));
    await tester.pump();

    expect(_value('Seconds'), '3', reason: '2.5 seconds held rounds up');
  });

  testWidgets('a recorded value reads as measured data, not as a suggestion', (
    tester,
  ) async {
    await _openLog(tester);
    final colors = Theme.of(tester.element(_field('Seconds'))).colorScheme;

    expect(_hint(tester, 'Seconds'), 'Suggested value; edit to confirm');

    await tester.enterText(_field('RPE'), '9');
    await tester.pump();

    expect(_hint(tester, 'RPE'), isEmpty, reason: 'an entered value is plain');

    await _startTimer(tester, '45');
    await tester.pump(const Duration(seconds: 30));
    await tester.tap(find.byKey(const ValueKey('countdown-done')));
    await tester.pump();

    final recorded = _hint(tester, 'Seconds');
    expect(recorded, contains('Recorded'));
    expect(recorded, isNot('Suggested value; edit to confirm'));
    expect(recorded, isNot(_hint(tester, 'RPE')));
    expect(
      _style(tester, 'Seconds')?.fontStyle,
      isNot(FontStyle.italic),
      reason: 'measured data is not styled as a suggestion',
    );
    expect(
      _style(tester, 'Seconds')?.color,
      isNot(suggestedValueColor(colors)),
    );
    await expectFlutterAccessibilityGuidelines(tester);
  });

  testWidgets('ending a countdown writes only the field that started it', (
    tester,
  ) async {
    await _openLog(tester);

    expect(_value('RPE'), '8');
    expect(_style(tester, 'RPE')?.fontStyle, FontStyle.italic);

    await _startTimer(tester, '45');
    await tester.pump(const Duration(seconds: 30));
    await tester.tap(find.byKey(const ValueKey('countdown-done')));
    await tester.pump();

    expect(_value('Seconds'), '30');
    expect(_value('RPE'), '8');
    expect(
      _style(tester, 'RPE')?.fontStyle,
      FontStyle.italic,
      reason: 'another field keeps its own text and origin',
    );
    expect(_hint(tester, 'RPE'), contains('Suggested'));
  });

  testWidgets('editing a recorded value by hand makes it entered', (
    tester,
  ) async {
    await _openLog(tester);
    await _startTimer(tester, '45');
    await tester.pump(const Duration(seconds: 30));
    await tester.tap(find.byKey(const ValueKey('countdown-done')));
    await tester.pump();

    expect(_hint(tester, 'Seconds'), contains('Recorded'));

    await tester.enterText(_field('Seconds'), '28');
    await tester.pump();

    expect(_value('Seconds'), '28');
    expect(_hint(tester, 'Seconds'), isEmpty);
    expect(_style(tester, 'Seconds')?.fontStyle, isNot(FontStyle.italic));
  });

  testWidgets('a rest countdown ends without recording any field', (
    tester,
  ) async {
    await _openLog(tester);
    await _save(tester);

    expect(_heading(tester), 'REST');
    expect(_countdown(tester), '45');

    await tester.pump(const Duration(seconds: 45));
    await tester.pump();

    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
    expect(_value('Seconds'), '30');
    expect(_value('RPE'), '8');
    expect(_hint(tester, 'Seconds'), contains('Suggested'));
  });

  testWidgets('a countdown displaced by an exercise timer records nothing', (
    tester,
  ) async {
    await _openLog(tester);
    await _save(tester);

    expect(_heading(tester), 'REST');
    expect(_countdown(tester), '45');

    await _startTimer(tester, '60');
    expect(_heading(tester), 'Side Plank');

    await tester.pump(const Duration(seconds: 45));
    await tester.pump();

    expect(
      _value('Seconds'),
      '60',
      reason: 'the displaced rest countdown records nothing at its own end',
    );
    expect(_heading(tester), 'Side Plank');

    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.byKey(const ValueKey('countdown-done')));
    await tester.pump();

    expect(_value('Seconds'), '50');
  });

  testWidgets('starting a timer changes no set value, origin, or workbook', (
    tester,
  ) async {
    final service = await _openLog(tester);

    expect(_value('Seconds'), '30');
    expect(_style(tester, 'Seconds')?.fontStyle, FontStyle.italic);

    await tester.tap(find.byKey(const ValueKey('set-timer-Seconds')));
    await tester.pump();

    expect(find.byKey(const ValueKey('countdown-bar')), findsOneWidget);
    expect(_value('Seconds'), '30');
    expect(
      _style(tester, 'Seconds')?.fontStyle,
      FontStyle.italic,
      reason: 'timing must not confirm a suggested value',
    );
    expect(service.appliedPlans, isEmpty);
    expect(find.text('Save set S1'), findsOneWidget);
    expect(_heading(tester), isNot('REST'));
  });

  testWidgets('an unusable value neither starts nor disturbs a countdown', (
    tester,
  ) async {
    final service = await _openLog(tester);

    await tester.enterText(_field('Seconds'), 'later');
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('set-timer-Seconds')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);

    await tester.enterText(_field('Seconds'), '12');
    await tester.pump();
    await _save(tester);

    expect(service.appliedPlans, hasLength(1));
    expect(_heading(tester), 'REST');

    await tester.enterText(_field('Seconds'), '-4');
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('set-timer-Seconds')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(
      _heading(tester),
      'REST',
      reason: 'an unusable value must leave the running countdown alone',
    );
    expect(_countdown(tester), '45');
  });

  testWidgets('exercise timing replaces rest, which can no longer vibrate', (
    tester,
  ) async {
    final vibrations = _recordPlatformCalls(tester);
    await _openLog(tester);
    await _save(tester);

    expect(_heading(tester), 'REST');
    expect(_countdown(tester), '45');

    await _startTimer(tester, '3');

    expect(_heading(tester), 'Side Plank');
    expect(_countdown(tester), '3');

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(vibrations, ['HapticFeedback.vibrate']);

    await tester.pump(const Duration(minutes: 2));
    await tester.pump();

    expect(vibrations, [
      'HapticFeedback.vibrate',
    ], reason: 'the displaced rest countdown must never signal');
    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
  });

  testWidgets('exercise timing locks the app until Done releases it', (
    tester,
  ) async {
    final service = await _openLog(tester);

    expect(_dim(tester), 1);
    await _startTimer(tester, '60');

    expect(_dim(tester), lessThan(1), reason: 'the locked app is dimmed');
    expect(
      find.text('Save set S1'),
      findsOneWidget,
      reason: 'the app stays on screen behind the countdown',
    );
    expect(
      find.semantics.byLabel('New set Seconds'),
      findsNothing,
      reason: 'locked controls are removed from accessibility focus',
    );
    expect(find.semantics.byLabel(RegExp('Save set S1')), findsNothing);
    expect(find.semantics.byLabel('Log Side Plank'), findsNothing);
    expect(
      find.semantics.byLabel(RegExp('Pause Side Plank timer')),
      findsOne,
      reason: 'the countdown controls stay reachable',
    );
    expect(find.semantics.byLabel('Done'), findsOne);

    await tester.tap(find.text('Save set S1'), warnIfMissed: false);
    await tester.pump();
    expect(service.appliedPlans, isEmpty);

    await tester.tap(_field('Seconds'), warnIfMissed: false);
    await tester.pump();
    expect(inputHasFocus(_field('Seconds')), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(inputHasFocus(_field('Seconds')), isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.text('Save set S1'),
      findsOneWidget,
      reason: 'back navigation cannot leave a locked exercise',
    );

    await tester.tap(find.byKey(const ValueKey('countdown-toggle')));
    await tester.pump();
    expect(_dim(tester), lessThan(1), reason: 'pause keeps the lock');
    expect(find.semantics.byLabel('New set Seconds'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('countdown-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('countdown-add')));
    await tester.pump();
    expect(_countdown(tester), '90');
    expect(_dim(tester), lessThan(1), reason: 'added time keeps the lock');

    await tester.tap(find.byKey(const ValueKey('countdown-done')));
    await tester.pump();

    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
    expect(_dim(tester), 1);
    expect(find.semantics.byLabel('New set Seconds'), findsOne);

    await tester.tap(_field('Seconds'));
    await tester.pump();
    expect(inputHasFocus(_field('Seconds')), isTrue);

    await _save(tester);
    expect(service.appliedPlans, hasLength(1));
  });

  testWidgets('expiry releases the app on its own', (tester) async {
    await _openLog(tester);
    await _startTimer(tester, '5');

    expect(_dim(tester), lessThan(1));
    expect(find.semantics.byLabel('New set Seconds'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
    expect(_dim(tester), 1);
    expect(find.semantics.byLabel('New set Seconds'), findsOne);

    await tester.tap(_field('Seconds'));
    await tester.pump();
    expect(inputHasFocus(_field('Seconds')), isTrue);
  });

  testWidgets('a rest countdown leaves the app interactive', (tester) async {
    final service = await _openLog(tester);
    await _save(tester);

    expect(_heading(tester), 'REST');
    expect(_dim(tester), 1);
    expect(find.semantics.byLabel('New set Seconds'), findsOne);

    await tester.tap(_field('Seconds'));
    await tester.pump();
    expect(inputHasFocus(_field('Seconds')), isTrue);
    expect(service.appliedPlans, hasLength(1));
  });

  testWidgets('resume keeps the exact deadline and signals expiry once', (
    tester,
  ) async {
    final vibrations = _recordPlatformCalls(tester);
    await _openLog(tester);
    await _startTimer(tester, '3.5');

    expect(_countdown(tester), '4');

    _suspend(tester);
    await tester.pump(const Duration(seconds: 2));
    _resume(tester);
    await tester.pump();

    expect(find.byKey(const ValueKey('countdown-bar')), findsOneWidget);
    expect(_countdown(tester), '2', reason: '1.5 seconds remain');
    expect(vibrations, isEmpty);

    await tester.pump(const Duration(milliseconds: 1499));
    expect(
      find.byKey(const ValueKey('countdown-bar')),
      findsOneWidget,
      reason: 'the exact 3.5 second deadline survived suspension',
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(vibrations, ['HapticFeedback.vibrate']);
    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
    expect(_dim(tester), 1);

    await _startTimer(tester, '4');
    _suspend(tester);
    await tester.pump(const Duration(seconds: 10));

    expect(
      vibrations,
      hasLength(1),
      reason: 'a suspended app cannot signal while it is away',
    );

    _resume(tester);
    await tester.pump();

    expect(vibrations, hasLength(2), reason: 'expiry is discovered on resume');
    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
    expect(_dim(tester), 1);

    _suspend(tester);
    _resume(tester);
    await tester.pump(const Duration(seconds: 5));

    expect(vibrations, hasLength(2), reason: 'each countdown signals once');
  });

  testWidgets('exercise timing stays usable on a narrow large-text phone', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _openLog(tester, size: const Size(320, 1400));
    await _startTimer(tester, '45');

    expect(tester.takeException(), isNull);
    expect(_heading(tester), 'Side Plank');
    final heading = tester.getRect(
      find.byKey(const ValueKey('countdown-heading')),
    );
    for (final control in const [
      'countdown-add',
      'countdown-toggle',
      'countdown-done',
    ]) {
      expect(
        heading.bottom,
        lessThanOrEqualTo(tester.getRect(find.byKey(ValueKey(control))).top),
      );
    }
    await expectFlutterAccessibilityGuidelines(tester);

    await tester.pump(const Duration(seconds: 12));
    await tester.tap(find.byKey(const ValueKey('countdown-done')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('set-field-Seconds')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    final control = tester.getSize(
      find.byKey(const ValueKey('set-timer-Seconds')),
    );
    expect(control.width, greaterThanOrEqualTo(48));
    expect(control.height, greaterThanOrEqualTo(48));
    expect(_value('Seconds'), '12', reason: 'Done records the time held');
    expect(_hint(tester, 'Seconds'), contains('Recorded'));
    await expectFlutterAccessibilityGuidelines(tester);
  });
}

Future<TestValSvc> _openLog(
  WidgetTester tester, {
  String exercise = 'Side Plank',
  String history = '',
  Size size = const Size(390, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final service = TestValSvc.fromRows(
    [
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      [
        'Side Plank',
        '3',
        '45s',
        '',
        '30s@8',
        '',
        '{Seconds}s@{RPE}',
        'Core',
        '',
        'x',
        history,
      ],
      [
        'Wall Sit',
        '3',
        '45s',
        '',
        '40@8',
        '',
        '{Hold}@{RPE}',
        'Core',
        '',
        'x',
        '',
      ],
    ],
    exercisesRows: [
      exercisesSheetColumns,
      [
        'Side Plank',
        'Timed hold',
        '3',
        '45s',
        '',
        '',
        '{Seconds}s@{RPE}',
        '30s@8',
        "['Seconds']",
      ],
      [
        'Wall Sit',
        'Timed hold with an exercise-specific label',
        '3',
        '45s',
        '',
        '',
        '{Hold}@{RPE}',
        '40@8',
        "['Hold']",
      ],
    ],
    cellFormulas: [
      ...exerciseRowFormulas(sheetRowNumber: 3, exercisesRowNumber: 2),
      ...exerciseRowFormulas(sheetRowNumber: 4, exercisesRowNumber: 3),
    ],
  );

  await tester.pumpWidget(
    WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
  );
  await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
  await tester.pump();
  await tester.pump();
  await tester.tap(find.text(exercise));
  await tester.pumpAndSettle();
  return service;
}

Future<void> _startTimer(WidgetTester tester, String seconds) async {
  await tester.enterText(_field('Seconds'), seconds);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('set-timer-Seconds')));
  await tester.pump();
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save set S1'));
  await tester.tap(find.text('Save set S1'));
  await tester.pump();
  await tester.pump();
}

void _suspend(WidgetTester tester) {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void _resume(WidgetTester tester) {
  for (final state in const [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

Finder _field(String label) => find.byKey(ValueKey('set-field-$label'));

String _value(String label) => editableTextFor(_field(label)).controller.text;

TextStyle? _style(WidgetTester tester, String label) {
  return tester.widget<TextField>(_field(label)).style;
}

String _hint(WidgetTester tester, String label) {
  return tester.getSemantics(find.bySemanticsLabel('New set $label')).hint;
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

String _countdown(WidgetTester tester) {
  return tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('countdown-toggle')),
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

/// Records the platform calls the app makes, such as its completion signal.
List<String> _recordPlatformCalls(WidgetTester tester) {
  final calls = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method.startsWith('HapticFeedback')) calls.add(call.method);
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}
