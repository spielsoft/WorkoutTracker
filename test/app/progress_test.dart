import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

import 'service_fake.dart';

void main() {
  testWidgets(
    'logging progress uses a positive integer target set count when present',
    (tester) async {
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Split Squat', '3', '8/side', '8', '90s', '', '', '', 'Legs', '', ''],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Split Squat'));
      await tester.pumpAndSettle();

      expect(find.text('Plan 3 x 8/side @ 8'), findsOneWidget);
      expect(find.text('Progress 0/3'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('set-field-Weight')),
        '40',
      );
      await tester.enterText(
        find.byKey(const ValueKey('set-field-Reps')),
        '8/side',
      );
      await tester.enterText(find.byKey(const ValueKey('set-field-RPE')), '8');
      await tester.tap(find.text('Save set'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Next set S2'), findsOneWidget);
      expect(find.text('Progress 1/3'), findsOneWidget);
    },
  );
}
