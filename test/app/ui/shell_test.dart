import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

import '../service_fake.dart';
import '../../support/widget.dart';

void main() {
  testWidgets('meets Flutter accessibility guidelines across core GUI states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );
    await expectFlutterAccessibilityGuidelines(tester);

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await expectFlutterAccessibilityGuidelines(tester);

    await tester.tap(find.byKey(const ValueKey('select-workout-setup')));
    await tester.pumpAndSettle();
    await expectFlutterAccessibilityGuidelines(tester);

    await tester.tap(find.text('Squat').first);
    await tester.pumpAndSettle();
    await expectFlutterAccessibilityGuidelines(tester);

    await tester.tap(find.byTooltip('Back to exercises'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to workout setup'));
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
        key: const ValueKey('inventory-accessibility-app'),
        svc: inventoryService,
        initialText: 'spreadsheet-id',
      ),
    );
    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();
    await expectFlutterAccessibilityGuidelines(tester);

    await tester.tap(find.byKey(const ValueKey('add-canonical-exercise')));
    await tester.pumpAndSettle();
    await expectFlutterAccessibilityGuidelines(tester);
  });
}
