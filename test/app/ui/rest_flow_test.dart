import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/src/app/rest.dart';

import '../../support/widget.dart';
import '../service_fake.dart';

void main() {
  testWidgets('rest is headed REST and leaves the app interactive', (
    tester,
  ) async {
    await _openLog(tester, rest: '90s', sets: '3');
    await _save(tester);

    expect(find.byKey(const ValueKey('countdown-bar')), findsOneWidget);
    expect(find.text('REST'), findsOneWidget);

    final field = find.byKey(const ValueKey('set-field-RPE'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pump();

    expect(
      editableTextFor(field).focusNode.hasFocus,
      isTrue,
      reason: 'a rest countdown must stay nonmodal',
    );
    expect(find.byKey(const ValueKey('countdown-bar')), findsOneWidget);
  });

  testWidgets('a running countdown stays reachable by screen reader', (
    tester,
  ) async {
    await _openLog(tester, rest: '90s', sets: '3');
    await _save(tester);

    // The page area sits behind a modal route barrier. Reading the compiled
    // semantics tree, rather than the bar's widget configuration, is what
    // proves the barrier does not swallow the controls above it.
    expect(find.semantics.byLabel('REST'), findsOne);
    expect(find.semantics.byLabel(RegExp('^Pause REST timer, ')), findsOne);
    expect(find.semantics.byLabel('+30 s'), findsOne);
    expect(find.semantics.byLabel('Done'), findsOne);
    expect(
      find.semantics.byLabel('New set RPE'),
      findsOne,
      reason: 'rest is nonmodal, so the page stays reachable too',
    );
  });

  testWidgets('rest timer runs while the set write is still in flight', (
    tester,
  ) async {
    await _openService(
      tester,
      CompletingWriteValidationService(minimalValidParsedSheet()),
    );

    await _save(tester);

    expect(find.byKey(const ValueKey('countdown-bar')), findsOneWidget);
    expect(find.text('180'), findsOneWidget);
  });

  testWidgets(
    'successful set save starts a top timer that survives navigation',
    (tester) async {
      await _openLog(tester, rest: '3 min', sets: '3');

      await _save(tester);

      final timer = find.byKey(const ValueKey('countdown-bar'));
      expect(timer, findsOneWidget);
      expect(find.text('180'), findsOneWidget);
      expect(
        tester.getTopLeft(timer).dy,
        lessThan(tester.getTopLeft(find.byTooltip('Back to exercises')).dy),
      );

      final top = tester.getTopLeft(timer).dy;
      await tester.showKeyboard(find.byKey(const ValueKey('set-field-RPE')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 330);
      await tester.pump();

      expect(timer, findsOneWidget);
      expect(tester.getTopLeft(timer).dy, top);

      await tester.tap(find.byTooltip('Back to exercises'));
      await tester.pumpAndSettle();

      expect(find.text('Exercises'), findsOneWidget);
      expect(timer, findsOneWidget);
      expect(find.text('180'), findsOneWidget);
    },
  );

  testWidgets('rest pauses, extends, and dismisses from its own controls', (
    tester,
  ) async {
    await _openLog(tester, rest: '90s', sets: '3');
    await _save(tester);

    expect(find.text('90'), findsOneWidget);
    expect(find.text('+30 s'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // The countdown button's accessible pause/resume state is proven where it
    // is announceable, in test/app/ui/countdown_bar_test.dart.
    await tester.tap(find.byKey(const ValueKey('countdown-toggle')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('90'), findsOneWidget, reason: 'pause holds the time');

    await tester.tap(find.text('+30 s'));
    await tester.pump();
    expect(find.text('120'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('countdown-toggle')));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('115'), findsOneWidget, reason: 'resume continues it');

    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
  });

  testWidgets('countdown disappears when it reaches zero', (tester) async {
    await _openLog(tester, rest: '1s', sets: '2');
    await _save(tester);

    expect(find.text('1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
  });

  testWidgets('noninteger set prescription still starts a rest timer', (
    tester,
  ) async {
    await _openLog(tester, rest: '90s', sets: '3-4');
    await _save(tester);

    expect(find.byKey(const ValueKey('countdown-bar')), findsOneWidget);
  });

  testWidgets('final planned set starts a rest timer', (tester) async {
    await _openLog(tester, rest: '90s', sets: '1');
    await _save(tester);

    expect(find.byKey(const ValueKey('countdown-bar')), findsOneWidget);
  });

  testWidgets('unitless rest starts a timer in seconds', (tester) async {
    await _openLog(tester, rest: '120', sets: '3');
    await _save(tester);

    expect(find.byKey(const ValueKey('countdown-bar')), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
  });

  testWidgets('blank rest starts no timer', (tester) async {
    await _openLog(tester, rest: '', sets: '3');
    await _save(tester);

    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
  });

  testWidgets('blank fields neither save nor start rest', (tester) async {
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      [
        'Squat',
        '3',
        '90s',
        '',
        '',
        '',
        '{Weight}x{Reps}@{RPE}',
        'Legs',
        '',
        'x',
        '',
      ],
    ]);
    await _openService(tester, service);

    await _save(tester);

    expect(service.appliedPlans, isEmpty);
    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
  });

  testWidgets('unparseable rest starts no timer', (tester) async {
    await _openLog(tester, rest: 'eventually', sets: '3');
    await _save(tester);

    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
  });

  test('supported rest spellings resolve', () {
    expect(restDuration('120'), const Duration(seconds: 120));
    expect(restDuration('3 min'), const Duration(minutes: 3));
    expect(restDuration('90s'), const Duration(seconds: 90));
    expect(restDuration('1.5 min'), const Duration(seconds: 90));
    expect(restDuration('3:00'), const Duration(minutes: 3));
  });

  testWidgets('failed set save leaves its started rest timer running', (
    tester,
  ) async {
    final service = FailingWriteValidationService(minimalValidParsedSheet());
    await _openService(tester, service);

    await _save(tester);

    expect(find.text('Unable to save set'), findsOneWidget);
    expect(find.byKey(const ValueKey('countdown-bar')), findsOneWidget);
    expect(find.text('180'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('175'), findsOneWidget);
    await _save(tester);
    expect(find.text('180'), findsOneWidget);
  });

  testWidgets('unusable rest starts no timer while a write is in flight', (
    tester,
  ) async {
    await _openService(
      tester,
      CompletingWriteValidationService(_sheet(rest: 'later')),
    );

    await _save(tester);

    expect(find.byKey(const ValueKey('countdown-bar')), findsNothing);
  });

  testWidgets('timer controls remain accessible on a narrow large-text phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await _openLog(tester, rest: '90s', sets: '3', configureView: false);
    await _save(tester);

    expect(tester.takeException(), isNull);
    await expectFlutterAccessibilityGuidelines(tester);
  });
}

Future<void> _openLog(
  WidgetTester tester, {
  required String rest,
  required String sets,
  bool configureView = true,
}) async {
  final service = TestValSvc.fromRows([
    [...activeSheetFixedColumns, 'Week 1'],
    [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
    [
      'Squat',
      sets,
      rest,
      '',
      'x5@8',
      '',
      '{Weight}x{Reps}@{RPE}',
      'Legs',
      '',
      'x',
      '',
    ],
  ]);
  await _openService(tester, service, configureView: configureView);
}

Future<void> _openService(
  WidgetTester tester,
  WbkAccess service, {
  bool configureView = true,
}) async {
  if (configureView) {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  await tester.pumpWidget(
    WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
  );
  await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
  await tester.pump();
  await tester.pump();
  await tester.tap(find.text('Squat'));
  await tester.pumpAndSettle();
}

ParsedActiveSheet _sheet({required String rest}) {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Squat',
          '3',
          rest,
          '',
          'x5@8',
          '',
          '{Weight}x{Reps}@{RPE}',
          'Legs',
          '',
          'x',
          '',
        ],
      ],
    ),
  );
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save set S1'));
  await tester.tap(find.text('Save set S1'));
  await tester.pump();
  await tester.pump();
}
