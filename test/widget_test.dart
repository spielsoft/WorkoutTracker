import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/main.dart';
import 'package:workout_tracker/sheet_contract.dart';

void main() {
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

  final ParsedActiveSheet activeSheet;
  final spreadsheetIds = <String>[];

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
}
