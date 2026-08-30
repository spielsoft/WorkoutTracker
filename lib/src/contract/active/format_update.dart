part of '../active.dart';

/// One placed row affected by a canonical Log Format change.
class PlacementFormatImpact {
  PlacementFormatImpact({
    required this.sheetRowNumber,
    required this.workout,
    required this.isBackup,
    required this.oldTargets,
    required Map<String, String> proposedValues,
    required this.rawHistoryCount,
  }) : proposedValues = Map<String, String>.unmodifiable(proposedValues);

  final int sheetRowNumber;
  final String workout;
  final bool isBackup;
  final String oldTargets;
  final Map<String, String> proposedValues;
  final int rawHistoryCount;
}

/// Snapshot-backed workflow for changing a format used by placed rows.
///
/// The impact is safe to show directly to a user. Calling [plan] keeps the
/// canonical and row-local changes together and carries stale expectations for
/// every cell involved in the decision.
class ExeFormatImpact {
  ExeFormatImpact._({
    required this.selected,
    required this.exercise,
    required this.fields,
    required this.placements,
    required this._sheet,
  });

  final CanonicalExercise selected;
  final ExerciseDef exercise;
  final List<String> fields;
  final List<PlacementFormatImpact> placements;
  final ParsedActiveSheet _sheet;

  int get rawHistoryCount => placements.fold(
    0,
    (count, placement) => count + placement.rawHistoryCount,
  );

  ExeUpdatePlan plan(Map<int, Map<String, String>> valuesByRow) {
    final format = parseLogFormat(exercise.resolvedLogFormat);
    if (format is! ParsedLogFormat) {
      return ExeUpdatePlan.invalid('The proposed Log Format is invalid.');
    }
    final columns = _sheet._columns!;

    final errors = <String>[];
    final updates = <CellUpdate>[];
    for (final placement in placements) {
      final values = valuesByRow[placement.sheetRowNumber];
      if (values == null) {
        errors.add('Row ${placement.sheetRowNumber} needs reviewed Targets.');
        continue;
      }
      if (!_sameFieldOrder(format.fieldLabels, values.keys)) {
        errors.add(
          'Row ${placement.sheetRowNumber} Targets must contain the proposed '
          'fields in order.',
        );
        continue;
      }
      final rendered = format.renderValues(values);
      final parsed = format.parseValues(rendered);
      if (parsed == null || !_sameFieldValues(values, parsed)) {
        errors.add(
          'Row ${placement.sheetRowNumber} has Targets that cannot be '
          'recovered under the proposed format.',
        );
        continue;
      }
      updates.add(
        CellUpdate(
          sheetRowNumber: placement.sheetRowNumber,
          sheetColumnNumber: columns.targets + 1,
          value: rendered,
        ),
      );
    }
    if (errors.isNotEmpty) {
      return ExeUpdatePlan.invalid(errors.join(' '));
    }

    final canonical = _WritePlanner(
      _sheet,
    ).planCanonicalUpdate(selectedExercise: selected, exercise: exercise);
    final active = ActiveSheetWritePlan(
      cellUpdates: updates,
      expectations: [
        for (final placement in placements) ...[
          RowValuesExpct(
            sheetRowNumber: placement.sheetRowNumber,
            expectedValues: _sheet._sheetRow(placement.sheetRowNumber),
          ),
          for (final formula in _sheet._cellFormulas)
            if (formula.sheetRowNumber == placement.sheetRowNumber &&
                (formula.sheetColumnNumber == columns.exercise + 1 ||
                    formula.sheetColumnNumber == columns.logFormat + 1))
              FormulaExpct(
                sheetRowNumber: formula.sheetRowNumber,
                sheetColumnNumber: formula.sheetColumnNumber,
                expectedFormula: formula.formula,
              ),
        ],
      ],
    );
    return ExeUpdatePlan(exercises: canonical, active: active);
  }
}

class ExeUpdatePlan {
  ExeUpdatePlan({
    required this.exercises,
    required this.active,
    Iterable<WriteRejection> validationRejections = const [],
  }) : validationRejections = List<WriteRejection>.unmodifiable(
         validationRejections,
       );

  factory ExeUpdatePlan.invalid(String message) {
    return ExeUpdatePlan(
      exercises: ExercisesWritePlan(),
      active: ActiveSheetWritePlan(),
      validationRejections: [WriteRejection(message)],
    );
  }

  final ExercisesWritePlan exercises;
  final ActiveSheetWritePlan active;
  final List<WriteRejection> validationRejections;

  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) => [
    ...validationRejections,
    ...exercises.writeRejections(sheet),
    ...active.writeRejections(sheet),
  ];
}

ExeFormatImpact? _formatImpact(
  ParsedActiveSheet sheet, {
  required CanonicalExercise selected,
  required ExerciseDef exercise,
}) {
  final oldFormat = selected.format;
  final newFormat = parseLogFormat(exercise.resolvedLogFormat);
  if (oldFormat is! ParsedLogFormat || newFormat is! ParsedLogFormat) {
    return null;
  }
  if (selected.logFormat == exercise.resolvedLogFormat) {
    return null;
  }

  final exerciseColumn = sheet._columns!.exercise + 1;
  final placedRows = <int>{
    for (final formula in sheet._cellFormulas)
      if (formula.sheetColumnNumber == exerciseColumn &&
          _exerciseRef(formula.formula)?.rowNumber == selected.sheetRowNumber)
        formula.sheetRowNumber,
  };
  final placements = <PlacementFormatImpact>[];
  for (final slot in sheet.slots) {
    if (!placedRows.contains(slot.sheetRowNumber)) continue;
    final proposed = <String, String>{
      for (final field in newFormat.fieldLabels)
        field: slot.targetValues.containsKey(field)
            ? slot.targetValues[field] ?? ''
            : exercise.defaultValues[field] ?? '',
    };
    placements.add(
      PlacementFormatImpact(
        sheetRowNumber: slot.sheetRowNumber,
        workout: slot.workout,
        isBackup: slot.isBackup,
        oldTargets: _cell(
          sheet._sheetRow(slot.sheetRowNumber),
          sheet._columns.targets,
        ),
        proposedValues: proposed,
        rawHistoryCount: _rawHistoryImpact(
          sheet,
          slot.sheetRowNumber,
          oldFormat,
          newFormat,
        ),
      ),
    );
  }
  if (placements.isEmpty) return null;
  return ExeFormatImpact._(
    selected: selected,
    exercise: exercise,
    fields: List<String>.unmodifiable(newFormat.fieldLabels),
    placements: List<PlacementFormatImpact>.unmodifiable(placements),
    sheet: sheet,
  );
}

int _rawHistoryImpact(
  ParsedActiveSheet sheet,
  int sheetRowNumber,
  ParsedLogFormat oldFormat,
  ParsedLogFormat newFormat,
) {
  final row = sheet._sheetRow(sheetRowNumber);
  var count = 0;
  for (final block in sheet.historyBlocks) {
    for (final column in block.setColumns) {
      final raw = _cell(row, column.sheetColumnNumber - 1);
      if (raw.isEmpty) continue;
      if (parseLogEntry(oldFormat, raw) is FormattedLogEntry &&
          parseLogEntry(newFormat, raw) is RawLogEntry) {
        count += 1;
      }
    }
  }
  return count;
}

bool _sameFieldOrder(Iterable<String> fields, Iterable<String> keys) {
  return _listEquals(fields.toList(), keys.toList());
}

bool _sameFieldValues(
  Map<String, String> expected,
  Map<String, String> actual,
) {
  return expected.length == actual.length &&
      expected.entries.every((entry) => actual[entry.key] == entry.value);
}
