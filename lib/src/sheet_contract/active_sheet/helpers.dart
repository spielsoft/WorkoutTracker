part of '../active_sheet.dart';

String _cell(List<String> row, int index) {
  if (index < 0 || index >= row.length) {
    return '';
  }
  return row[index];
}

bool _isTrue(String value) {
  return value.trim().toLowerCase() == 'true';
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (first.length != second.length) {
    return false;
  }

  for (var index = 0; index < first.length; index += 1) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}

bool _nullableListEquals<T>(List<T>? first, List<T>? second) {
  if (first == null || second == null) {
    return first == second;
  }
  return _listEquals(first, second);
}
