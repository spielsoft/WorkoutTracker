import 'dart:io';

import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:workout_tracker/google_sheets.dart';

const _developmentSpreadsheetId =
    '1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E';

Future<void> main(List<String> arguments) async {
  final spreadsheetId = arguments.isEmpty
      ? _developmentSpreadsheetId
      : arguments.single;

  auth.AutoRefreshingAuthClient? client;
  try {
    client = await auth.clientViaApplicationDefaultCredentials(
      scopes: GoogleApisSheetsSpreadsheetClient.readOnlyScopes,
    );

    final adapter = GoogleSheetsReadAdapter(
      client: GoogleApisSheetsSpreadsheetClient(sheets.SheetsApi(client)),
    );
    final activeSheet = await adapter.readParsedActiveSheet(spreadsheetId);

    stdout.writeln('Read spreadsheet: $spreadsheetId');
    stdout.writeln('Selectable workouts: ${activeSheet.selectableWorkouts}');
    stdout.writeln(
      'History blocks: ${activeSheet.historyBlocks.map((block) => block.label).toList()}',
    );
    stdout.writeln('Schema violations: ${activeSheet.schemaViolations.length}');
    stdout.writeln(
      'Formula healing issues: ${activeSheet.formulaHealingIssues.length}',
    );

    if (activeSheet.schemaViolations.isNotEmpty) {
      stderr.writeln('Live sheet read succeeded but validation found issues.');
      exitCode = 2;
    }
  } on Object catch (error) {
    stderr.writeln('Unable to read spreadsheet $spreadsheetId.');
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    client?.close();
  }
}
