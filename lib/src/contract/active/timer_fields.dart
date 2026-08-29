part of '../active.dart';

/// The whole `Timer Fields` cell: blank, `[]`, or quoted exact labels.
final _timerFieldsCell = RegExp(r"^\[\s*(?:'[^']*'(?:\s*,\s*'[^']*')*\s*)?\]$");

/// One quoted label inside an already validated `Timer Fields` cell.
final _timerFieldsLabel = RegExp(r"'([^']*)'");

/// Reads a `Timer Fields` cell as its exact labels in written order.
///
/// A blank cell means no timed fields. Returns null when the cell is not a
/// list of quoted labels, which the workbook contract treats as damage rather
/// than silently ignoring configuration a person can see in the Sheet.
List<String>? _parseTimerFields(String cell) {
  final text = cell.trim();
  if (text.isEmpty) {
    return const [];
  }
  if (!_timerFieldsCell.hasMatch(text)) {
    return null;
  }
  return [
    for (final match in _timerFieldsLabel.allMatches(text)) match.group(1)!,
  ];
}

/// Renders the labels [format] still declares, in declaration order.
///
/// Labels the current format no longer declares are dropped so a format
/// change can never write timer configuration the reread would reject.
String _renderTimerFields(
  LogFormatParseResult format,
  Iterable<String> labels,
) {
  final declared = _declaredTimerFields(format, labels);
  if (declared.isEmpty) {
    return '';
  }
  return "[${declared.map((label) => "'$label'").join(', ')}]";
}

/// Orders [labels] by [format] declaration, dropping duplicates and strangers.
List<String> _declaredTimerFields(
  LogFormatParseResult format,
  Iterable<String> labels,
) {
  if (format is! ParsedLogFormat) {
    return const [];
  }
  final selected = labels.toSet();
  return [
    for (final label in format.fieldLabels)
      if (selected.contains(label)) label,
  ];
}
