part of '../active.dart';

class _ExerciseWritePlanner {
  _ExerciseWritePlanner(this.context);

  final _WritePlanningContext context;

  ExercisesWritePlan planCanonicalAppend(ExerciseDef exercise) {
    if (!_hasValidFormat(exercise)) {
      return ExercisesWritePlan();
    }
    final append = ExercisesRowAppend(
      sheetRowNumber: 2,
      values: _exerciseValues(exercise),
    );
    return ExercisesWritePlan(rowAppends: [append]);
  }

  ExercisesWritePlan planCanonicalUpdate({
    required CanonicalExercise selectedExercise,
    required ExerciseDef exercise,
  }) {
    if (!_hasValidFormat(exercise)) {
      return ExercisesWritePlan();
    }
    final sheetRowNumber = selectedExercise.sheetRowNumber;
    if (sheetRowNumber < 2 ||
        sheetRowNumber > context.sheet._exercisesRows.length) {
      return ExercisesWritePlan();
    }
    return ExercisesWritePlan(
      rowUpdates: [
        ExercisesRowUpdate(
          sheetRowNumber: sheetRowNumber,
          values: _exerciseValues(exercise),
        ),
      ],
      expectations: [
        ExercisesRowExpct(
          sheetRowNumber: sheetRowNumber,
          expectedValues: context.sheet._exercisesRows[sheetRowNumber - 1],
        ),
      ],
    );
  }

  bool _hasValidFormat(ExerciseDef exercise) {
    return context.sheet._parseFormat(exercise.resolvedLogFormat)
        is ParsedLogFormat;
  }

  ExercisesWritePlan planCanonicalReorder(ReorderIntent intent) {
    if (context.sheet._exercisesRows.length < 3) {
      return ExercisesWritePlan();
    }
    final header = context.sheet._exercisesRows.first;
    final exerciseRows = context.sheet._exercisesRows.skip(1).toList();
    final reorderedRows = _reordered(exerciseRows, intent);
    if (_nestedListEquals(exerciseRows, reorderedRows)) {
      return ExercisesWritePlan();
    }

    final oldToNewRows = <int, int>{};
    for (var oldIndex = 0; oldIndex < exerciseRows.length; oldIndex += 1) {
      final row = exerciseRows[oldIndex];
      final newIndex = reorderedRows.indexWhere(
        (candidate) => identical(candidate, row),
      );
      if (newIndex >= 0) {
        oldToNewRows[oldIndex + 2] = newIndex + 2;
      }
    }

    return ExercisesWritePlan(
      rowUpdates: [
        for (var index = 0; index < reorderedRows.length; index += 1)
          ExercisesRowUpdate(
            sheetRowNumber: index + 2,
            values: _normalizedExerciseRow(header, reorderedRows[index]),
          ),
      ],
      formulaUpdates: context.reorderFormulaUpdates(oldToNewRows),
      expectations: [
        for (var index = 0; index < exerciseRows.length; index += 1)
          ExercisesRowExpct(
            sheetRowNumber: index + 2,
            expectedValues: exerciseRows[index],
          ),
        ...context.reorderFormulaExpcts(oldToNewRows),
      ],
    );
  }

  List<String> _exerciseValues(ExerciseDef exercise) {
    final header = context.sheet._exercisesRows.first;
    final columns = context.sheet._exerciseColumns!;
    final logFormatColumn = columns.logFormat;
    final row = List.filled(_exerciseRowWidth(header, logFormatColumn), '');
    _setRowValue(row, columns.exercise, exercise.exercise);
    _setRowValue(row, columns.description, exercise.description);
    _setRowValue(row, columns.defaultSets, exercise.defaultSets);
    _setRowValue(row, columns.defaultRest, exercise.defaultRest);
    _setRowValue(row, columns.defaultTempo, exercise.defaultTempo);
    _setRowValue(row, columns.notes, exercise.notes);
    _setRowValue(row, logFormatColumn, exercise.resolvedLogFormat);
    final format = context.sheet._parseFormat(exercise.resolvedLogFormat);
    _setRowValue(
      row,
      columns.defaultValues,
      format is ParsedLogFormat
          ? format.renderValues(exercise.defaultValues)
          : '',
    );
    return row;
  }

  List<String> _normalizedExerciseRow(List<String> header, List<String> row) {
    final width = header.length < exercisesSheetColumns.length
        ? exercisesSheetColumns.length
        : header.length;
    return [for (var index = 0; index < width; index += 1) _cell(row, index)];
  }

  int _exerciseRowWidth(List<String> header, int logFormatColumn) {
    var width = header.length;
    if (width < exercisesSheetColumns.length) {
      width = exercisesSheetColumns.length;
    }
    if (width <= logFormatColumn) {
      width = logFormatColumn + 1;
    }
    return width;
  }

  void _setRowValue(List<String> row, int index, String value) {
    while (row.length <= index) {
      row.add('');
    }
    row[index] = value;
  }
}

bool _nestedListEquals<T>(List<List<T>> a, List<List<T>> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i += 1) {
    if (!_listEquals(a[i], b[i])) {
      return false;
    }
  }
  return true;
}
