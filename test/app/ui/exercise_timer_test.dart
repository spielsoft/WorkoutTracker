import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/src/app/logging_new_set.dart';

import '../service_fake.dart';
import '../../support/widget.dart';

// Countdown mechanics themselves - exact fractional deadlines, replacement,
// lifecycle correction, and one completion signal - are proven against the
// countdown engine in countdown_ctrl_test.dart. These tests prove only what
// the application shell adds: which fields offer a timer, the policy the shell
// hands the countdown, and what a finished countdown writes back.
//
// The recorded platform calls prove only which signal the app requests. Real
// haptic hardware stays physical-device acceptance work.
void main() {
  testWidgets('a differently named canonical field is timeable', (
    tester,
  ) async {
    await _openLog(tester, exercise: 'Wall Sit');

    expect(
      find.semantics.byLabel('Start Wall Sit Hold timer, 40 seconds'),
      findsOne,
    );
    expect(
      _timerControls,
      findsOne,
      reason: 'the same exercise leaves its RPE field untimed',
    );
  });

  testWidgets('the timer control names its exercise, field, and readiness', (
    tester,
  ) async {
    await _openLog(tester);

    final control = find.byKey(const ValueKey('set-timer-Seconds'));

    for (final usable in const ['30', ' 2.6 ', '0.25']) {
      await tester.enterText(_field('Seconds'), usable);
      await tester.pump();

      expect(
        tester.getSemantics(control),
        matchesSemantics(
          label: 'Start Side Plank Seconds timer, ${usable.trim()} seconds',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
        reason:
            'a positive finite number of seconds can start a countdown, '
            'including "$usable"',
      );
    }

    for (final unusable in const [
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
      await tester.enterText(_field('Seconds'), unusable);
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
        reason: 'nothing can start from "$unusable"',
      );
    }
  });

  testWidgets('timer controls stay out of logged set editing and placement', (
    tester,
  ) async {
    await _openLog(tester, history: '20s@8');

    expect(_timerControls, findsOne);

    await tester.tap(find.byKey(const ValueKey('edit-S1')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('logged-S1-field-Seconds')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _loggedSetEditor('S1'), matching: _timerButtons),
      findsNothing,
      reason: 'the open logged set editor offers no way to start a timer',
    );
    expect(
      find.descendant(of: find.byType(NewSetEditor), matching: _timerButtons),
      findsOne,
      reason: 'only the new set editor may start a timer',
    );
    expect(
      _timerControls,
      findsOne,
      reason: 'and that is the only such control on the screen',
    );

    await tester.tap(find.byTooltip('Back to exercises'));
    await tester.pumpAndSettle();

    expect(_timerControls, findsNothing);

    await tester.tap(find.byKey(const ValueKey('add-primary-exercise')));
    await tester.pumpAndSettle();

    expect(find.text('Choose exercise'), findsOneWidget);
    expect(_timerControls, findsNothing);
  });

  testWidgets('the icon times the exact field value and records what it ran', (
    tester,
  ) async {
    final signals = _recordPlatformCalls(tester);
    final service = await _openLog(tester);

    await tester.enterText(_field('Seconds'), '2.6');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('set-timer-Seconds')));
    await tester.pump();

    expect(find.byKey(const ValueKey('countdown-bar')), findsOneWidget);
    expect(
      _countdownName(tester),
      'Pause Side Plank timer, 3 seconds remaining',
      reason: 'the shell heads the countdown with the exercise being timed',
    );
    expect(_value('Seconds'), '2.6', reason: 'starting never edits the field');
    expect(signals, isEmpty);

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();

    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
    expect(signals, ['HapticFeedback.vibrate']);
    expect(
      _value('Seconds'),
      '3',
      reason: 'the field that started the countdown receives what it measured',
    );
    expect(_hint(tester, 'Seconds'), contains('Recorded'));
    expect(service.appliedPlans, isEmpty, reason: 'recording never saves');
    expect(find.text('Save set S1'), findsOneWidget);
  });

  testWidgets('a hold stopped at once still records a full second', (
    tester,
  ) async {
    final service = await _openLog(tester);
    await _startTimer(tester, '45');

    await tester.tap(find.byKey(const ValueKey('countdown-done')));
    await tester.pump();

    expect(
      _value('Seconds'),
      '1',
      reason: 'a zero would replace the prescription and disable the timer',
    );
    expect(
      find.bySemanticsLabel(RegExp('^Start .+ Seconds timer, 1 seconds')),
      findsOne,
      reason: 'the recorded value can start another countdown',
    );
    expect(service.appliedPlans, isEmpty);
  });

  testWidgets('a recorded duration rounds exactly as the visible countdown', (
    tester,
  ) async {
    await _openLog(tester);
    await _startTimer(tester, '9.5');

    expect(
      _countdownName(tester),
      'Pause Side Plank timer, 10 seconds remaining',
      reason: 'the display rounds to nearest',
    );

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
    expect(
      recorded,
      isNot('Suggested value; edit to confirm'),
      reason: 'measured data is not announced as an unconfirmed suggestion',
    );
    expect(recorded, isNot(_hint(tester, 'RPE')));
    await expectFlutterAccessibilityGuidelines(tester);
  });

  testWidgets('ending a countdown writes only the field that started it', (
    tester,
  ) async {
    await _openLog(tester);

    expect(_value('RPE'), '8');
    expect(_hint(tester, 'RPE'), contains('Suggested'));

    await _startTimer(tester, '45');
    await tester.pump(const Duration(seconds: 30));
    await tester.tap(find.byKey(const ValueKey('countdown-done')));
    await tester.pump();

    expect(_value('Seconds'), '30');
    expect(_value('RPE'), '8');
    expect(
      _hint(tester, 'RPE'),
      contains('Suggested'),
      reason: 'another field keeps its own text and origin',
    );
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
  });

  testWidgets('a rest countdown ends without recording any field', (
    tester,
  ) async {
    await _openLog(tester);
    await _save(tester);

    expect(_countdownName(tester), 'Pause REST timer, 45 seconds remaining');

    await tester.pump(const Duration(seconds: 45));
    await tester.pump();

    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
    expect(_value('Seconds'), '30');
    expect(_value('RPE'), '8');
    expect(_hint(tester, 'Seconds'), contains('Suggested'));
  });

  testWidgets('an exercise timer replaces rest, which then records nothing', (
    tester,
  ) async {
    await _openLog(tester);
    await _save(tester);

    expect(_countdownName(tester), 'Pause REST timer, 45 seconds remaining');

    await _startTimer(tester, '60');

    expect(
      _countdownName(tester),
      'Pause Side Plank timer, 60 seconds remaining',
      reason: 'the shell owns one countdown, and the exercise takes it over',
    );
    expect(find.byKey(const ValueKey('countdown-bar')), findsOneWidget);

    await tester.pump(const Duration(seconds: 45));
    await tester.pump();

    expect(
      _value('Seconds'),
      '60',
      reason: 'the displaced rest countdown records nothing at its own end',
    );
    expect(
      _countdownName(tester),
      'Pause Side Plank timer, 15 seconds remaining',
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.byKey(const ValueKey('countdown-done')));
    await tester.pump();

    expect(_value('Seconds'), '50');
  });

  testWidgets('starting a timer changes no set value, workbook, or rest', (
    tester,
  ) async {
    final service = await _openLog(tester);

    expect(_value('Seconds'), '30');
    expect(_hint(tester, 'Seconds'), contains('Suggested'));

    await tester.tap(find.byKey(const ValueKey('set-timer-Seconds')));
    await tester.pump();

    expect(find.byKey(const ValueKey('countdown-bar')), findsOneWidget);
    expect(
      _value('Seconds'),
      '30',
      reason: 'timing must not edit or confirm a suggested value',
    );
    expect(service.appliedPlans, isEmpty);
    expect(find.text('Save set S1'), findsOneWidget);
    expect(
      _countdownName(tester),
      startsWith('Pause Side Plank timer'),
      reason: 'starting an exercise timer never starts rest',
    );
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
    expect(_countdownName(tester), 'Pause REST timer, 45 seconds remaining');

    await tester.enterText(_field('Seconds'), '-4');
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('set-timer-Seconds')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(
      _countdownName(tester),
      'Pause REST timer, 45 seconds remaining',
      reason: 'an unusable value must leave the running countdown alone',
    );
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
    expect(
      _countdownName(tester),
      'Pause Side Plank timer, 90 seconds remaining',
    );
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

  testWidgets('exercise timing stays usable on a narrow large-text phone', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _openLog(tester, size: const Size(320, 1400));
    await _startTimer(tester, '45');

    expect(tester.takeException(), isNull);
    expect(_countdownName(tester), startsWith('Pause Side Plank timer'));
    // How the bar itself lays out at this size belongs to
    // countdown_bar_test.dart; this test covers what the log screen adds.
    expect(
      find.semantics.byLabel('New set Seconds'),
      findsNothing,
      reason: 'a locked control is not announced at this size either',
    );
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

/// Every control that can start an exercise countdown, located by the
/// accessible name the product promises rather than by its icon glyph.
final _timerControls = find.semantics.byLabel(RegExp(r'^Start .+ timer'));

/// The same controls as widgets, so a finder can ask which editor holds one.
final _timerButtons = find.bySemanticsLabel(RegExp(r'^Start .+ timer'));

/// What the editor for logged set [setLabel] draws: the innermost widget
/// holding both one of its fields and its own Cancel control.
///
/// Bounded by the keys that editor already exposes rather than by a layout
/// type, so it still names the same region after a layout rewrite.
Finder _loggedSetEditor(String setLabel) {
  return find
      .ancestor(
        of: find.byKey(ValueKey('logged-$setLabel-field-Seconds')),
        matching: find.ancestor(
          of: find.byKey(ValueKey('cancel-$setLabel')),
          matching: find.byWidgetPredicate((_) => true),
        ),
      )
      .first;
}

Finder _field(String label) => find.byKey(ValueKey('set-field-$label'));

String _value(String label) => editableTextFor(_field(label)).controller.text;

String _hint(WidgetTester tester, String label) {
  return tester.getSemantics(find.bySemanticsLabel('New set $label')).hint;
}

/// The running countdown as a screen reader announces it: which timer it is
/// and how many whole seconds remain.
String _countdownName(WidgetTester tester) {
  return tester
      .getSemantics(find.byKey(const ValueKey('countdown-toggle')))
      .label;
}

/// Effective opacity applied to the app below the countdown bar.
///
/// Reading the rendered opacity is a deliberate last resort: it is the only
/// local evidence that a locked app is dimmed rather than merely inert. How
/// that dim actually reads on a device stays physical acceptance work.
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
