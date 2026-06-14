import 'dart:io';

import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/set_notation.dart';
import 'package:workout_tracker/sheet_contract.dart';

const _developmentSpreadsheetId =
    '1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E';

Future<void> main(List<String> arguments) async {
  final spreadsheetId = arguments.isEmpty
      ? _developmentSpreadsheetId
      : arguments.single;

  auth.AutoRefreshingAuthClient? client;
  var createdColumnCount = 0;
  try {
    client = await auth.clientViaApplicationDefaultCredentials(
      scopes: GoogleApisSheetsWriteClient.writeScopes,
    );
    final api = sheets.SheetsApi(client);
    final readAdapter = GoogleSheetsReadAdapter(
      client: GoogleApisSheetsSpreadsheetClient(api),
    );
    final writeAdapter = GoogleSheetsWriteAdapter(
      client: GoogleApisSheetsWriteClient(api),
    );

    final initial = await readAdapter.readParsedActiveSheet(spreadsheetId);
    _failIfInvalid(initial);
    final slot = _firstPrimaryWithBackup(initial);
    if (slot == null) {
      throw StateError('Live sheet has no primary row with a backup row.');
    }

    final label = 'WT Slice13 ${DateTime.now().toUtc().toIso8601String()}';
    stdout.writeln('Creating temporary history block: $label');
    await writeAdapter.applyActiveSheetWritePlan(
      spreadsheetId: spreadsheetId,
      plan: initial.planNewHistoryBlock(label: label),
    );
    createdColumnCount = 1;

    var activeSheet = await readAdapter.readParsedActiveSheet(spreadsheetId);
    _expectSetColumns(activeSheet, label, ['S1']);
    await writeAdapter.applyActiveSheetWritePlan(
      spreadsheetId: spreadsheetId,
      plan: activeSheet.planHistoryBlockGrowth(
        label: label,
        throughSetNumber: 2,
      ),
    );
    createdColumnCount = 2;

    activeSheet = await readAdapter.readParsedActiveSheet(spreadsheetId);
    _expectSetColumns(activeSheet, label, ['S1', 'S2']);
    await writeAdapter.applyActiveSheetWritePlan(
      spreadsheetId: spreadsheetId,
      plan: activeSheet.planSetLoggingWrite(
        historyBlockLabel: label,
        sheetRowNumber: slot.sheetRowNumber,
        set: LoggedSet(
          result: WeightedReps(weight: '101', reps: '5'),
          rpe: '8',
          note: 'slice13-primary',
        ),
      ),
    );

    activeSheet = await readAdapter.readParsedActiveSheet(spreadsheetId);
    await writeAdapter.applyActiveSheetWritePlan(
      spreadsheetId: spreadsheetId,
      plan: activeSheet.planSetLoggingWrite(
        historyBlockLabel: label,
        sheetRowNumber: slot.backups.first.sheetRowNumber,
        set: LoggedSet(
          result: WeightedReps(weight: '102', reps: '8'),
          rpe: '7',
          note: 'slice13-backup',
        ),
      ),
    );

    activeSheet = await readAdapter.readParsedActiveSheet(spreadsheetId);
    await writeAdapter.applyActiveSheetWritePlan(
      spreadsheetId: spreadsheetId,
      plan: activeSheet.planSetEdit(
        historyBlockLabel: label,
        sheetRowNumber: slot.sheetRowNumber,
        setNumber: 1,
        set: LoggedSet(
          result: WeightedReps(weight: '103', reps: '5'),
          rpe: '8',
          note: 'slice13-edit',
        ),
      ),
    );

    activeSheet = await readAdapter.readParsedActiveSheet(spreadsheetId);
    await writeAdapter.applyActiveSheetWritePlan(
      spreadsheetId: spreadsheetId,
      plan: activeSheet.planSetClear(
        historyBlockLabel: label,
        sheetRowNumber: slot.sheetRowNumber,
        setNumber: 1,
      ),
    );

    await _verifyFormulaHealing(
      spreadsheetId: spreadsheetId,
      readAdapter: readAdapter,
      writeAdapter: writeAdapter,
      activeRow: slot,
    );

    stdout.writeln(
      'Verified live Slice 13 writes on spreadsheet $spreadsheetId',
    );
    stdout.writeln(
      'Touched temporary columns J:K and active row '
      '${slot.sheetRowNumber}; cleanup will remove J:K.',
    );
  } on Object catch (error) {
    stderr.writeln('Unable to verify spreadsheet writes for $spreadsheetId.');
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    if (client != null && createdColumnCount > 0) {
      try {
        await _deleteCreatedHistoryColumns(
          api: sheets.SheetsApi(client),
          spreadsheetId: spreadsheetId,
          columnCount: createdColumnCount,
        );
        stdout.writeln('Removed temporary history columns.');
      } on Object catch (cleanupError) {
        stderr.writeln('Temporary history columns were not removed.');
        stderr.writeln(cleanupError);
        exitCode = 1;
      }
    }
    client?.close();
  }
}

void _failIfInvalid(ParsedActiveSheet sheet) {
  if (sheet.schemaViolations.isNotEmpty) {
    throw StateError(
      'Live sheet has schema violations: ${sheet.schemaViolations}',
    );
  }
}

WorkoutSlot? _firstPrimaryWithBackup(ParsedActiveSheet sheet) {
  for (final slot in sheet.primarySlots) {
    if (slot.backups.isNotEmpty) {
      return slot;
    }
  }
  return null;
}

void _expectSetColumns(
  ParsedActiveSheet sheet,
  String label,
  List<String> expected,
) {
  final block = sheet.selectHistoryBlock(label);
  final labels = block?.setColumns.map((column) => column.label).toList();
  if (block == null || labels.toString() != expected.toString()) {
    throw StateError('Expected $label columns $expected, found $labels.');
  }
}

Future<void> _verifyFormulaHealing({
  required String spreadsheetId,
  required GoogleSheetsReadAdapter readAdapter,
  required GoogleSheetsWriteAdapter writeAdapter,
  required WorkoutSlot activeRow,
}) async {
  final input = await readAdapter.readActiveSheetInput(spreadsheetId);
  final exerciseFormula = input.cellFormulas.where(
    (formula) =>
        formula.sheetRowNumber == activeRow.sheetRowNumber &&
        formula.sheetColumnNumber == 1,
  );
  if (exerciseFormula.isEmpty) {
    throw StateError(
      'Active row ${activeRow.sheetRowNumber} has no Exercise formula to heal.',
    );
  }

  await writeAdapter.applyActiveSheetWritePlan(
    spreadsheetId: spreadsheetId,
    plan: ActiveSheetWritePlan(
      cellUpdates: [
        CellUpdate(
          sheetRowNumber: activeRow.sheetRowNumber,
          sheetColumnNumber: 1,
          value: activeRow.exercise,
        ),
      ],
    ),
  );

  final brokenSheet = await readAdapter.readParsedActiveSheet(spreadsheetId);
  final healPlan = brokenSheet.planFormulaHealing(
    activeSheetRowNumber: activeRow.sheetRowNumber,
  );
  if (healPlan.cellUpdates.isEmpty) {
    throw StateError('Formula healing did not produce a write plan.');
  }

  await writeAdapter.applyActiveSheetWritePlan(
    spreadsheetId: spreadsheetId,
    plan: healPlan,
  );

  final healedSheet = await readAdapter.readParsedActiveSheet(spreadsheetId);
  final stillBroken = healedSheet.formulaHealingIssues.any(
    (issue) => issue.activeSheetRowNumber == activeRow.sheetRowNumber,
  );
  if (stillBroken) {
    throw StateError('Formula healing issue remained after applying plan.');
  }
}

Future<void> _deleteCreatedHistoryColumns({
  required sheets.SheetsApi api,
  required String spreadsheetId,
  required int columnCount,
}) async {
  final spreadsheet = await api.spreadsheets.get(
    spreadsheetId,
    $fields: 'sheets(properties(sheetId,index,title,sheetType))',
  );
  final apiSheets = [...?spreadsheet.sheets]
    ..sort((left, right) {
      return (left.properties?.index ?? 0).compareTo(
        right.properties?.index ?? 0,
      );
    });
  final sheetId = apiSheets.first.properties?.sheetId;
  if (sheetId == null) {
    throw StateError('Active sheet is missing a sheet ID.');
  }

  await api.spreadsheets.batchUpdate(
    sheets.BatchUpdateSpreadsheetRequest(
      requests: [
        sheets.Request(
          deleteDimension: sheets.DeleteDimensionRequest(
            range: sheets.DimensionRange(
              sheetId: sheetId,
              dimension: 'COLUMNS',
              startIndex: activeSheetFixedColumns.length,
              endIndex: activeSheetFixedColumns.length + columnCount,
            ),
          ),
        ),
      ],
    ),
    spreadsheetId,
    $fields: 'spreadsheetId',
  );
}
