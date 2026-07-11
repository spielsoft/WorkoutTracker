part of '../active.dart';

const defaultWorkoutName = 'Default';

const activeSheetFixedColumns = [
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

const exercisesSheetColumns = [
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

const defaultExerciseLogFormat = defaultLogFormat;

class ActiveSheetInput {
  ActiveSheetInput({
    required Iterable<Iterable<String>> rows,
    Iterable<CellFormula> cellFormulas = const [],
    Iterable<Iterable<String>> exercisesRows = const [],
    this.hasExercisesSheet = true,
    this.validateWorkbook = false,
    Set<int> mergedFirstColumnRows = const {},
  }) : rows = List<List<String>>.unmodifiable(
         rows.map((row) => List<String>.unmodifiable(row)),
       ),
       cellFormulas = List<CellFormula>.unmodifiable(cellFormulas),
       exercisesRows = List<List<String>>.unmodifiable(
         exercisesRows.map((row) => List<String>.unmodifiable(row)),
       ),
       mergedFirstColumnRows = Set.unmodifiable(mergedFirstColumnRows);

  final List<List<String>> rows;
  final List<CellFormula> cellFormulas;
  final List<List<String>> exercisesRows;
  final bool hasExercisesSheet;

  /// Whether missing workbook tabs and headers must be reported.
  ///
  /// Active-sheet-only contract tests may omit the Exercises grid. Production
  /// workbook reads always set this to true.
  final bool validateWorkbook;

  /// 1-based sheet row numbers whose first display cell is merged for humans.
  final Set<int> mergedFirstColumnRows;
}

class CellFormula {
  const CellFormula({
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
    required this.formula,
  });

  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String formula;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CellFormula &&
            sheetRowNumber == other.sheetRowNumber &&
            sheetColumnNumber == other.sheetColumnNumber &&
            formula == other.formula;
  }

  @override
  int get hashCode => Object.hash(sheetRowNumber, sheetColumnNumber, formula);

  @override
  String toString() {
    return 'CellFormula('
        'sheetRowNumber: $sheetRowNumber, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'formula: $formula'
        ')';
  }
}
