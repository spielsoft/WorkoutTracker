import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/main.dart';
import 'package:workout_tracker/sheet_contract.dart';

void main() {
  testWidgets('selects a workout and history block before showing overview', (
    tester,
  ) async {
    final service = _FakeSpreadsheetValidationService(
      parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [...activeSheetFixedColumns, 'Week 2', '', 'Week 1'],
            [
              ...List.filled(activeSheetFixedColumns.length, ''),
              'S1',
              'S2',
              'S1',
            ],
            [
              'Squat',
              '3',
              '5',
              '8',
              '3 min',
              '',
              '',
              'Legs',
              '',
              '225x5@8',
              '',
              '205x5@8',
            ],
            [
              'Leg Press',
              '3',
              '10',
              '8',
              '2 min',
              '',
              'Backup if racks are full.',
              'Legs',
              'TRUE',
              '360x10@8',
              '',
              '',
            ],
            [
              'Deadlift',
              '3',
              '5',
              '8',
              '3 min',
              '',
              '',
              'Legs',
              '',
              '',
              '',
              '',
            ],
            [
              'Bench Press',
              '4',
              '6',
              '8',
              '3 min',
              '',
              '',
              'Upper',
              '',
              '155x6@8',
              '',
              '',
            ],
            ['Plank', '3', '45s', '8', '60s', '', '', '', '', '', '', ''],
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.text('Validate spreadsheet'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Workout'), findsOneWidget);
    expect(find.text('History block'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Leg Press'), findsOneWidget);
    expect(find.text('Deadlift'), findsOneWidget);
    expect(find.text('Bench Press'), findsNothing);
    expect(find.text('2 sets'), findsOneWidget);
    expect(find.text('0 sets'), findsOneWidget);

    final squatTop = tester.getTopLeft(find.text('Squat')).dy;
    final deadliftTop = tester.getTopLeft(find.text('Deadlift')).dy;
    expect(squatTop, lessThan(deadliftTop));

    await tester.tap(find.text('Week 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week 1').last);
    await tester.pumpAndSettle();

    expect(find.text('1 set'), findsOneWidget);

    await tester.tap(find.text('Legs').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(defaultWorkoutName).last);
    await tester.pumpAndSettle();

    expect(find.text('Plank'), findsOneWidget);
    expect(find.text('Squat'), findsNothing);
  });

  testWidgets('creates and selects a new visible history block', (
    tester,
  ) async {
    final rows = [
      [...activeSheetFixedColumns, 'Week 2'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', '', '225x5@8'],
    ];
    final service = _FakeSpreadsheetValidationService.fromRows(rows);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.text('Validate spreadsheet'));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField).last, 'Week 3');
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create history block'));
    await tester.pump();
    await tester.pump();

    expect(service.createdHistoryBlockLabels, ['Week 3']);
    expect(find.text('Week 3'), findsOneWidget);
    expect(find.text('0 sets'), findsOneWidget);
  });

  testWidgets('validates a selected spreadsheet and shows backend issues', (
    tester,
  ) async {
    final service = _FakeSpreadsheetValidationService(
      parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [...activeSheetFixedColumns, 'Week 1'],
            [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
            [
              'Reverse Lunge',
              '3',
              '10/side',
              '8',
              '90s',
              '',
              'Backup if benches are taken.',
              'Legs',
              'TRUE',
              '',
            ],
          ],
          exercisesRows: const [
            [
              'Exercise',
              'Description',
              'Default Sets',
              'Default Reps',
              'Default RPE',
              'Default Rest',
              'Default Tempo',
              'Notes',
            ],
            [
              'Reverse Lunge',
              'Dumbbell reverse lunge',
              '3',
              '10/side',
              '8',
              '90s',
              '',
              'Backup if benches are taken.',
            ],
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText:
            'https://docs.google.com/spreadsheets/d/'
            '$workoutTrackerDevelopmentSpreadsheetId/edit?gid=0#gid=0',
      ),
    );

    await tester.tap(find.text('Validate spreadsheet'));
    await tester.pump();
    await tester.pump();

    expect(service.spreadsheetIds, [workoutTrackerDevelopmentSpreadsheetId]);
    expect(find.text('Sheet contract issues'), findsOneWidget);
    expect(
      find.textContaining(
        'Row 3, Legs: Backup row has no preceding primary row',
      ),
      findsOneWidget,
    );
    expect(find.text('Formula repair needed'), findsOneWidget);
    expect(find.textContaining('Row 3, Reverse Lunge'), findsOneWidget);
    expect(find.textContaining('Exercise: missing formula'), findsOneWidget);
  });

  testWidgets('shows a ready state for a valid selected spreadsheet', (
    tester,
  ) async {
    final service = _FakeSpreadsheetValidationService(
      parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [
              'Exercise',
              'Sets',
              'Reps',
              'RPE',
              'Rest',
              'Tempo',
              'Notes',
              'Workout',
              'is_backup',
              'Week 1',
            ],
            ['', '', '', '', '', '', '', '', '', 'S1'],
            [
              'Squat',
              '3',
              '5',
              '8',
              '3 min',
              '',
              'Stay braced.',
              'Legs',
              '',
              '',
            ],
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.text('Validate spreadsheet'));
    await tester.pump();
    await tester.pump();

    expect(service.spreadsheetIds, ['spreadsheet-id']);
    expect(find.text('Sheet contract valid'), findsOneWidget);
    expect(find.text('Formulas valid'), findsOneWidget);
    expect(find.text('Sheet contract issues'), findsNothing);
    expect(find.text('Formula repair needed'), findsNothing);
  });
}

class _FakeSpreadsheetValidationService
    implements SpreadsheetValidationService {
  _FakeSpreadsheetValidationService(this.activeSheet);

  _FakeSpreadsheetValidationService.fromRows(List<List<String>> rows)
    : activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows)),
      _sourceRows = rows;

  ParsedActiveSheet activeSheet;
  List<List<String>>? _sourceRows;
  final spreadsheetIds = <String>[];
  final createdHistoryBlockLabels = <String>[];

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    spreadsheetIds.add(spreadsheetId);
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
    );
  }

  @override
  Future<SpreadsheetValidationReport> createHistoryBlock({
    required String spreadsheetId,
    required String label,
    required ParsedActiveSheet activeSheet,
  }) async {
    createdHistoryBlockLabels.add(label);
    final sourceRows = _sourceRows;
    if (sourceRows != null) {
      final previewRows = activeSheet
          .planNewHistoryBlock(label: label)
          .previewRowsAfterApplying(sourceRows);
      this.activeSheet = parseActiveSheet(ActiveSheetInput(rows: previewRows));
      _sourceRows = previewRows;
    }
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: this.activeSheet,
    );
  }
}
