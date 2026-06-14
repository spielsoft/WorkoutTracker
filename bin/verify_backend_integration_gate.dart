import 'dart:io';

import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/set_notation.dart';
import 'package:workout_tracker/sheet_contract.dart';

Future<void> main(List<String> arguments) async {
  final spreadsheetId = arguments.isEmpty
      ? workoutTrackerDevelopmentSpreadsheetId
      : arguments.single;

  auth.AutoRefreshingAuthClient? client;
  var shouldCleanup = false;
  var cleanupVerified = false;
  try {
    client = await auth.clientViaApplicationDefaultCredentials(
      scopes: GoogleApisSheetsWriteClient.writeScopes,
    );
    final api = sheets.SheetsApi(client);
    final resetHarness = DevelopmentSheetResetHarness(
      client: GoogleApisDevelopmentSheetResetClient(api),
    );
    final readAdapter = GoogleSheetsReadAdapter(
      client: GoogleApisSheetsSpreadsheetClient(api),
    );
    final writeAdapter = GoogleSheetsWriteAdapter(
      client: GoogleApisSheetsWriteClient(api),
    );

    stdout.writeln('Resetting development spreadsheet: $spreadsheetId');
    await resetHarness.reset(spreadsheetId: spreadsheetId);
    shouldCleanup = true;
    var activeSheet = await _readKnownResetSheet(
      spreadsheetId: spreadsheetId,
      readAdapter: readAdapter,
    );
    stdout.writeln('Validated reset sheet contract.');

    final slot = _firstPrimaryWithBackup(activeSheet);
    if (slot == null) {
      throw StateError('Reset sheet has no primary row with a backup row.');
    }

    await _verifyFormulaHealing(
      spreadsheetId: spreadsheetId,
      readAdapter: readAdapter,
      writeAdapter: writeAdapter,
      slot: slot,
    );
    stdout.writeln('Planned and applied live formula healing.');

    activeSheet = await readAdapter.readParsedActiveSheet(spreadsheetId);
    await _verifyPrimarySetLifecycle(
      spreadsheetId: spreadsheetId,
      readAdapter: readAdapter,
      writeAdapter: writeAdapter,
      activeSheet: activeSheet,
      slot: slot,
      historyBlockLabel: 'Week 2',
    );
    stdout.writeln(
      'Logged, read back, edited, cleared, and reread primary set.',
    );

    activeSheet = await readAdapter.readParsedActiveSheet(spreadsheetId);
    final newHistoryLabel =
        'WT Slice15 ${DateTime.now().toUtc().toIso8601String()}';
    await _verifyNewHistoryBlockAndBackupSetCount(
      spreadsheetId: spreadsheetId,
      readAdapter: readAdapter,
      writeAdapter: writeAdapter,
      activeSheet: activeSheet,
      slot: slot,
      historyBlockLabel: newHistoryLabel,
    );
    stdout.writeln(
      'Created new history block and verified backup set count inclusion.',
    );

    stdout.writeln('Resetting development spreadsheet after validation.');
    await resetHarness.reset(spreadsheetId: spreadsheetId);
    await _readKnownResetSheet(
      spreadsheetId: spreadsheetId,
      readAdapter: readAdapter,
    );
    cleanupVerified = true;

    stdout.writeln(
      'Verified Slice 15 backend integration gate on spreadsheet $spreadsheetId',
    );
  } on Object catch (error) {
    stderr.writeln(
      'Unable to verify backend integration gate for $spreadsheetId.',
    );
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    if (client != null && shouldCleanup && !cleanupVerified) {
      try {
        final api = sheets.SheetsApi(client);
        final resetHarness = DevelopmentSheetResetHarness(
          client: GoogleApisDevelopmentSheetResetClient(api),
        );
        final readAdapter = GoogleSheetsReadAdapter(
          client: GoogleApisSheetsSpreadsheetClient(api),
        );
        await resetHarness.reset(spreadsheetId: spreadsheetId);
        await _readKnownResetSheet(
          spreadsheetId: spreadsheetId,
          readAdapter: readAdapter,
        );
        stdout.writeln('Cleanup reset completed after validation failure.');
      } on Object catch (cleanupError) {
        stderr.writeln('Cleanup reset failed after validation failure.');
        stderr.writeln(cleanupError);
        exitCode = 1;
      }
    }
    client?.close();
  }
}

Future<ParsedActiveSheet> _readKnownResetSheet({
  required String spreadsheetId,
  required GoogleSheetsReadAdapter readAdapter,
}) async {
  final input = await readAdapter.readActiveSheetInput(spreadsheetId);
  final activeSheet = parseActiveSheet(input);
  _expectKnownReset(input, activeSheet);
  return activeSheet;
}

void _expectKnownReset(ActiveSheetInput input, ParsedActiveSheet activeSheet) {
  _failIfInvalid(activeSheet);
  if (activeSheet.formulaHealingIssues.isNotEmpty) {
    throw StateError(
      'Reset sheet has formula healing issues: '
      '${activeSheet.formulaHealingIssues}',
    );
  }

  _expectContainsAll(activeSheet.selectableWorkouts, [
    'Legs',
    'Upper',
    defaultWorkoutName,
  ], 'selectable workouts');
  _expectContainsAll(
    activeSheet.historyBlocks.map((block) => block.label).toList(),
    ['Week 2', 'Week 1'],
    'history blocks',
  );

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

Future<void> _verifyFormulaHealing({
  required String spreadsheetId,
  required GoogleSheetsReadAdapter readAdapter,
  required GoogleSheetsWriteAdapter writeAdapter,
  required WorkoutSlot slot,
}) async {
  await writeAdapter.applyActiveSheetWritePlan(
    spreadsheetId: spreadsheetId,
    plan: ActiveSheetWritePlan(
      cellUpdates: [
        CellUpdate(
          sheetRowNumber: slot.sheetRowNumber,
          sheetColumnNumber: 1,
          value: slot.exercise,
        ),
      ],
    ),
  );

  final brokenSheet = await readAdapter.readParsedActiveSheet(spreadsheetId);
  _failIfInvalid(brokenSheet);
  final issue = brokenSheet.formulaHealingIssues
      .where((issue) => issue.activeSheetRowNumber == slot.sheetRowNumber)
      .firstOrNull;
  if (issue == null) {
    throw StateError('Formula healing did not detect the broken formula.');
  }
  if (issue.requiresUserSelection) {
    throw StateError('Expected exact formula healing preselection: $issue');
  }

  final healPlan = brokenSheet.planFormulaHealing(
    activeSheetRowNumber: slot.sheetRowNumber,
  );
  if (healPlan.cellUpdates.isEmpty) {
    throw StateError('Formula healing did not produce a write plan.');
  }

  await writeAdapter.applyActiveSheetWritePlan(
    spreadsheetId: spreadsheetId,
    plan: healPlan,
  );

  final healedSheet = await readAdapter.readParsedActiveSheet(spreadsheetId);
  _failIfInvalid(healedSheet);
  final stillBroken = healedSheet.formulaHealingIssues.any(
    (issue) => issue.activeSheetRowNumber == slot.sheetRowNumber,
  );
  if (stillBroken) {
    throw StateError('Formula healing issue remained after applying plan.');
  }
}

Future<void> _verifyPrimarySetLifecycle({
  required String spreadsheetId,
  required GoogleSheetsReadAdapter readAdapter,
  required GoogleSheetsWriteAdapter writeAdapter,
  required ParsedActiveSheet activeSheet,
  required WorkoutSlot slot,
  required String historyBlockLabel,
}) async {
  _expectSetColumns(activeSheet, historyBlockLabel, ['S1', 'S2']);

  final loggedSet = LoggedSet(
    result: WeightedReps(weight: '111', reps: '5'),
    rpe: '8',
    note: 'slice15-primary',
  );
  await writeAdapter.applyActiveSheetWritePlan(
    spreadsheetId: spreadsheetId,
    plan: activeSheet.planSetLoggingWrite(
      historyBlockLabel: historyBlockLabel,
      sheetRowNumber: slot.sheetRowNumber,
      set: loggedSet,
    ),
  );

  var readBack = await readAdapter.readParsedActiveSheet(spreadsheetId);
  _expectRowSetValue(
    readBack,
    primarySheetRowNumber: slot.sheetRowNumber,
    selectedSheetRowNumber: slot.sheetRowNumber,
    historyBlockLabel: historyBlockLabel,
    setNumber: 1,
    expectedValue: renderSetNotation(loggedSet),
  );

  final editedSet = LoggedSet(
    result: WeightedReps(weight: '112', reps: '5'),
    rpe: '8',
    note: 'slice15-edit',
  );
  await writeAdapter.applyActiveSheetWritePlan(
    spreadsheetId: spreadsheetId,
    plan: readBack.planSetEdit(
      historyBlockLabel: historyBlockLabel,
      sheetRowNumber: slot.sheetRowNumber,
      setNumber: 1,
      set: editedSet,
    ),
  );

  readBack = await readAdapter.readParsedActiveSheet(spreadsheetId);
  _expectRowSetValue(
    readBack,
    primarySheetRowNumber: slot.sheetRowNumber,
    selectedSheetRowNumber: slot.sheetRowNumber,
    historyBlockLabel: historyBlockLabel,
    setNumber: 1,
    expectedValue: renderSetNotation(editedSet),
  );

  await writeAdapter.applyActiveSheetWritePlan(
    spreadsheetId: spreadsheetId,
    plan: readBack.planSetClear(
      historyBlockLabel: historyBlockLabel,
      sheetRowNumber: slot.sheetRowNumber,
      setNumber: 1,
    ),
  );

  readBack = await readAdapter.readParsedActiveSheet(spreadsheetId);
  _expectRowSetValue(
    readBack,
    primarySheetRowNumber: slot.sheetRowNumber,
    selectedSheetRowNumber: slot.sheetRowNumber,
    historyBlockLabel: historyBlockLabel,
    setNumber: 1,
    expectedValue: '',
  );
}

Future<void> _verifyNewHistoryBlockAndBackupSetCount({
  required String spreadsheetId,
  required GoogleSheetsReadAdapter readAdapter,
  required GoogleSheetsWriteAdapter writeAdapter,
  required ParsedActiveSheet activeSheet,
  required WorkoutSlot slot,
  required String historyBlockLabel,
}) async {
  await writeAdapter.applyActiveSheetWritePlan(
    spreadsheetId: spreadsheetId,
    plan: activeSheet.planNewHistoryBlock(label: historyBlockLabel),
  );

  var readBack = await readAdapter.readParsedActiveSheet(spreadsheetId);
  _expectSetColumns(readBack, historyBlockLabel, ['S1']);

  final backup = slot.backups.first;
  final backupSet = LoggedSet(
    result: WeightedReps(weight: '113', reps: '8'),
    rpe: '7',
    note: 'slice15-backup',
  );
  await writeAdapter.applyActiveSheetWritePlan(
    spreadsheetId: spreadsheetId,
    plan: readBack.planSetLoggingWrite(
      historyBlockLabel: historyBlockLabel,
      sheetRowNumber: backup.sheetRowNumber,
      set: backupSet,
    ),
  );

  readBack = await readAdapter.readParsedActiveSheet(spreadsheetId);
  _expectRowSetValue(
    readBack,
    primarySheetRowNumber: slot.sheetRowNumber,
    selectedSheetRowNumber: backup.sheetRowNumber,
    historyBlockLabel: historyBlockLabel,
    setNumber: 1,
    expectedValue: renderSetNotation(backupSet),
  );

  final overview = readBack.buildWorkoutOverview(
    workout: slot.workout,
    historyBlockLabel: historyBlockLabel,
  );
  final overviewSlot = overview.slots
      .where((candidate) => candidate.sheetRowNumber == slot.sheetRowNumber)
      .firstOrNull;
  if (overviewSlot == null) {
    throw StateError('Workout overview did not include primary row $slot.');
  }
  if (overviewSlot.setCount != 1) {
    throw StateError(
      'Expected backup set to count toward slot total. '
      'Found ${overviewSlot.setCount}.',
    );
  }
}

void _expectRowSetValue(
  ParsedActiveSheet activeSheet, {
  required int primarySheetRowNumber,
  required int selectedSheetRowNumber,
  required String historyBlockLabel,
  required int setNumber,
  required String expectedValue,
}) {
  _failIfInvalid(activeSheet);
  final context = activeSheet.buildExerciseLoggingContext(
    primarySheetRowNumber: primarySheetRowNumber,
    selectedSheetRowNumber: selectedSheetRowNumber,
    historyBlockLabel: historyBlockLabel,
  );
  final entry = context.selectedHistory.entries
      .where((entry) => entry.setNumber == setNumber)
      .firstOrNull;
  if (entry == null) {
    throw StateError(
      'No S$setNumber entry found for $historyBlockLabel row '
      '$selectedSheetRowNumber.',
    );
  }
  if (entry.rawValue != expectedValue) {
    throw StateError(
      'Expected S$setNumber to be "$expectedValue", found '
      '"${entry.rawValue}".',
    );
  }
}

void _expectSetColumns(
  ParsedActiveSheet activeSheet,
  String label,
  List<String> expected,
) {
  final block = activeSheet.selectHistoryBlock(label);
  final labels = block?.setColumns.map((column) => column.label).toList();
  if (block == null || labels.toString() != expected.toString()) {
    throw StateError('Expected $label columns $expected, found $labels.');
  }
}

void _failIfInvalid(ParsedActiveSheet activeSheet) {
  if (activeSheet.schemaViolations.isNotEmpty) {
    throw StateError(
      'Live sheet has schema violations: ${activeSheet.schemaViolations}',
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

void _expectContainsAll(
  List<String> actual,
  List<String> expected,
  String label,
) {
  final missing = expected.where((value) => !actual.contains(value)).toList();
  if (missing.isNotEmpty) {
    throw StateError('Expected $label to contain $expected, found $actual.');
  }
}
