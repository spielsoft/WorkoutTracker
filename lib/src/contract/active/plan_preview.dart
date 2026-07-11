part of '../active.dart';

class _PlanPreview {
  const _PlanPreview._();

  static List<List<String>> active(
    ActiveSheetWritePlan plan,
    Iterable<Iterable<String>> rows,
  ) {
    final preview = _copy(rows);
    final rowInsertions = [...plan.rowInsertions]
      ..sort((a, b) => b.sheetRowNumber.compareTo(a.sheetRowNumber));
    final columnInsertions = [...plan.columnInsertions]
      ..sort((a, b) => b.sheetColumnNumber.compareTo(a.sheetColumnNumber));
    final rowDeletions = [...plan.rowDeletions]
      ..sort((a, b) => b.sheetRowNumber.compareTo(a.sheetRowNumber));

    if (columnInsertions.isNotEmpty) {
      while (preview.length < 2) {
        preview.add([]);
      }
    }

    for (final insertion in rowInsertions) {
      final rowIndex = insertion.sheetRowNumber - 1;
      if (rowIndex < 0) {
        continue;
      }
      final insertedRows = List.generate(
        insertion.rowCount,
        (_) => List.filled(insertion.cellCount, ''),
      );
      if (rowIndex >= preview.length) {
        while (preview.length < rowIndex) {
          preview.add([]);
        }
        preview.addAll(insertedRows);
      } else {
        preview.insertAll(rowIndex, insertedRows);
      }
    }

    for (final insertion in columnInsertions) {
      final columnIndex = insertion.sheetColumnNumber - 1;
      for (var rowIndex = 0; rowIndex < preview.length; rowIndex += 1) {
        final row = preview[rowIndex];
        while (row.length < columnIndex) {
          row.add('');
        }
        row.insertAll(columnIndex, insertion._valuesForRow(rowIndex));
      }
    }

    for (final update in plan.cellUpdates) {
      final rowIndex = update.sheetRowNumber - 1;
      final columnIndex = update.sheetColumnNumber - 1;
      if (rowIndex < 0) {
        continue;
      }
      while (preview.length <= rowIndex) {
        preview.add([]);
      }
      final row = preview[rowIndex];
      while (row.length <= columnIndex) {
        row.add('');
      }
      row[columnIndex] = update.value;
    }

    for (final deletion in rowDeletions) {
      final rowIndex = deletion.sheetRowNumber - 1;
      if (rowIndex < 0 || rowIndex >= preview.length) {
        continue;
      }
      final endIndex = rowIndex + deletion.rowCount;
      preview.removeRange(
        rowIndex,
        endIndex > preview.length ? preview.length : endIndex,
      );
    }

    return _freeze(preview);
  }

  static List<List<String>> exercises(
    ExercisesWritePlan plan,
    Iterable<Iterable<String>> rows,
  ) {
    final preview = _copy(rows);
    for (final update in plan.rowUpdates) {
      final rowIndex = update.sheetRowNumber - 1;
      if (rowIndex >= 0 && rowIndex < preview.length) {
        preview[rowIndex] = update.values.toList();
      }
    }
    for (final append in plan.rowAppends) {
      final rowIndex = append.sheetRowNumber - 1;
      while (preview.length < rowIndex) {
        preview.add([]);
      }
      if (rowIndex == preview.length) {
        preview.add(append.values.toList());
      } else {
        preview.insert(rowIndex, append.values.toList());
      }
    }
    return _freeze(preview);
  }

  static List<List<String>> _copy(Iterable<Iterable<String>> rows) {
    return rows.map((row) => row.toList()).toList();
  }

  static List<List<String>> _freeze(List<List<String>> rows) {
    return rows.map((row) => List<String>.unmodifiable(row)).toList();
  }
}
