part of '../active.dart';

enum HealingIssueReason { missingFormula, brokenFormula }

class FormulaHealingIssue {
  FormulaHealingIssue({
    required this.activeSheetRowNumber,
    required this.exerciseName,
    required this.needsChoice,
    required Iterable<int> candidateRows,
    Iterable<HealingChoice> exerciseChoices = const [],
    this.preselectedRow,
    Iterable<HealingCellIssue> cells = const [],
  }) : candidateRows = List<int>.unmodifiable(candidateRows),
       exerciseChoices = List<HealingChoice>.unmodifiable(exerciseChoices),
       cells = List<HealingCellIssue>.unmodifiable(cells);

  final int activeSheetRowNumber;
  final String exerciseName;
  final int? preselectedRow;
  final bool needsChoice;
  final List<int> candidateRows;
  final List<HealingChoice> exerciseChoices;
  final List<HealingCellIssue> cells;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FormulaHealingIssue &&
            activeSheetRowNumber == other.activeSheetRowNumber &&
            exerciseName == other.exerciseName &&
            preselectedRow == other.preselectedRow &&
            needsChoice == other.needsChoice &&
            _listEquals(candidateRows, other.candidateRows) &&
            _listEquals(exerciseChoices, other.exerciseChoices) &&
            _listEquals(cells, other.cells);
  }

  @override
  int get hashCode => Object.hash(
    activeSheetRowNumber,
    exerciseName,
    preselectedRow,
    needsChoice,
    Object.hashAll(candidateRows),
    Object.hashAll(exerciseChoices),
    Object.hashAll(cells),
  );

  @override
  String toString() {
    return 'FormulaHealingIssue('
        'activeSheetRowNumber: $activeSheetRowNumber, '
        'exerciseName: $exerciseName, '
        'preselectedRow: $preselectedRow, '
        'needsChoice: $needsChoice, '
        'candidateRows: $candidateRows, '
        'exerciseChoices: $exerciseChoices, '
        'cells: $cells'
        ')';
  }
}

class HealingChoice {
  const HealingChoice({
    required this.sheetRowNumber,
    required this.exerciseName,
    required this.description,
  });

  final int sheetRowNumber;
  final String exerciseName;
  final String description;

  String get label {
    final trimmedDescription = description.trim();
    if (trimmedDescription.isEmpty) {
      return 'Row $sheetRowNumber: $exerciseName';
    }
    return 'Row $sheetRowNumber: $exerciseName - $trimmedDescription';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HealingChoice &&
            sheetRowNumber == other.sheetRowNumber &&
            exerciseName == other.exerciseName &&
            description == other.description;
  }

  @override
  int get hashCode => Object.hash(sheetRowNumber, exerciseName, description);

  @override
  String toString() {
    return 'HealingChoice('
        'sheetRowNumber: $sheetRowNumber, '
        'exerciseName: $exerciseName, '
        'description: $description'
        ')';
  }
}

class HealingCellIssue {
  const HealingCellIssue({
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
    required this.columnName,
    required this.reason,
    required this.currentFormula,
  });

  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String columnName;
  final HealingIssueReason reason;
  final String currentFormula;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HealingCellIssue &&
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
    return 'HealingCellIssue('
        'sheetRowNumber: $sheetRowNumber, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'columnName: $columnName, '
        'reason: $reason, '
        'currentFormula: $currentFormula'
        ')';
  }
}

class _HealingPlanner {
  _HealingPlanner(this.sheet);

  final ParsedActiveSheet sheet;

  ActiveSheetWritePlan planFormulaHealing({
    required int activeSheetRowNumber,
    int? selectedRow,
  }) {
    if (sheet.schemaViolations.isNotEmpty) {
      return ActiveSheetWritePlan();
    }
    FormulaHealingIssue? issue;
    for (final candidate in sheet.healingIssues) {
      if (candidate.activeSheetRowNumber == activeSheetRowNumber) {
        issue = candidate;
        break;
      }
    }
    if (issue == null) {
      return ActiveSheetWritePlan();
    }

    final exerciseSheetRowNumber = selectedRow ?? issue.preselectedRow;
    if (exerciseSheetRowNumber == null) {
      return ActiveSheetWritePlan();
    }

    final slot = _slotForRow(sheet, activeSheetRowNumber);
    return ActiveSheetWritePlan(
      cellUpdates: [
        for (final cell in issue.cells)
          CellUpdate.formula(
            sheetRowNumber: cell.sheetRowNumber,
            sheetColumnNumber: cell.sheetColumnNumber,
            value: _directExercisesFormula(
              exerciseColumn:
                  sheet._exerciseFormulaColumns[cell.columnName] ??
                  _defaultExerciseColumn(cell.columnName),
              exercisesSheetRowNumber: exerciseSheetRowNumber,
            ),
          ),
      ],
      expectations: [
        if (slot != null)
          RepairRowExpct(
            sheetRowNumber: activeSheetRowNumber,
            expectedValues: sheet._sheetRow(activeSheetRowNumber),
          ),
      ],
    );
  }

  ActiveSheetWritePlan planFormulaRepair() {
    if (sheet.schemaViolations.isNotEmpty) {
      return ActiveSheetWritePlan();
    }
    final updates = <CellUpdate>[];
    final expectations = <WriteExpct>[];
    for (final issue in sheet.healingIssues) {
      if (issue.needsChoice) {
        continue;
      }
      final plan = planFormulaHealing(
        activeSheetRowNumber: issue.activeSheetRowNumber,
      );
      updates.addAll(plan.cellUpdates);
      expectations.addAll(plan.expectations);
    }
    return ActiveSheetWritePlan(
      cellUpdates: updates,
      expectations: expectations,
    );
  }
}

List<FormulaHealingIssue> _healingIssues(
  ActiveSheetInput sheet,
  _FixedColumnIndexes columns,
) {
  if (sheet.exercisesRows.isEmpty) {
    return const [];
  }

  final exerciseColumns = _ExercisesColumnIndexes.fromHeader(
    sheet.exercisesRows.first,
  );
  final exerciseChoices = _exerciseChoices(
    sheet.exercisesRows,
    exerciseColumns.exercise,
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
    final exerciseName = _cell(row, columns.exercise).trim();
    if (exerciseName.isEmpty) {
      continue;
    }

    final candidates = _matchingRows(
      sheet.exercisesRows,
      exerciseColumns.exercise,
      exerciseName,
    );
    final cells = <HealingCellIssue>[];
    for (final formulaColumn in _formulaDrivenColumns(
      columns,
      exerciseColumns,
    )) {
      final sheetColumnNumber = formulaColumn.activeSheetColumnIndex + 1;
      final currentFormula =
          formulas[_CellAddress(sheetRowNumber, sheetColumnNumber)] ?? '';
      if (currentFormula.trim().isEmpty) {
        cells.add(
          HealingCellIssue(
            sheetRowNumber: sheetRowNumber,
            sheetColumnNumber: sheetColumnNumber,
            columnName: formulaColumn.activeColumnName,
            reason: HealingIssueReason.missingFormula,
            currentFormula: '',
          ),
        );
      } else if (!_matchesAnyDirectRef(
        currentFormula,
        exerciseColumn: formulaColumn.exerciseColumnIndex + 1,
        exercisesSheetRowNumbers: candidates.isEmpty
            ? exerciseChoices.map((choice) => choice.sheetRowNumber)
            : candidates,
      )) {
        cells.add(
          HealingCellIssue(
            sheetRowNumber: sheetRowNumber,
            sheetColumnNumber: sheetColumnNumber,
            columnName: formulaColumn.activeColumnName,
            reason: HealingIssueReason.brokenFormula,
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
        exerciseName: exerciseName,
        preselectedRow: candidates.length == 1 ? candidates.single : null,
        needsChoice: candidates.length != 1,
        candidateRows: candidates,
        exerciseChoices: exerciseChoices,
        cells: cells,
      ),
    );
  }

  return issues;
}

List<HealingChoice> _exerciseChoices(
  List<List<String>> exercisesRows,
  int exerciseColumnIndex,
) {
  final choices = <HealingChoice>[];
  for (var rowIndex = 1; rowIndex < exercisesRows.length; rowIndex += 1) {
    final exerciseName = _cell(
      exercisesRows[rowIndex],
      exerciseColumnIndex,
    ).trim();
    if (exerciseName.isEmpty) {
      continue;
    }
    choices.add(
      HealingChoice(
        sheetRowNumber: rowIndex + 1,
        exerciseName: exerciseName,
        description: _cell(exercisesRows[rowIndex], 1).trim(),
      ),
    );
  }
  return List<HealingChoice>.unmodifiable(choices);
}

List<int> _matchingRows(
  List<List<String>> exercisesRows,
  int exerciseColumnIndex,
  String exerciseName,
) {
  final matches = <int>[];
  for (var rowIndex = 1; rowIndex < exercisesRows.length; rowIndex += 1) {
    if (_cell(exercisesRows[rowIndex], exerciseColumnIndex).trim() ==
        exerciseName) {
      matches.add(rowIndex + 1);
    }
  }
  return matches;
}

bool _matchesDirectRef(
  String formula, {
  required int exerciseColumn,
  required int exercisesSheetRowNumber,
}) {
  final expected = _directExercisesFormula(
    exerciseColumn: exerciseColumn,
    exercisesSheetRowNumber: exercisesSheetRowNumber,
  );
  final quotedExpected =
      "='Exercises'!${_columnLetter(exerciseColumn)}"
      '$exercisesSheetRowNumber';
  final normalized = formula.trim();
  return normalized == expected || normalized == quotedExpected;
}

bool _matchesAnyDirectRef(
  String formula, {
  required int exerciseColumn,
  required Iterable<int> exercisesSheetRowNumbers,
}) {
  for (final rowNumber in exercisesSheetRowNumbers) {
    if (_matchesDirectRef(
      formula,
      exerciseColumn: exerciseColumn,
      exercisesSheetRowNumber: rowNumber,
    )) {
      return true;
    }
  }
  return false;
}

String _directExercisesFormula({
  required int exerciseColumn,
  required int exercisesSheetRowNumber,
}) {
  return '=Exercises!${_columnLetter(exerciseColumn)}'
      '$exercisesSheetRowNumber';
}

int _defaultExerciseColumn(String activeColumnName) {
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
    required this.exerciseColumnIndex,
  });

  final String activeColumnName;
  final int activeSheetColumnIndex;
  final int exerciseColumnIndex;
}

List<_FormulaDrivenColumn> _formulaDrivenColumns(
  _FixedColumnIndexes active,
  _ExercisesColumnIndexes exercises,
) {
  return [
    _FormulaDrivenColumn(
      activeColumnName: 'Exercise',
      activeSheetColumnIndex: active.exercise,
      exerciseColumnIndex: exercises.exercise,
    ),
    _FormulaDrivenColumn(
      activeColumnName: 'Log Format',
      activeSheetColumnIndex: active.logFormat,
      exerciseColumnIndex: exercises.logFormat,
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
