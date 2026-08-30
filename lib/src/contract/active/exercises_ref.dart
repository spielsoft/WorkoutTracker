part of '../active.dart';

// The one direct `Exercises` reference format, read and written here.
//
// A placement's binding is a formula in one direction and a parsed cell in
// the other, so both directions live in this file. Splitting them let a
// healing check that rendered its own string stop agreeing with the reader
// that resolves a placement's canonical row, and a placement bound to two
// different rows satisfied both halves at once.

/// The `Exercises` cell one direct reference names.
class _ExerciseRef {
  const _ExerciseRef({required this.columnNumber, required this.rowNumber});

  final int columnNumber;
  final int rowNumber;
}

/// One direct `Exercises` reference, quoted or not: `=Exercises!A7`.
final _exerciseRefPattern = RegExp(
  r"^=(?:Exercises|'Exercises')!([A-Z]+)(\d+)$",
);

/// Reads the cell a direct `Exercises` formula points at, or null.
///
/// Anything else - a blank cell, a computed lookup, a reference to another
/// tab - is not a binding and never becomes one by guessing.
_ExerciseRef? _exerciseRef(String formula) {
  final match = _exerciseRefPattern.firstMatch(formula.trim());
  if (match == null) {
    return null;
  }
  return _ExerciseRef(
    columnNumber: _columnNumber(match.group(1)!),
    rowNumber: int.parse(match.group(2)!),
  );
}

/// Writes the direct reference [_exerciseRef] reads back.
String _directExercisesFormula({
  required int exerciseColumn,
  required int exercisesSheetRowNumber,
}) {
  return '=Exercises!${_columnLetter(exerciseColumn)}'
      '$exercisesSheetRowNumber';
}

/// The `Exercises` row an active `Exercise` formula binds a placement to.
///
/// Only a direct reference into the name column at a row that names an
/// exercise binds anything. A blank cell, a reference into another column, a
/// computed lookup, and a row outside the grid all leave the placement
/// unbound; the visible name is never a fallback because names may repeat.
int? _boundExercisesRow(
  String formula, {
  required int nameColumnIndex,
  required List<List<String>> exercisesRows,
}) {
  final reference = _exerciseRef(formula);
  if (reference == null || reference.columnNumber != nameColumnIndex + 1) {
    return null;
  }
  final rowIndex = reference.rowNumber - 1;
  if (rowIndex < 1 || rowIndex >= exercisesRows.length) {
    return null;
  }
  if (_cell(exercisesRows[rowIndex], nameColumnIndex).trim().isEmpty) {
    return null;
  }
  return reference.rowNumber;
}

int _columnNumber(String letters) {
  var columnNumber = 0;
  for (final codeUnit in letters.codeUnits) {
    columnNumber = columnNumber * 26 + (codeUnit - 64);
  }
  return columnNumber;
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
