import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/sheets.dart';

import '../defaults.dart';
import '../log_format/legacy.dart';
import 'model.dart';

class VersionFormatMigrator implements FieldMigrator {
  VersionFormatMigrator({
    required this.client,
    required Iterable<String> allowedSpreadsheetIds,
  }) : _allowedIds = Set<String>.unmodifiable(allowedSpreadsheetIds);

  final SheetsWorkbookClient client;
  final Set<String> _allowedIds;

  @override
  Future<FormatMigrationReport> dryRun(String spreadsheetId) async {
    _requireAllowed(spreadsheetId);
    return _plan(spreadsheetId, await _read(spreadsheetId)).report;
  }

  @override
  Future<FormatMigrationReport> migrate(
    String spreadsheetId, {
    required bool confirmed,
    WbkMigrationReport? expected,
  }) async {
    _requireAllowed(spreadsheetId);
    if (!confirmed) {
      throw StateError('Format conversion requires explicit confirmation.');
    }
    if (expected != null &&
        (expected.kind != WbkMigrationKind.format09 ||
            expected.spreadsheetId != spreadsheetId)) {
      throw StateError('Workbook conversion route changed after preview.');
    }

    final baseline = await _read(spreadsheetId);
    if (expected?.staleExpectation case final _FormatWbk preview) {
      if (!_sameWbk(preview, baseline)) {
        throw StateError(
          'Workbook changed after the format conversion preview.',
        );
      }
    }
    final plan = _plan(spreadsheetId, baseline);
    if (plan.report.alreadyCurrent) return plan.report;
    if (!plan.report.canApply) {
      throw StateError(plan.report.blockers.join(' '));
    }
    final current = await _read(spreadsheetId);
    if (!_sameWbk(baseline, current)) {
      throw StateError('Workbook changed after the format conversion preview.');
    }
    await client.applyOperations(
      spreadsheetId: spreadsheetId,
      operations: plan.operations,
    );
    final input = await SheetsReadAdapter(
      client: client,
    ).readActiveSheetInput(spreadsheetId);
    if (input.schemaVersion != currentWbkVersion) {
      throw StateError(
        'Converted workbook did not receive schema version '
        '$currentWbkVersion.',
      );
    }
    final parsed = parseActiveSheet(input);
    if (parsed.schemaViolations.isNotEmpty) {
      throw StateError(
        'Converted workbook failed validation: '
        '${parsed.schemaViolations.map((item) => item.message).join(' ')}',
      );
    }
    return plan.report.applied(parsed);
  }

  void _requireAllowed(String spreadsheetId) {
    if (!_allowedIds.contains(spreadsheetId)) {
      throw StateError('Spreadsheet is not allowlisted for format conversion.');
    }
  }

  Future<_FormatWbk> _read(String spreadsheetId) async {
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
    return _FormatWbk(
      active: snapshot.sheets.first,
      exercises: snapshot.sheets.firstWhere(
        (sheet) => sheet.sheet.title == 'Exercises',
      ),
      schemaMetadata: metadata.metadataByKey(workbookSchemaKey),
    );
  }
}

class FormatMigrationReport implements WbkMigrationReport {
  FormatMigrationReport({
    required this.spreadsheetId,
    required Iterable<String> changes,
    required Iterable<String> blockers,
    required this.recognized,
    required this.sourceVersion,
    required this.historyCellCount,
    this.wasApplied = false,
    this.alreadyCurrent = false,
    this.refreshedSheet,
    this.staleExpectation,
  }) : changes = List<String>.unmodifiable(changes),
       blockers = List<String>.unmodifiable(blockers);

  @override
  final String spreadsheetId;
  @override
  final List<String> changes;
  @override
  final List<String> blockers;
  @override
  final bool recognized;
  final String? sourceVersion;
  final int historyCellCount;
  @override
  final bool wasApplied;
  @override
  final bool alreadyCurrent;
  @override
  final ParsedActiveSheet? refreshedSheet;
  @override
  final WbkStaleExpectation? staleExpectation;

  @override
  WbkMigrationKind get kind => WbkMigrationKind.format09;

  @override
  bool get canApply => recognized && !alreadyCurrent && blockers.isEmpty;

  FormatMigrationReport applied(ParsedActiveSheet sheet) =>
      FormatMigrationReport(
        spreadsheetId: spreadsheetId,
        changes: changes,
        blockers: blockers,
        recognized: recognized,
        sourceVersion: sourceVersion,
        historyCellCount: historyCellCount,
        wasApplied: true,
        refreshedSheet: sheet,
      );
}

class _FormatPlan {
  const _FormatPlan({required this.report, required this.operations});

  final FormatMigrationReport report;
  final List<SheetsWorkbookOperation> operations;
}

class _FormatWbk implements WbkStaleExpectation {
  const _FormatWbk({
    required this.active,
    required this.exercises,
    required this.schemaMetadata,
  });

  final SheetsGridSnapshot active;
  final SheetsGridSnapshot exercises;
  final SheetsDeveloperMetadata? schemaMetadata;
}

_FormatPlan _plan(String spreadsheetId, _FormatWbk wb) {
  final version = wb.schemaMetadata?.value;
  if (version == currentWbkVersion) {
    return _FormatPlan(
      report: FormatMigrationReport(
        spreadsheetId: spreadsheetId,
        changes: const [],
        blockers: const [],
        recognized: false,
        sourceVersion: version,
        historyCellCount: 0,
        alreadyCurrent: true,
      ),
      operations: const [],
    );
  }
  if (version != priorWbkVersion) {
    return _FormatPlan(
      report: FormatMigrationReport(
        spreadsheetId: spreadsheetId,
        changes: const [],
        blockers: [
          if (version != null)
            'Workbook declares unsupported schema version "$version".',
        ],
        recognized: false,
        sourceVersion: version,
        historyCellCount: 0,
      ),
      operations: const [],
    );
  }

  final parsed = _parse(wb, priorWbkVersion);
  final blockers = [
    for (final item in parsed.schemaViolations) item.message,
    for (final issue in parsed.healingIssues)
      'Active row ${issue.activeSheetRowNumber} must reconnect '
          '${issue.exerciseName} before format conversion.',
  ];
  final changes = <String>[];
  final operations = <SheetsWorkbookOperation>[];
  var historyCellCount = 0;

  if (blockers.isEmpty) {
    for (var i = 1; i < wb.exercises.rows.length; i += 1) {
      final row = wb.exercises.rows[i];
      if (_cell(row, 0).trim().isEmpty) continue;
      final location = 'Exercises row ${i + 1}';
      final conversion = _convert(_cell(row, 6), location, blockers);
      if (conversion == null) continue;
      _proveValue(
        conversion,
        _cell(row, 7),
        '$location Default Values',
        blockers,
      );
      if (conversion.before != conversion.after) {
        changes.add(_change(location, conversion));
        operations.add(
          SheetsCellWrite(
            sheet: wb.exercises.sheet,
            sheetRowNumber: i + 1,
            sheetColumnNumber: 7,
            value: conversion.after,
          ),
        );
      }
    }

    for (var i = 1; i < wb.active.rows.length; i += 1) {
      final row = wb.active.rows[i];
      if (wb.active.mergedFirstColumnRows.contains(i + 1)) continue;
      if (_cell(row, 0).trim().isEmpty) continue;
      final location = 'Active row ${i + 1}';
      final conversion = _convert(_cell(row, 6), location, blockers);
      if (conversion == null) continue;
      _proveValue(conversion, _cell(row, 4), '$location Targets', blockers);
      if (conversion.before != conversion.after) {
        changes.add(_change(location, conversion));
      }
      for (
        var column = activeSheetFixedColumns.length;
        column < row.length;
        column += 1
      ) {
        final value = row[column];
        if (value.isEmpty) continue;
        historyCellCount += 1;
        _proveHistory(conversion, value, location, column + 1, blockers);
      }
    }
  }

  changes.add('Set workbook schema version to $currentWbkVersion.');
  operations.add(
    SheetsMetadataWrite(
      sheet: wb.active.sheet,
      key: workbookSchemaKey,
      value: currentWbkVersion,
      metadataId: wb.schemaMetadata?.id,
    ),
  );

  return _FormatPlan(
    report: FormatMigrationReport(
      spreadsheetId: spreadsheetId,
      changes: changes,
      blockers: blockers,
      recognized: true,
      sourceVersion: version,
      historyCellCount: historyCellCount,
      staleExpectation: wb,
    ),
    operations: blockers.isEmpty ? operations : const [],
  );
}

ParsedActiveSheet _parse(_FormatWbk wb, String version) {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: wb.active.rows,
      exercisesRows: wb.exercises.rows,
      cellFormulas: [
        for (final formula in wb.active.cellFormulas)
          CellFormula(
            sheetRowNumber: formula.sheetRowNumber,
            sheetColumnNumber: formula.sheetColumnNumber,
            formula: formula.formula,
          ),
      ],
      validateWorkbook: true,
      schemaVersion: version,
      mergedFirstColumnRows: wb.active.mergedFirstColumnRows,
    ),
  );
}

_Conversion? _convert(String text, String location, List<String> blockers) {
  final oldFormat = parseLegacyLogFormat(text);
  if (oldFormat is! ParsedLogFormat) {
    blockers.add('$location has an invalid 0.9 Log Format.');
    return null;
  }
  final after = text.trim().isEmpty
      ? ''
      : oldFormat.segments.map((segment) {
          return switch (segment) {
            LogField(:final label) => '{$label}',
            LogLiteral(:final text) => text,
          };
        }).join();
  final newFormat = parseLogFormat(after);
  if (newFormat is! ParsedLogFormat ||
      !_sameList(oldFormat.fieldLabels, newFormat.fieldLabels)) {
    blockers.add('$location cannot be converted to a valid 1.0 Log Format.');
    return null;
  }
  return _Conversion(
    before: text,
    after: after,
    oldFormat: oldFormat,
    newFormat: newFormat,
  );
}

void _proveValue(
  _Conversion conversion,
  String value,
  String location,
  List<String> blockers,
) {
  final before = conversion.oldFormat.parseValues(value);
  final after = conversion.newFormat.parseValues(value);
  if (before == null || after == null || !_sameMap(before, after)) {
    blockers.add('$location is not equivalent under the 1.0 format.');
  }
}

void _proveHistory(
  _Conversion conversion,
  String value,
  String row,
  int column,
  List<String> blockers,
) {
  final before = conversion.oldFormat.parseValues(value);
  final after = conversion.newFormat.parseValues(value);
  if ((before == null) != (after == null) ||
      (before != null && after != null && !_sameMap(before, after))) {
    blockers.add('$row history column $column is not format-equivalent.');
  }
}

String _change(String location, _Conversion conversion) {
  return '$location Log Format: '
      '"${conversion.before}" → "${conversion.after}".';
}

class _Conversion {
  const _Conversion({
    required this.before,
    required this.after,
    required this.oldFormat,
    required this.newFormat,
  });

  final String before;
  final String after;
  final ParsedLogFormat oldFormat;
  final ParsedLogFormat newFormat;
}

String _cell(List<String> row, int index) =>
    index < row.length ? row[index] : '';

bool _sameWbk(_FormatWbk a, _FormatWbk b) {
  return _sameGrid(a.active, b.active) &&
      _sameGrid(a.exercises, b.exercises) &&
      a.schemaMetadata?.id == b.schemaMetadata?.id &&
      a.schemaMetadata?.value == b.schemaMetadata?.value;
}

bool _sameGrid(SheetsGridSnapshot a, SheetsGridSnapshot b) {
  return a.sheet.sheetId == b.sheet.sheetId &&
      a.sheet.title == b.sheet.title &&
      _sameRows(a.rows, b.rows) &&
      _sameFormulas(a.cellFormulas, b.cellFormulas) &&
      _sameSet(a.mergedFirstColumnRows, b.mergedFirstColumnRows);
}

bool _sameFormulas(List<SheetsCellFormula> a, List<SheetsCellFormula> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i].sheetRowNumber != b[i].sheetRowNumber ||
        a[i].sheetColumnNumber != b[i].sheetColumnNumber ||
        a[i].formula != b[i].formula) {
      return false;
    }
  }
  return true;
}

bool _sameRows(List<List<String>> a, List<List<String>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (!_sameList(a[i], b[i])) return false;
  }
  return true;
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _sameMap(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

bool _sameSet(Set<int> a, Set<int> b) {
  return a.length == b.length && a.containsAll(b);
}
