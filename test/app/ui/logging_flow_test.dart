import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

import '../service_fake.dart';
import '../../support/widget.dart';

void main() {
  testWidgets('renders the main logging flow and sends a save to the service', (
    tester,
  ) async {
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 2', 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1'],
      [
        'Squat',
        '3',
        '5',
        '8',
        '3 min',
        'Controlled',
        'Stay braced.',
        '',
        'Legs',
        '',
        '',
        '',
      ],
      ['Bench Press', '4', '6', '8', '3 min', '', '', '', 'Upper', '', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );

    expect(find.text('WorkoutTracker'), findsNothing);
    expect(
      find.byKey(const ValueKey('spreadsheet-selection-input')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    expect(service.spreadsheetIds, ['spreadsheet-id']);
    expect(find.byKey(const ValueKey('workout-home')), findsOneWidget);
    expect(find.byTooltip('Back to sheet selection'), findsOneWidget);
    expect(find.text('Workout'), findsOneWidget);
    expect(find.text('History block'), findsOneWidget);
    expect(find.text('Legs (0/1 started)'), findsOneWidget);
    expect(find.text('Legs exercises'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);

    await tester.tap(find.text('Week 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week 1').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Legs (0/1 started)').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upper (0/1 started)').last);
    await tester.pumpAndSettle();

    expect(find.text('Upper exercises'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.byKey(const ValueKey('workout-home')), findsOneWidget);

    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsWidgets);
    expect(find.text('Bench Press logging'), findsNothing);
    expect(find.byTooltip('Back to exercises'), findsOneWidget);
    expect(find.text('Workout setup'), findsNothing);
    expect(find.text('Upper exercises'), findsNothing);
    expect(find.byKey(const ValueKey('set-field-Weight')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-field-Reps')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-field-RPE')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('set-field-Weight')),
      '155',
    );
    await tester.enterText(find.byKey(const ValueKey('set-field-Reps')), '6');
    await tester.enterText(find.byKey(const ValueKey('set-field-RPE')), '8');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save set'));
    await tester.pump();
    await tester.pump();

    expect(service.appliedPlans, hasLength(1));
    expect(service.appliedPlans.single.cellUpdates.single.value, '155x6@8');
    expect(find.text('Next set S2'), findsOneWidget);
  });

  testWidgets('does not launch duplicate Save set actions while pending', (
    tester,
  ) async {
    final service = CompletingWriteValidationService(minimalValidParsedSheet());

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('set-field-Weight')),
      '155',
    );
    await tester.enterText(find.byKey(const ValueKey('set-field-Reps')), '6');
    await tester.enterText(find.byKey(const ValueKey('set-field-RPE')), '8');

    await tester.tap(find.text('Save set'));
    await tester.tap(find.text('Save set'));

    expect(service.appliedPlans, hasLength(1));
  });

  testWidgets('shows failed Save set writes near logging controls', (
    tester,
  ) async {
    final service = FailingWriteValidationService(minimalValidParsedSheet());

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('set-field-Weight')),
      '155',
    );
    await tester.enterText(find.byKey(const ValueKey('set-field-Reps')), '6');
    await tester.enterText(find.byKey(const ValueKey('set-field-RPE')), '8');
    await tester.tap(find.text('Save set'));
    await tester.pump();
    await tester.pump();

    expect(service.appliedPlans, hasLength(1));
    expect(find.byKey(const ValueKey('logging-write-error')), findsOneWidget);
    expect(
      find.text('Unable to save set: Bad state: network unavailable'),
      findsOneWidget,
    );
  });

  testWidgets(
    'keeps attempted next-set input recoverable after confirmation conflict',
    (tester) async {
      final service = RecoverableConfirmationFailureService();

      await tester.pumpWidget(
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Squat'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('set-field-Weight')),
        '155',
      );
      await tester.enterText(find.byKey(const ValueKey('set-field-Reps')), '6');
      await tester.enterText(find.byKey(const ValueKey('set-field-RPE')), '8');
      await tester.tap(find.text('Save set'));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans, hasLength(1));
      expect(service.appliedPlans.single.nextSetPosition?.setNumber, 3);
      expect(find.byKey(const ValueKey('logging-write-error')), findsOneWidget);
      expect(find.text('Next set S2'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('set-field-Weight')))
            .controller
            ?.text,
        '155',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('set-field-Reps')))
            .controller
            ?.text,
        '6',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('set-field-RPE')))
            .controller
            ?.text,
        '8',
      );

      await tester.tap(find.text('Save set'));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans, hasLength(2));
      expect(
        service.appliedPlans.map((plan) => plan.nextSetPosition?.setNumber),
        [3, 3],
      );
      expect(find.byKey(const ValueKey('logging-write-error')), findsNothing);
      expect(find.text('Next set S3'), findsOneWidget);
    },
  );

  testWidgets('compresses logging context and history until expanded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 2', 'Week 1', ''],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1', 'S2'],
      [
        'Carry',
        '3',
        '40',
        '8',
        '90s',
        'Smooth',
        'Stay tall.',
        '{Distance}[@]{RPE}',
        'Conditioning',
        '',
        'worked up, grip failed',
        '30@7',
        '35@8',
      ],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Carry'));
    await tester.pumpAndSettle();

    expect(find.text('Carry'), findsWidgets);
    expect(find.text('Carry logging'), findsNothing);
    expect(find.text('Next set S2'), findsOneWidget);
    expect(find.text('Logged sets'), findsOneWidget);
    expect(textFieldWithLabel('Raw set text'), findsOneWidget);
    expect(find.text('Training details'), findsOneWidget);
    expect(find.text('Plan 3 x 40 @ 8'), findsOneWidget);
    expect(find.text('Rest 90s | Tempo Smooth'), findsOneWidget);
    expect(find.text('Target: 3 sets x 40 @ 8'), findsNothing);
    expect(find.text('Rest: 90s'), findsNothing);
    expect(find.text('Tempo: Smooth'), findsNothing);
    expect(find.text('Notes: Stay tall.'), findsNothing);
    expect(find.text('Recent history'), findsOneWidget);
    expect(find.text('Week 1: 30@7, 35@8'), findsOneWidget);
    expect(find.text('Week 1'), findsNothing);
    expect(find.text('Week 1 S1: 30@7'), findsNothing);
    expect(find.text('S1: 30@7'), findsNothing);
    expect(find.text('S2: 35@8'), findsNothing);

    await tester.tap(find.text('Training details'));
    await tester.pumpAndSettle();

    expect(find.text('Target: 3 sets x 40 @ 8'), findsOneWidget);
    expect(find.text('Rest: 90s'), findsOneWidget);
    expect(find.text('Tempo: Smooth'), findsOneWidget);
    expect(find.text('Notes: Stay tall.'), findsOneWidget);
    expect(find.text('Latest history: 35@8'), findsOneWidget);

    await tester.tap(find.text('Recent history'));
    await tester.pumpAndSettle();

    expect(find.text('S1: 30@7'), findsOneWidget);
    expect(find.text('S2: 35@8'), findsOneWidget);
  });

  testWidgets('presents logged current and backup states in the logging flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
      [
        'Pull Up',
        '3',
        '8',
        '8',
        '2 min',
        '',
        'Full hang.',
        '{Reps}',
        'Upper',
        '',
        '12',
        '',
      ],
      [
        'Front Plank',
        '3',
        '45s',
        '8',
        '60s',
        '',
        'Brace hard.',
        '{Seconds}[s@]{RPE}',
        'Upper',
        'TRUE',
        '',
        '',
      ],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Pull Up'));
    await tester.pumpAndSettle();

    expect(find.text('Progress 1/3'), findsOneWidget);
    expect(find.text('Logged S1'), findsOneWidget);
    expect(find.text('Current S2'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Front Plank'), findsOneWidget);
  });

  testWidgets(
    'switching to a backup row refreshes structured labels and parsed values',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = TestValSvc.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Pull Up',
          '3',
          '8',
          '8',
          '2 min',
          '',
          'Full hang.',
          '{Reps}',
          'Upper',
          '',
          '12',
        ],
        [
          'Front Plank',
          '3',
          '45s',
          '8',
          '60s',
          '',
          'Brace hard.',
          '{Seconds}[s@]{RPE}',
          'Upper',
          'TRUE',
          '45s@8',
        ],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Pull Up'));
      await tester.pumpAndSettle();

      expect(find.text('Front Plank'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('logged-S1-field-Reps')),
        findsOneWidget,
      );

      await tester.tap(find.text('Front Plank'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('set-field-Seconds')), findsOneWidget);
      expect(find.byKey(const ValueKey('set-field-RPE')), findsOneWidget);
      expect(find.byKey(const ValueKey('set-field-Reps')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('logged-S1-field-Seconds')),
        '50',
      );
      await tester.tap(find.byTooltip('Save structured set'));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans.single.cellUpdates.single.value, '50s@8');

      await tester.tap(find.byTooltip('Clear set'));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans.last.cellUpdates.single.value, isEmpty);
    },
  );
}
