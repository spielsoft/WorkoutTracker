import 'format.dart';

const legacyLogFormat = '{Weight}[x]{Reps}[@]{RPE}';

/// Parses the pre-1.0 bracket-token syntax for explicitly routed workbooks.
///
/// This internal parser is deliberately not exported as part of the public
/// log-format language.
LogFormatParseResult parseLegacyLogFormat(String text) {
  final source = text.trim().isEmpty ? legacyLogFormat : text;
  final segments = <LogFormatSegment>[];
  var index = 0;
  while (index < source.length) {
    final marker = source[index];
    if (marker != '{' && marker != '[') {
      return const InvalidLogFormat(['Format text must use {} or [] tokens.']);
    }
    final endMarker = marker == '{' ? '}' : ']';
    final end = source.indexOf(endMarker, index + 1);
    if (end == -1) {
      return const InvalidLogFormat(['Format tokens must be closed.']);
    }
    final value = source.substring(index + 1, end);
    if (marker == '{' && value.trim().isEmpty) {
      return const InvalidLogFormat(['Field labels must not be blank.']);
    }
    if (marker == '{' && _containsMarker(value)) {
      return const InvalidLogFormat(['Field labels cannot contain brackets.']);
    }
    segments.add(marker == '{' ? LogField(value) : LogLiteral(value));
    index = end + 1;
  }

  final fields = segments.whereType<LogField>().toList();
  if (fields.isEmpty || fields.length > 4) {
    return const InvalidLogFormat(['Log formats support one to four fields.']);
  }
  final labels = fields.map((field) => field.label).toList();
  if (labels.toSet().length != labels.length) {
    return const InvalidLogFormat(['Field labels must be unique.']);
  }
  return ParsedLogFormat(segments);
}

bool _containsMarker(String text) {
  return text.contains('{') ||
      text.contains('}') ||
      text.contains('[') ||
      text.contains(']');
}
