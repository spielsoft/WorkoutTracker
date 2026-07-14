import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

import '../service_fake.dart';
import '../../support/widget.dart';

void main() {
  testWidgets(
    'logs and rereads five-field DB Step-Up while preserving raw history',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      const format = '({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}';
      final service = TestValSvc.fromRows([
        [...activeSheetFixedColumns, 'Week 1', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
        [
          'DB Step-Up',
          '3',
          '90s',
          '3-1-1',
          '(12, 15)x8@8,0',
          'Control the descent.',
          format,
          'Legs',
          '',
          'x',
          '12x8@8,0',
          '',
        ],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
      );
      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('DB Step-Up'));
      await tester.pumpAndSettle();

      const fields = ['Height (in)', 'Weight (lbs)', 'Reps', 'RPE', 'Pain'];
      for (final label in fields) {
        final field = find.bySemanticsLabel('New set $label');
        expect(field, findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find.descendant(of: field, matching: find.byType(TextField)),
              )
              .keyboardType,
          const TextInputType.numberWithOptions(decimal: true),
        );
      }
      final tops = [
        for (final label in fields)
          tester.getTopLeft(find.bySemanticsLabel('New set $label')).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(find.text('Height (in) (12)'), findsOneWidget);
      expect(find.text('Weight (lbs) (15)'), findsOneWidget);
      expect(find.text('Save set S2'), findsOneWidget);

      const edited = {
        'Height (in)': '14',
        'Weight (lbs)': '20',
        'Reps': '10',
        'RPE': '9',
        'Pain': '1',
      };
      for (final entry in edited.entries) {
        await tester.enterText(
          find.bySemanticsLabel('New set ${entry.key}'),
          entry.value,
        );
      }
      await tester.ensureVisible(find.text('Save set S2'));
      await tester.tap(find.text('Save set S2'));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans, hasLength(1));
      expect(
        service.appliedPlans.single.cellUpdates.single.value,
        '(14, 20)x10@9,1',
      );
      for (final entry in edited.entries) {
        _expectFieldValue(entry.key, entry.value);
      }
      expect(find.text('Save set S3'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit S1'));
      await tester.pump();
      final raw = find.bySemanticsLabel('S1 raw set text');
      expect(raw, findsOneWidget);
      await tester.enterText(raw, '12x9@8,0');
      await tester.tap(find.byTooltip('Save raw set text'));
      await tester.pump();

      expect(service.appliedPlans, hasLength(2));
      expect(service.appliedPlans.last.cellUpdates.single.value, '12x9@8,0');
    },
  );

  testWidgets('renders the main logging flow and sends a save to the service', (
    tester,
  ) async {
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 2', 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1'],
      [
        'Squat',
        '3',
        '3 min',
        'Controlled',
        'x5@8',
        'Stay braced.',
        '',
        'Legs',
        '',
        'x',
        '',
        '',
      ],
      [
        'Bench Press',
        '4',
        '3 min',
        '2-1-1',
        'x6@8',
        '',
        '',
        'Upper',
        '',
        'x',
        '',
        '',
      ],
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
    await tester.tap(find.text('Save set S1'));
    await tester.pump();
    await tester.pump();

    expect(service.appliedPlans, hasLength(1));
    expect(service.appliedPlans.single.cellUpdates.single.value, '155x6@8');
    expect(find.text('Save set S2'), findsOneWidget);
    _expectFieldValue('Weight', '155');
    _expectFieldValue('Reps', '6');
    _expectFieldValue('RPE', '8');
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

    await tester.tap(find.text('Save set S1'));
    await tester.tap(find.text('Save set S1'));

    expect(service.appliedPlans, hasLength(1));
  });

  testWidgets('final forward action cannot bypass pending save protection', (
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
      '155.5',
    );
    await tester.enterText(find.byKey(const ValueKey('set-field-Reps')), '6');
    await tester.enterText(find.byKey(const ValueKey('set-field-RPE')), '8');
    await tester.tap(find.byKey(const ValueKey('set-field-RPE')));
    await tester.pump();

    final forward = find.bySemanticsLabel('Save set S1 from keyboard');
    expect(forward, findsOneWidget);
    await tester.tap(forward);
    await tester.tap(forward);

    expect(service.appliedPlans, hasLength(1));
    expect(service.appliedPlans.single.cellUpdates.single.value, '155.5x6@8');
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
    await tester.tap(find.text('Save set S1'));
    await tester.pump();
    await tester.pump();

    expect(service.appliedPlans, hasLength(1));
    expect(
      find.text('Unable to save set: Bad state: network unavailable'),
      findsOneWidget,
    );
    expect(find.text('Save set S1'), findsOneWidget);
    _expectFieldValue('Weight', '155');
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
      await tester.tap(find.text('Save set S2'));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans, hasLength(1));
      expect(service.appliedPlans.single.nextSetPosition?.setNumber, 3);
      expect(
        find.text(
          'Unable to save set: saved set was not visible after refresh.',
        ),
        findsOneWidget,
      );
      expect(find.text('Save set S2'), findsOneWidget);
      _expectFieldValue('Weight', '155');
      _expectFieldValue('Reps', '6');
      _expectFieldValue('RPE', '8');

      await tester.tap(find.text('Save set S2'));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans, hasLength(2));
      expect(
        service.appliedPlans.map((plan) => plan.nextSetPosition?.setNumber),
        [3, 3],
      );
      expect(
        find.text(
          'Unable to save set: saved set was not visible after refresh.',
        ),
        findsNothing,
      );
      expect(find.text('Save set S3'), findsOneWidget);
    },
  );

  testWidgets('shows static logging context and expandable history', (
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
        '120s',
        'Smooth',
        'Stay tall.',
        '{Distance}@{RPE}',
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
    expect(find.text('Next set S2'), findsNothing);
    expect(find.text('Save set S2'), findsOneWidget);
    expect(find.text('Logged sets'), findsOneWidget);
    expect(find.text('worked up, grip failed'), findsOneWidget);
    expect(textFieldWithLabel('Raw set text'), findsNothing);
    expect(find.text('Training details'), findsNothing);
    expect(find.text('3 sets | 120 s Rest'), findsOneWidget);
    expect(find.textContaining('40@8'), findsNothing);
    expect(find.textContaining('Tempo'), findsNothing);
    expect(find.text('Notes: Stay tall.'), findsNothing);
    expect(find.text('Stay tall.'), findsOneWidget);
    expect(find.text('Recent history'), findsOneWidget);
    expect(find.text('Week 1: 30@7, 35@8'), findsOneWidget);
    expect(find.text('Week 1'), findsNothing);
    expect(find.text('Week 1 S1: 30@7'), findsNothing);
    expect(find.text('S1: 30@7'), findsNothing);
    expect(find.text('S2: 35@8'), findsNothing);

    await tester.tap(find.text('Recent history'));
    await tester.pumpAndSettle();

    expect(find.text('S1: 30@7'), findsOneWidget);
    expect(find.text('S2: 35@8'), findsOneWidget);
  });

  testWidgets('presents the next set and backup role in the logging flow', (
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
        '{Seconds}s@{RPE}',
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

    expect(find.text('Save set S2'), findsOneWidget);
    expect(find.text('Progress 1/3'), findsNothing);
    expect(find.text('Logged S1'), findsNothing);
    expect(find.text('Current S2'), findsNothing);
    expect(find.text('Backup'), findsNothing);
    expect(find.byIcon(Icons.alt_route_outlined), findsOneWidget);
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
          '{Seconds}s@{RPE}',
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
      await tester.tap(find.text('Front Plank'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('set-field-Seconds')));
      await tester.pump();
      expect(find.bySemanticsLabel('Next field RPE'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('edit-S1')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('logged-S1-field-Seconds')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('logged-S1-field-Reps')), findsNothing);

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

void _expectFieldValue(String label, String value) {
  expect(
    find.descendant(
      of: find.bySemanticsLabel('New set $label'),
      matching: find.text(value),
    ),
    findsOneWidget,
  );
}
