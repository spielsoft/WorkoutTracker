import '../defaults.dart';

sealed class LogFormatParseResult {
  const LogFormatParseResult();
}

const defaultLogFormatText = defaultLogFormat;

class ParsedLogFormat extends LogFormatParseResult {
  const ParsedLogFormat(this.segments);

  final List<LogFormatSegment> segments;

  List<String> get fieldLabels => [
    for (final segment in segments)
      if (segment case LogField(:final label)) label,
  ];

  List<String> get literalSegments => [
    for (final segment in segments)
      if (segment case LogLiteral(:final text)) text,
  ];

  String get representativeEntry {
    const samples = ['100', '8', '8', '1', '0'];
    return render({
      for (var i = 0; i < fieldLabels.length; i += 1)
        fieldLabels[i]: samples[i],
    });
  }

  String render(Map<String, String> fieldValues) {
    final buffer = StringBuffer();
    for (final segment in segments) {
      switch (segment) {
        case LogField(:final label):
          buffer.write(fieldValues[label] ?? '');
        case LogLiteral(:final text):
          buffer.write(text);
      }
    }
    return buffer.toString();
  }

  String renderValues(Map<String, String> values) {
    if (fieldLabels.every((label) => (values[label] ?? '').isEmpty)) {
      return '';
    }
    return render(values);
  }

  Map<String, String>? parseValues(String text) {
    if (text.isEmpty) {
      return Map<String, String>.unmodifiable({
        for (final label in fieldLabels) label: '',
      });
    }
    return switch (parseLogEntry(this, text)) {
      FormattedLogEntry(:final fieldValues) => fieldValues,
      RawLogEntry() => null,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ParsedLogFormat && _listEquals(segments, other.segments);
  }

  @override
  int get hashCode => Object.hashAll(segments);

  @override
  String toString() => 'ParsedLogFormat($segments)';
}

sealed class LogEntry {
  const LogEntry();
}

class FormattedLogEntry extends LogEntry {
  FormattedLogEntry({
    required Iterable<String> fieldLabels,
    required Map<String, String> fieldValues,
  }) : fieldLabels = List<String>.unmodifiable(fieldLabels),
       fieldValues = Map<String, String>.unmodifiable(fieldValues);

  final List<String> fieldLabels;
  final Map<String, String> fieldValues;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FormattedLogEntry &&
            _listEquals(fieldLabels, other.fieldLabels) &&
            _mapEquals(fieldValues, other.fieldValues);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(fieldLabels),
    Object.hashAll(
      fieldValues.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );

  @override
  String toString() {
    return 'FormattedLogEntry('
        'fieldLabels: $fieldLabels, '
        'fieldValues: $fieldValues'
        ')';
  }
}

class RawLogEntry extends LogEntry {
  const RawLogEntry(this.text);

  final String text;

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is RawLogEntry && text == other.text;
  }

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'RawLogEntry($text)';
}

class InvalidLogFormat extends LogFormatParseResult {
  const InvalidLogFormat(this.errors);

  final List<String> errors;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InvalidLogFormat && _listEquals(errors, other.errors);
  }

  @override
  int get hashCode => Object.hashAll(errors);

  @override
  String toString() => 'InvalidLogFormat($errors)';
}

sealed class LogFormatSegment {
  const LogFormatSegment();
}

class LogField extends LogFormatSegment {
  const LogField(this.label);

  final String label;

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is LogField && label == other.label;
  }

  @override
  int get hashCode => label.hashCode;

  @override
  String toString() => 'LogField($label)';
}

class LogLiteral extends LogFormatSegment {
  const LogLiteral(this.text);

  final String text;

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is LogLiteral && text == other.text;
  }

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'LogLiteral($text)';
}

LogFormatParseResult parseLogFormat(String text) {
  final source = text.trim().isEmpty ? defaultLogFormatText : text;
  final segments = <LogFormatSegment>[];
  var index = 0;
  while (index < source.length) {
    if (source[index] == '}') {
      return const InvalidLogFormat([
        'Closing braces must have a matching opening brace.',
      ]);
    }
    if (source[index] != '{') {
      final nextField = source.indexOf('{', index);
      final end = nextField == -1 ? source.length : nextField;
      final literal = source.substring(index, end);
      if (literal.contains('}')) {
        return const InvalidLogFormat([
          'Closing braces must have a matching opening brace.',
        ]);
      }
      segments.add(LogLiteral(literal));
      index = end;
      continue;
    }

    final end = source.indexOf('}', index + 1);
    if (end == -1) {
      return const InvalidLogFormat([
        'Opening braces must have a matching closing brace.',
      ]);
    }
    final label = source.substring(index + 1, end);
    if (label.trim().isEmpty) {
      return const InvalidLogFormat(['Field labels must not be blank.']);
    }
    if (label.contains('{')) {
      return const InvalidLogFormat(['Field labels cannot contain braces.']);
    }
    if (segments.isNotEmpty && segments.last is LogField) {
      return const InvalidLogFormat([
        'Adjacent fields need literal text between them.',
      ]);
    }
    segments.add(LogField(label));
    index = end + 1;
  }

  final fieldCount = segments.whereType<LogField>().length;
  if (fieldCount < 1 || fieldCount > 5) {
    return const InvalidLogFormat(['Log formats support one to five fields.']);
  }

  final labels = [
    for (final field in segments.whereType<LogField>()) field.label,
  ];
  if (labels.toSet().length != labels.length) {
    return const InvalidLogFormat(['Field labels must be unique.']);
  }

  return ParsedLogFormat(segments);
}

LogEntry parseLogEntry(ParsedLogFormat format, String text) {
  final values = _parseLogEntrySegments(format.segments, text);
  if (values == null) {
    return RawLogEntry(text);
  }
  return FormattedLogEntry(
    fieldLabels: format.fieldLabels,
    fieldValues: values,
  );
}

Map<String, String>? _parseLogEntrySegments(
  List<LogFormatSegment> segments,
  String source,
) {
  Map<String, String>? parseFrom(
    int segmentIndex,
    int textIndex,
    Map<String, String> values,
  ) {
    if (segmentIndex == segments.length) {
      return textIndex == source.length ? values : null;
    }

    final segment = segments[segmentIndex];
    switch (segment) {
      case LogLiteral(:final text):
        if (!source.startsWith(text, textIndex)) {
          return null;
        }
        return parseFrom(segmentIndex + 1, textIndex + text.length, values);
      case LogField(:final label):
        for (
          var endIndex = textIndex;
          endIndex <= source.length;
          endIndex += 1
        ) {
          final nextValues = Map<String, String>.of(values);
          nextValues[label] = source.substring(textIndex, endIndex);
          final parsed = parseFrom(segmentIndex + 1, endIndex, nextValues);
          if (parsed != null) {
            return parsed;
          }
        }
    }
    return null;
  }

  return parseFrom(0, 0, <String, String>{});
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> left, Map<K, V> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
