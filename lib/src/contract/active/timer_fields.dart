part of '../active.dart';

/// The one codec for the `Timer Fields` cell, owning render and parse together.
///
/// The cell stays a human-editable list of quoted labels such as `['Seconds']`.
/// A Log Format label may hold any character except braces, so quotes and
/// backslashes are escaped the way every mainstream language escapes them:
///
/// - `\'` inside quotes is an apostrophe;
/// - `\\` inside quotes is a backslash;
/// - every other character, including commas, brackets, spaces, and non-ASCII
///   text, stands for itself and is never escaped.
///
/// A backslash followed by anything else is malformed rather than a guess, so a
/// hand-typed mistake surfaces as blocking schema damage instead of silently
/// becoming a different label.
const _timerFieldsQuote = "'";
const _timerFieldsEscape = r'\';

/// Reads a `Timer Fields` cell as its exact labels in written order.
///
/// A blank cell means no timed fields. Returns null when the cell is not a
/// well-formed list of quoted labels, which the workbook contract treats as
/// damage rather than silently ignoring configuration a person can see in the
/// Sheet.
List<String>? _parseTimerFields(String cell) {
  final text = cell.trim();
  if (text.isEmpty) {
    return const [];
  }
  if (!text.startsWith('[') || !text.endsWith(']')) {
    return null;
  }

  final end = text.length - 1;
  final labels = <String>[];
  var index = _skipTimerFieldsSpace(text, 1, end);
  if (index == end) {
    return labels;
  }

  while (true) {
    final label = _readTimerFieldsLabel(text, index, end);
    if (label == null) {
      return null;
    }
    labels.add(label.value);
    index = _skipTimerFieldsSpace(text, label.next, end);
    if (index == end) {
      return labels;
    }
    if (text[index] != ',') {
      return null;
    }
    index = _skipTimerFieldsSpace(text, index + 1, end);
  }
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
  return '[${declared.map(_quoteTimerFieldsLabel).join(', ')}]';
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

/// Quotes one label, escaping only the two characters the grammar reserves.
String _quoteTimerFieldsLabel(String label) {
  final escaped = label
      .replaceAll(_timerFieldsEscape, '$_timerFieldsEscape$_timerFieldsEscape')
      .replaceAll(_timerFieldsQuote, '$_timerFieldsEscape$_timerFieldsQuote');
  return '$_timerFieldsQuote$escaped$_timerFieldsQuote';
}

/// Reads the quoted label starting at [start], or null when it is malformed.
///
/// Returns the exact label and the index just past its closing quote.
/// Characters between the quotes are exact, so a label keeps its own leading
/// and trailing spaces; only text outside the quotes is padding.
({String value, int next})? _readTimerFieldsLabel(
  String text,
  int start,
  int end,
) {
  if (start >= end || text[start] != _timerFieldsQuote) {
    return null;
  }
  final value = StringBuffer();
  var index = start + 1;
  while (index < end) {
    final char = text[index];
    if (char == _timerFieldsQuote) {
      return (value: value.toString(), next: index + 1);
    }
    if (char == _timerFieldsEscape) {
      index += 1;
      if (index >= end) {
        return null;
      }
      final escaped = text[index];
      if (escaped != _timerFieldsEscape && escaped != _timerFieldsQuote) {
        return null;
      }
      value.write(escaped);
      index += 1;
      continue;
    }
    value.write(char);
    index += 1;
  }
  return null;
}

/// Skips padding between the brackets, quotes, and commas of a cell.
int _skipTimerFieldsSpace(String text, int start, int end) {
  var index = start;
  while (index < end && text[index].trim().isEmpty) {
    index += 1;
  }
  return index;
}
