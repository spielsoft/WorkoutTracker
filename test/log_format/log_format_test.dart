import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/log_format.dart';

void main() {
  test('parses field labels and literal segments in format order', () {
    final format = parseLogFormat('{Weight}[x]{Reps}[@]{RPE}');

    expect(format, isA<ParsedLogFormat>());
    final parsed = format as ParsedLogFormat;
    expect(parsed.fieldLabels, ['Weight', 'Reps', 'RPE']);
    expect(parsed.literalSegments, ['x', '@']);
    expect(parsed.segments, [
      const LogField('Weight'),
      const LogLiteral('x'),
      const LogField('Reps'),
      const LogLiteral('@'),
      const LogField('RPE'),
    ]);
  });

  test('blank format parses as the default weighted reps format', () {
    final format = parseLogFormat('');

    expect(format, isA<ParsedLogFormat>());
    final parsed = format as ParsedLogFormat;
    expect(parsed.fieldLabels, ['Weight', 'Reps', 'RPE']);
    expect(parsed.literalSegments, ['x', '@']);
  });

  test('accepts formats with one to four fields', () {
    final oneField = parseLogFormat('{Reps}');
    final fourFields = parseLogFormat('{A}[,]{B}[,]{C}[,]{D}');

    expect(oneField, isA<ParsedLogFormat>());
    expect((oneField as ParsedLogFormat).fieldLabels, ['Reps']);
    expect(fourFields, isA<ParsedLogFormat>());
    expect((fourFields as ParsedLogFormat).fieldLabels, ['A', 'B', 'C', 'D']);
  });

  test('rejects empty field labels through a validation result', () {
    final format = parseLogFormat('{Weight}[x]{}');

    expect(format, isA<InvalidLogFormat>());
    final invalid = format as InvalidLogFormat;
    expect(invalid.errors, contains('Field labels must not be blank.'));
  });

  test('rejects malformed field labels through a validation result', () {
    final format = parseLogFormat('{Weight[x]{Reps}');

    expect(format, isA<InvalidLogFormat>());
    final invalid = format as InvalidLogFormat;
    expect(invalid.errors, contains('Field labels cannot contain brackets.'));
  });

  test('rejects formats with more than four fields', () {
    final format = parseLogFormat('{A}[,]{B}[,]{C}[,]{D}[,]{E}');

    expect(format, isA<InvalidLogFormat>());
    final invalid = format as InvalidLogFormat;
    expect(invalid.errors, contains('Log formats support one to four fields.'));
  });

  test('renders field values and literal segments in format order', () {
    final format =
        parseLogFormat('{Weight}[x]{Reps}[@]{RPE}') as ParsedLogFormat;

    expect(
      format.render({'Weight': '150', 'Reps': '10', 'RPE': '8'}),
      '150x10@8',
    );
  });

  test('renders literals even when adjacent field values are blank', () {
    final format =
        parseLogFormat('{Weight}[x]{Reps}[@]{RPE}[,]{Pain}') as ParsedLogFormat;

    expect(
      format.render({'Weight': '150', 'Reps': '10', 'RPE': '8', 'Pain': ''}),
      '150x10@8,',
    );
  });

  test('renders repeated literal delimiters without omitting blank fields', () {
    final format = parseLogFormat('{A}[,]{B}[,]{C}') as ParsedLogFormat;

    expect(format.render({'A': 'left', 'B': '', 'C': 'right'}), 'left,,right');
  });
}
