part of '../active_sheet.dart';

enum FormulaHealingIssueReason { missingFormula, brokenFormula }

class FormulaHealingIssue {
  FormulaHealingIssue({
    required this.activeSheetRowNumber,
    required this.displayedExerciseName,
    required this.requiresUserSelection,
    required Iterable<int> candidateExerciseSheetRowNumbers,
    this.preselectedExerciseSheetRowNumber,
    Iterable<FormulaHealingCellIssue> cells = const [],
  }) : candidateExerciseSheetRowNumbers = List<int>.unmodifiable(
         candidateExerciseSheetRowNumbers,
       ),
       cells = List<FormulaHealingCellIssue>.unmodifiable(cells);

  final int activeSheetRowNumber;
  final String displayedExerciseName;
  final int? preselectedExerciseSheetRowNumber;
  final bool requiresUserSelection;
  final List<int> candidateExerciseSheetRowNumbers;
  final List<FormulaHealingCellIssue> cells;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FormulaHealingIssue &&
            activeSheetRowNumber == other.activeSheetRowNumber &&
            displayedExerciseName == other.displayedExerciseName &&
            preselectedExerciseSheetRowNumber ==
                other.preselectedExerciseSheetRowNumber &&
            requiresUserSelection == other.requiresUserSelection &&
            _listEquals(
              candidateExerciseSheetRowNumbers,
              other.candidateExerciseSheetRowNumbers,
            ) &&
            _listEquals(cells, other.cells);
  }

  @override
  int get hashCode => Object.hash(
    activeSheetRowNumber,
    displayedExerciseName,
    preselectedExerciseSheetRowNumber,
    requiresUserSelection,
    Object.hashAll(candidateExerciseSheetRowNumbers),
    Object.hashAll(cells),
  );

  @override
  String toString() {
    return 'FormulaHealingIssue('
        'activeSheetRowNumber: $activeSheetRowNumber, '
        'displayedExerciseName: $displayedExerciseName, '
        'preselectedExerciseSheetRowNumber: $preselectedExerciseSheetRowNumber, '
        'requiresUserSelection: $requiresUserSelection, '
        'candidateExerciseSheetRowNumbers: $candidateExerciseSheetRowNumbers, '
        'cells: $cells'
        ')';
  }
}

class FormulaHealingCellIssue {
  const FormulaHealingCellIssue({
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
    required this.columnName,
    required this.reason,
    required this.currentFormula,
  });

  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String columnName;
  final FormulaHealingIssueReason reason;
  final String currentFormula;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FormulaHealingCellIssue &&
            sheetRowNumber == other.sheetRowNumber &&
            sheetColumnNumber == other.sheetColumnNumber &&
            columnName == other.columnName &&
            reason == other.reason &&
            currentFormula == other.currentFormula;
  }

  @override
  int get hashCode => Object.hash(
    sheetRowNumber,
    sheetColumnNumber,
    columnName,
    reason,
    currentFormula,
  );

  @override
  String toString() {
    return 'FormulaHealingCellIssue('
        'sheetRowNumber: $sheetRowNumber, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'columnName: $columnName, '
        'reason: $reason, '
        'currentFormula: $currentFormula'
        ')';
  }
}

class _FormulaHealingPlanner {
  _FormulaHealingPlanner(this.sheet);

  final ParsedActiveSheet sheet;

  ActiveSheetWritePlan planFormulaHealing({
    required int activeSheetRowNumber,
    int? selectedExerciseSheetRowNumber,
  }) {
    FormulaHealingIssue? issue;
    for (final candidate in sheet.formulaHealingIssues) {
      if (candidate.activeSheetRowNumber == activeSheetRowNumber) {
        issue = candidate;
        break;
      }
    }
    if (issue == null) {
      return ActiveSheetWritePlan();
    }

    final exerciseSheetRowNumber =
        selectedExerciseSheetRowNumber ??
        issue.preselectedExerciseSheetRowNumber;
    if (exerciseSheetRowNumber == null) {
      return ActiveSheetWritePlan();
    }

    return ActiveSheetWritePlan(
      cellUpdates: [
        for (final cell in issue.cells)
          CellUpdate(
            sheetRowNumber: cell.sheetRowNumber,
            sheetColumnNumber: cell.sheetColumnNumber,
            value: _directExercisesFormula(
              exercisesSheetColumnNumber:
                  sheet._formulaExerciseColumnNumbers[cell.columnName] ??
                  _defaultExerciseColumnNumber(cell.columnName),
              exercisesSheetRowNumber: exerciseSheetRowNumber,
            ),
          ),
      ],
    );
  }
}

List<FormulaHealingIssue> _formulaHealingIssues(
  ActiveSheetInput sheet,
  _FixedColumnIndexes columns,
) {
  if (sheet.exercisesRows.isEmpty) {
    return const [];
  }

  final exerciseColumns = _ExercisesColumnIndexes.fromHeader(
    sheet.exercisesRows.first,
  );
  final formulas = {
    for (final cellFormula in sheet.cellFormulas)
      _CellAddress(cellFormula.sheetRowNumber, cellFormula.sheetColumnNumber):
          cellFormula.formula,
  };
  final issues = <FormulaHealingIssue>[];

  for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex += 1) {
    final sheetRowNumber = rowIndex + 1;
    if (sheet.mergedFirstColumnRows.contains(sheetRowNumber)) {
      continue;
    }

    final row = sheet.rows[rowIndex];
    final displayedExerciseName = _cell(row, columns.exercise).trim();
    if (displayedExerciseName.isEmpty) {
      continue;
    }

    final candidates = _matchingExerciseRows(
      sheet.exercisesRows,
      exerciseColumns.exercise,
      displayedExerciseName,
    );
    final cells = <FormulaHealingCellIssue>[];
    for (final formulaColumn in _formulaDrivenColumns(
      columns,
      exerciseColumns,
    )) {
      final sheetColumnNumber = formulaColumn.activeSheetColumnIndex + 1;
      final currentFormula =
          formulas[_CellAddress(sheetRowNumber, sheetColumnNumber)] ?? '';
      if (currentFormula.trim().isEmpty) {
        cells.add(
          FormulaHealingCellIssue(
            sheetRowNumber: sheetRowNumber,
            sheetColumnNumber: sheetColumnNumber,
            columnName: formulaColumn.activeColumnName,
            reason: FormulaHealingIssueReason.missingFormula,
            currentFormula: '',
          ),
        );
      } else if (candidates.length == 1 &&
          !_formulaMatchesDirectReference(
            currentFormula,
            exercisesSheetColumnNumber:
                formulaColumn.exercisesSheetColumnIndex + 1,
            exercisesSheetRowNumber: candidates.single,
          )) {
        cells.add(
          FormulaHealingCellIssue(
            sheetRowNumber: sheetRowNumber,
            sheetColumnNumber: sheetColumnNumber,
            columnName: formulaColumn.activeColumnName,
            reason: FormulaHealingIssueReason.brokenFormula,
            currentFormula: currentFormula,
          ),
        );
      }
    }

    if (cells.isEmpty) {
      continue;
    }

    issues.add(
      FormulaHealingIssue(
        activeSheetRowNumber: sheetRowNumber,
        displayedExerciseName: displayedExerciseName,
        preselectedExerciseSheetRowNumber: candidates.length == 1
            ? candidates.single
            : null,
        requiresUserSelection: candidates.length != 1,
        candidateExerciseSheetRowNumbers: candidates,
        cells: cells,
      ),
    );
  }

  return issues;
}

List<int> _matchingExerciseRows(
  List<List<String>> exercisesRows,
  int exerciseColumnIndex,
  String displayedExerciseName,
) {
  final matches = <int>[];
  for (var rowIndex = 1; rowIndex < exercisesRows.length; rowIndex += 1) {
    if (_cell(exercisesRows[rowIndex], exerciseColumnIndex).trim() ==
        displayedExerciseName) {
      matches.add(rowIndex + 1);
    }
  }
  return matches;
}

bool _formulaMatchesDirectReference(
  String formula, {
  required int exercisesSheetColumnNumber,
  required int exercisesSheetRowNumber,
}) {
  final expected = _directExercisesFormula(
    exercisesSheetColumnNumber: exercisesSheetColumnNumber,
    exercisesSheetRowNumber: exercisesSheetRowNumber,
  );
  final quotedExpected =
      "='Exercises'!${_columnLetter(exercisesSheetColumnNumber)}"
      '$exercisesSheetRowNumber';
  final normalized = formula.trim();
  return normalized == expected || normalized == quotedExpected;
}

String _directExercisesFormula({
  required int exercisesSheetColumnNumber,
  required int exercisesSheetRowNumber,
}) {
  return '=Exercises!${_columnLetter(exercisesSheetColumnNumber)}'
      '$exercisesSheetRowNumber';
}

int _defaultExerciseColumnNumber(String activeColumnName) {
  switch (activeColumnName) {
    case 'Exercise':
      return 1;
    case 'Sets':
      return 3;
    case 'Reps':
      return 4;
    case 'RPE':
      return 5;
    case 'Rest':
      return 6;
    case 'Tempo':
      return 7;
    case 'Notes':
      return 8;
    case 'Log Format':
      return 9;
    default:
      return 1;
  }
}

String _columnLetter(int oneBasedColumnNumber) {
  var columnNumber = oneBasedColumnNumber;
  var letters = '';
  while (columnNumber > 0) {
    final remainder = (columnNumber - 1) % 26;
    letters = String.fromCharCode(65 + remainder) + letters;
    columnNumber = (columnNumber - 1) ~/ 26;
  }
  return letters;
}

class _FormulaDrivenColumn {
  const _FormulaDrivenColumn({
    required this.activeColumnName,
    required this.activeSheetColumnIndex,
    required this.exercisesSheetColumnIndex,
  });

  final String activeColumnName;
  final int activeSheetColumnIndex;
  final int exercisesSheetColumnIndex;
}

List<_FormulaDrivenColumn> _formulaDrivenColumns(
  _FixedColumnIndexes active,
  _ExercisesColumnIndexes exercises,
) {
  return [
    _FormulaDrivenColumn(
      activeColumnName: 'Exercise',
      activeSheetColumnIndex: active.exercise,
      exercisesSheetColumnIndex: exercises.exercise,
    ),
    _FormulaDrivenColumn(
      activeColumnName: 'Sets',
      activeSheetColumnIndex: active.sets,
      exercisesSheetColumnIndex: exercises.defaultSets,
    ),
    _FormulaDrivenColumn(
      activeColumnName: 'Reps',
      activeSheetColumnIndex: active.reps,
      exercisesSheetColumnIndex: exercises.defaultReps,
    ),
    _FormulaDrivenColumn(
      activeColumnName: 'RPE',
      activeSheetColumnIndex: active.rpe,
      exercisesSheetColumnIndex: exercises.defaultRpe,
    ),
    _FormulaDrivenColumn(
      activeColumnName: 'Rest',
      activeSheetColumnIndex: active.rest,
      exercisesSheetColumnIndex: exercises.defaultRest,
    ),
    _FormulaDrivenColumn(
      activeColumnName: 'Tempo',
      activeSheetColumnIndex: active.tempo,
      exercisesSheetColumnIndex: exercises.defaultTempo,
    ),
    _FormulaDrivenColumn(
      activeColumnName: 'Notes',
      activeSheetColumnIndex: active.notes,
      exercisesSheetColumnIndex: exercises.notes,
    ),
    if (active.logFormat != null && exercises.logFormat != null)
      _FormulaDrivenColumn(
        activeColumnName: 'Log Format',
        activeSheetColumnIndex: active.logFormat!,
        exercisesSheetColumnIndex: exercises.logFormat!,
      ),
  ];
}

class _CellAddress {
  const _CellAddress(this.sheetRowNumber, this.sheetColumnNumber);

  final int sheetRowNumber;
  final int sheetColumnNumber;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _CellAddress &&
            sheetRowNumber == other.sheetRowNumber &&
            sheetColumnNumber == other.sheetColumnNumber;
  }

  @override
  int get hashCode => Object.hash(sheetRowNumber, sheetColumnNumber);
}
