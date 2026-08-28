import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

import '../service_fake.dart';
import '../../support/widget.dart';

void main() {
  testWidgets('forces dark appearance for every system setting', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    for (final brightness in Brightness.values) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await tester.pumpWidget(
        WorkoutTrackerApp(
          key: ValueKey(brightness),
          svc: TestValSvc.fromRows([
            activeSheetFixedColumns,
            List.filled(activeSheetFixedColumns.length, ''),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
    }
  });

  testWidgets('keeps decorated input labels in the frame app-wide', (
    tester,
  ) async {
    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: TestValSvc.fromRows([
          activeSheetFixedColumns,
          List.filled(activeSheetFixedColumns.length, ''),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(
      theme.inputDecorationTheme.floatingLabelBehavior,
      FloatingLabelBehavior.always,
    );
  });

  testWidgets('repair guidance fits a narrow large-text phone', (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: TestValSvc.fromRows(const [
          ['Exercise', 'Reps'],
          ['Squat', '5'],
        ]),
        initialText: 'spreadsheet-id',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Fix the active sheet structure'), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);
  });

  testWidgets('core workflows remain usable at narrow width with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final service = TestValSvc(
      exerciseInventoryParsedSheet([
        exerciseRow('Squat', description: 'Back squat'),
      ]),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );
    await tester.tap(find.text('Select'));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Exercises'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit exercise library'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Edit exercises'), findsWidgets);

    await tester.tap(find.byTooltip('Create exercise'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('New exercise'), findsWidgets);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add to workout'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Choose exercise'), findsOneWidget);
  });

  testWidgets('meets Flutter accessibility guidelines across core GUI states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    for (final brightness in Brightness.values) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      final service = TestValSvc.fromRows([
        [...activeSheetFixedColumns, 'Week 1', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          'Stay braced.',
          '',
          'Legs',
          '',
          '150x5@8',
          '',
        ],
        [
          'Leg Press',
          '3',
          '10',
          '8',
          '2 min',
          '',
          'Backup if racks are busy.',
          '',
          'Legs',
          'TRUE',
          '',
          '',
        ],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          key: ValueKey('core-$brightness'),
          svc: service,
          initialText: 'spreadsheet-id',
        ),
      );
      await tester.pumpAndSettle();
      await expectFlutterAccessibilityGuidelines(tester);

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await expectFlutterAccessibilityGuidelines(tester);

      await tester.tap(find.text('Squat').first);
      await tester.pumpAndSettle();
      await expectFlutterAccessibilityGuidelines(tester);

      await tester.tap(find.byKey(const ValueKey('set-field-Weight')));
      await tester.pump();
      expect(find.bySemanticsLabel('Next field Reps'), findsOneWidget);
      await expectFlutterAccessibilityGuidelines(tester);

      await tester.tap(find.byTooltip('Back to exercises'));
      await tester.pumpAndSettle();

      final inventoryService = TestValSvc(
        exerciseInventoryParsedSheet([
          exerciseRow('Squat', description: 'Back squat'),
          exerciseRow('Leg Press', description: 'Machine press'),
          exerciseRow('Cable Row', description: 'Seated row'),
        ]),
      );
      await tester.pumpWidget(
        WorkoutTrackerApp(
          key: ValueKey('inventory-$brightness'),
          svc: inventoryService,
          initialText: 'spreadsheet-id',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
      await tester.pumpAndSettle();
      await expectFlutterAccessibilityGuidelines(tester);

      await tester.tap(find.byKey(const ValueKey('add-canonical-exercise')));
      await tester.pumpAndSettle();
      await expectFlutterAccessibilityGuidelines(tester);
    }
  });
}
