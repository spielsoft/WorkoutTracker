import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/sheets.dart';

/// Temporary owner-only migration for pre-MVP Reps/RPE workbook columns.
///
/// Keep all legacy recognition in this file and delete it, with its tests,
/// before the MVP release.
class LegacyFieldMigrator {
  LegacyFieldMigrator({
    required this.client,
    required Iterable<String> allowedSpreadsheetIds,
  }) : _allowedIds = Set<String>.unmodifiable(allowedSpreadsheetIds);

  final SheetsWorkbookClient client;
  final Set<String> _allowedIds;

  Future<LegacyFieldMigrationReport> dryRun(String spreadsheetId) async {
    _requireAllowed(spreadsheetId);
    final workbook = await _read(spreadsheetId);
    return _plan(spreadsheetId, workbook).report;
  }

  Future<LegacyFieldMigrationReport> migrate(
    String spreadsheetId, {
    required bool confirmed,
  }) async {
    _requireAllowed(spreadsheetId);
    if (!confirmed) {
      throw StateError('Legacy migration requires explicit confirmation.');
    }
    final baseline = await _read(spreadsheetId);
    final plan = _plan(spreadsheetId, baseline);
    if (plan.report.blockers.isNotEmpty) {
      throw StateError(plan.report.blockers.join(' '));
    }
    final current = await _read(spreadsheetId);
    if (!_sameWorkbook(baseline, current)) {
      throw StateError('Workbook changed after the migration dry run.');
    }
    await client.applyOperations(
      spreadsheetId: spreadsheetId,
      operations: plan.operations,
    );
    final parsed = await SheetsReadAdapter(
      client: client,
    ).readParsedActiveSheet(spreadsheetId);
    if (parsed.schemaViolations.isNotEmpty) {
      throw StateError(
        'Migrated workbook failed validation: '
        '${parsed.schemaViolations.map((item) => item.message).join(' ')}',
      );
    }
    return plan.report.applied();
  }

  void _requireAllowed(String spreadsheetId) {
    if (!_allowedIds.contains(spreadsheetId)) {
      throw StateError('Spreadsheet is not allowlisted for legacy migration.');
    }
  }

  Future<_LegacyWorkbook> _read(String spreadsheetId) async {
    final metadata = await client.fetchMetadata(spreadsheetId);
    if (metadata.sheets.isEmpty) {
      throw StateError('Spreadsheet has no sheets.');
    }
    final exercises = metadata.sheetByTitle('Exercises');
    if (exercises == null) {
      throw StateError('Spreadsheet has no Exercises tab.');
    }
    final active = metadata.sheets.first;
    final snapshot = await client.readGrids(
      spreadsheetId: spreadsheetId,
      reads: [
        SheetsGridRead(sheet: active),
        SheetsGridRead(sheet: exercises),
      ],
    );
    return _LegacyWorkbook(
      active: snapshot.sheets.first,
      exercises: snapshot.sheets.firstWhere(
        (sheet) => sheet.sheet.title == 'Exercises',
      ),
    );
  }
}

class LegacyFieldMigrationReport {
  LegacyFieldMigrationReport({
    required this.spreadsheetId,
    required this.exerciseCount,
    required this.activeRowCount,
    required Iterable<String> blockers,
    this.wasApplied = false,
  }) : blockers = List<String>.unmodifiable(blockers);

  final String spreadsheetId;
  final int exerciseCount;
  final int activeRowCount;
  final List<String> blockers;
  final bool wasApplied;

  bool get canApply => blockers.isEmpty;

  LegacyFieldMigrationReport applied() => LegacyFieldMigrationReport(
    spreadsheetId: spreadsheetId,
    exerciseCount: exerciseCount,
    activeRowCount: activeRowCount,
    blockers: blockers,
    wasApplied: true,
  );
}

class _LegacyPlan {
  _LegacyPlan({required this.report, required this.operations});

  final LegacyFieldMigrationReport report;
  final List<SheetsWorkbookOperation> operations;
}

class _LegacyWorkbook {
  const _LegacyWorkbook({required this.active, required this.exercises});

  final SheetsGridSnapshot active;
  final SheetsGridSnapshot exercises;
}

_LegacyPlan _plan(String spreadsheetId, _LegacyWorkbook workbook) {
  final activeRows = workbook.active.rows;
  final exerciseRows = workbook.exercises.rows;
  final blockers = <String>[];
  if (activeRows.isEmpty || !_samePrefix(activeRows.first, _legacyActive)) {
    blockers.add('Active tab does not have the legacy field header.');
  }
  if (exerciseRows.isEmpty ||
      !_samePrefix(exerciseRows.first, _legacyExercises)) {
    blockers.add('Exercises tab does not have the legacy field header.');
  }
  if (blockers.isNotEmpty) {
    return _LegacyPlan(
      report: LegacyFieldMigrationReport(
        spreadsheetId: spreadsheetId,
        exerciseCount: 0,
        activeRowCount: 0,
        blockers: blockers,
      ),
      operations: const [],
    );
  }

  final operations = <SheetsWorkbookOperation>[];
  _writeRow(operations, workbook.active.sheet, 1, activeSheetFixedColumns);
  var activeCount = 0;
  for (var index = 1; index < activeRows.length; index += 1) {
    final row = _padded(activeRows[index], 10);
    final formatText = row[7].trim().isEmpty
        ? defaultExerciseLogFormat
        : row[7];
    final targets = _legacyValues(
      formatText,
      reps: row[2],
      rpe: row[3],
      location: 'active row ${index + 1}',
      blockers: blockers,
    );
    if (row[0].trim().isNotEmpty) {
      activeCount += 1;
    }
    final rowNumber = index + 1;
    final exerciseFormula = _formulaAt(workbook.active, rowNumber, 1);
    final formatFormula = _formulaAt(workbook.active, rowNumber, 8);
    _writeRow(
      operations,
      workbook.active.sheet,
      rowNumber,
      [
        row[0],
        row[1],
        row[4],
        row[5],
        targets,
        row[6],
        row[7],
        row[8],
        row[9],
        row[0].trim().isEmpty ? '' : 'x',
      ],
      formulas: {
        1: ?exerciseFormula,
        7: ?formatFormula?.replaceFirst('!I', '!G'),
      },
    );
  }

  _writeRow(operations, workbook.exercises.sheet, 1, exercisesSheetColumns);
  var exerciseCount = 0;
  for (var index = 1; index < exerciseRows.length; index += 1) {
    final row = _padded(exerciseRows[index], 9);
    final formatText = row[8].trim().isEmpty
        ? defaultExerciseLogFormat
        : row[8];
    final defaults = _legacyValues(
      formatText,
      reps: row[3],
      rpe: row[4],
      location: 'Exercises row ${index + 1}',
      blockers: blockers,
    );
    if (row[0].trim().isNotEmpty) {
      exerciseCount += 1;
    }
    _writeRow(operations, workbook.exercises.sheet, index + 1, [
      row[0],
      row[1],
      row[2],
      row[5],
      row[6],
      row[7],
      row[8],
      defaults,
    ]);
  }
  operations.add(
    SheetsColumnDeletion(
      sheet: workbook.exercises.sheet,
      sheetColumnNumber: 9,
      columnCount: 1,
    ),
  );

  return _LegacyPlan(
    report: LegacyFieldMigrationReport(
      spreadsheetId: spreadsheetId,
      exerciseCount: exerciseCount,
      activeRowCount: activeCount,
      blockers: blockers,
    ),
    operations: operations,
  );
}

String _legacyValues(
  String formatText, {
  required String reps,
  required String rpe,
  required String location,
  required List<String> blockers,
}) {
  final parsed = parseLogFormat(formatText);
  if (parsed is! ParsedLogFormat) {
    blockers.add('$location has an invalid Log Format.');
    return '';
  }
  if (reps.trim().isNotEmpty && !parsed.fieldLabels.contains('Reps')) {
    blockers.add('$location has Reps that cannot map to its Log Format.');
  }
  if (rpe.trim().isNotEmpty && !parsed.fieldLabels.contains('RPE')) {
    blockers.add('$location has RPE that cannot map to its Log Format.');
  }
  return parsed.renderValues({
    for (final label in parsed.fieldLabels)
      label: switch (label) {
        'Reps' => reps,
        'RPE' => rpe,
        _ => '',
      },
  });
}

void _writeRow(
  List<SheetsWorkbookOperation> operations,
  SheetsSheetIdentity sheet,
  int rowNumber,
  List<String> values, {
  Map<int, String> formulas = const {},
}) {
  for (var index = 0; index < values.length; index += 1) {
    operations.add(
      SheetsCellWrite(
        sheet: sheet,
        sheetRowNumber: rowNumber,
        sheetColumnNumber: index + 1,
        value: formulas[index + 1] ?? values[index],
        mode: formulas.containsKey(index + 1)
            ? SheetsValueInputMode.userEntered
            : SheetsValueInputMode.literalText,
      ),
    );
  }
}

String? _formulaAt(SheetsGridSnapshot sheet, int rowNumber, int columnNumber) {
  for (final formula in sheet.cellFormulas) {
    if (formula.sheetRowNumber == rowNumber &&
        formula.sheetColumnNumber == columnNumber) {
      return formula.formula;
    }
  }
  return null;
}

List<String> _padded(List<String> row, int width) => [
  ...row,
  ...List.filled(row.length < width ? width - row.length : 0, ''),
];

bool _samePrefix(List<String> row, List<String> header) {
  if (row.length < header.length) {
    return false;
  }
  for (var index = 0; index < header.length; index += 1) {
    if (row[index] != header[index]) {
      return false;
    }
  }
  return true;
}

bool _sameWorkbook(_LegacyWorkbook left, _LegacyWorkbook right) {
  return _sameRows(left.active.rows, right.active.rows) &&
      _sameRows(left.exercises.rows, right.exercises.rows) &&
      _sameFormulas(left.active.cellFormulas, right.active.cellFormulas) &&
      _sameFormulas(left.exercises.cellFormulas, right.exercises.cellFormulas);
}

bool _sameRows(List<List<String>> left, List<List<String>> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var row = 0; row < left.length; row += 1) {
    if (left[row].length != right[row].length) {
      return false;
    }
    for (var column = 0; column < left[row].length; column += 1) {
      if (left[row][column] != right[row][column]) {
        return false;
      }
    }
  }
  return true;
}

bool _sameFormulas(
  List<SheetsCellFormula> left,
  List<SheetsCellFormula> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    final a = left[index];
    final b = right[index];
    if (a.sheetRowNumber != b.sheetRowNumber ||
        a.sheetColumnNumber != b.sheetColumnNumber ||
        a.formula != b.formula) {
      return false;
    }
  }
  return true;
}

const _legacyActive = [
  'Exercise',
  'Sets',
  'Reps',
  'RPE',
  'Rest',
  'Tempo',
  'Notes',
  'Log Format',
  'Workout',
  'is_backup',
];

const _legacyExercises = [
  'Exercise',
  'Description',
  'Default Sets',
  'Default Reps',
  'Default RPE',
  'Default Rest',
  'Default Tempo',
  'Notes',
  'Log Format',
];
