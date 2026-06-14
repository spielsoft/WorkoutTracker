import 'dart:io';

import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

Future<void> main(List<String> arguments) async {
  final spreadsheetId = arguments.isEmpty
      ? workoutTrackerDevelopmentSpreadsheetId
      : arguments.single;

  auth.AutoRefreshingAuthClient? client;
  try {
    client = await auth.clientViaApplicationDefaultCredentials(
      scopes: GoogleApisDevelopmentSheetResetClient.writeScopes,
    );
    final api = sheets.SheetsApi(client);
    final resetHarness = DevelopmentSheetResetHarness(
      client: GoogleApisDevelopmentSheetResetClient(api),
    );
    final readAdapter = GoogleSheetsReadAdapter(
      client: GoogleApisSheetsSpreadsheetClient(api),
    );

    await resetHarness.reset(spreadsheetId: spreadsheetId);
    final input = await readAdapter.readActiveSheetInput(spreadsheetId);
    final activeSheet = parseActiveSheet(input);

    _expectValidReset(input, activeSheet);

    stdout.writeln('Reset development spreadsheet: $spreadsheetId');
    stdout.writeln('Selectable workouts: ${activeSheet.selectableWorkouts}');
    stdout.writeln(
      'History blocks: ${activeSheet.historyBlocks.map((block) => block.label).toList()}',
    );
    stdout.writeln('Formula cells read back: ${input.cellFormulas.length}');
  } on Object catch (error) {
    stderr.writeln('Unable to reset development spreadsheet $spreadsheetId.');
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    client?.close();
  }
}

void _expectValidReset(ActiveSheetInput input, ParsedActiveSheet activeSheet) {
  if (activeSheet.schemaViolations.isNotEmpty) {
    throw StateError(
      'Reset sheet has schema violations: ${activeSheet.schemaViolations}\n'
      'Read-back rows: ${_previewRows(input.rows)}',
    );
  }
  if (activeSheet.formulaHealingIssues.isNotEmpty) {
    throw StateError(
      'Reset sheet has formula healing issues: '
      '${activeSheet.formulaHealingIssues}',
    );
  }
  if (!activeSheet.selectableWorkouts.contains('Legs') ||
      !activeSheet.selectableWorkouts.contains('Upper') ||
      !activeSheet.selectableWorkouts.contains(defaultWorkoutName)) {
    throw StateError(
      'Reset sheet has unexpected workouts: ${activeSheet.selectableWorkouts}',
    );
  }
  final historyLabels = activeSheet.historyBlocks
      .map((block) => block.label)
      .toList();
  if (!historyLabels.contains('Week 1') || !historyLabels.contains('Week 2')) {
    throw StateError('Reset sheet has unexpected history: $historyLabels.');
  }
  final hasPrimaryWithBackup = activeSheet.primarySlots.any(
    (slot) => slot.backups.isNotEmpty,
  );
  if (!hasPrimaryWithBackup) {
    throw StateError('Reset sheet has no primary row with a backup.');
  }
  final formulaCells = input.cellFormulas.where(
    (formula) =>
        formula.sheetRowNumber >= 3 &&
        formula.sheetColumnNumber >= 1 &&
        formula.sheetColumnNumber <= 7,
  );
  if (formulaCells.length < 35) {
    throw StateError(
      'Reset sheet did not read back all active display formulas.',
    );
  }
}

String _previewRows(List<List<String>> rows) {
  return rows
      .take(8)
      .map((row) => row.map((cell) => cell.isEmpty ? '<blank>' : cell).toList())
      .toList()
      .toString();
}
