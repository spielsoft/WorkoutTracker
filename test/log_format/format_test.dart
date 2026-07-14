import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/format.dart';

void main() {
  test('parses field labels and literal segments in format order', () {
    final format = parseLogFormat('{Weight}x{Reps}@{RPE}');

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

  test('accepts formats with one to five exact fields', () {
    final oneField = parseLogFormat('{Reps}');
    final fiveFields = parseLogFormat('{A},{b},{C c},{D (kg)},{E}');

    expect(oneField, isA<ParsedLogFormat>());
    expect((oneField as ParsedLogFormat).fieldLabels, ['Reps']);
    expect(fiveFields, isA<ParsedLogFormat>());
    expect((fiveFields as ParsedLogFormat).fieldLabels, [
      'A',
      'b',
      'C c',
      'D (kg)',
      'E',
    ]);
  });

  test('rejects empty field labels through a validation result', () {
    final format = parseLogFormat('{Weight}x{}');

    expect(format, isA<InvalidLogFormat>());
    final invalid = format as InvalidLogFormat;
    expect(invalid.errors, contains('Field labels must not be blank.'));
  });

  test('rejects malformed field labels through a validation result', () {
    final format = parseLogFormat('{Weight{x{Reps}');

    expect(format, isA<InvalidLogFormat>());
    final invalid = format as InvalidLogFormat;
    expect(invalid.errors, contains('Field labels cannot contain braces.'));
  });

  test('rejects formats with more than five fields', () {
    final format = parseLogFormat('{A},{B},{C},{D},{E},{F}');

    expect(format, isA<InvalidLogFormat>());
    final invalid = format as InvalidLogFormat;
    expect(invalid.errors, contains('Log formats support one to five fields.'));
  });

  test('rejects duplicate field labels', () {
    final format = parseLogFormat('{Reps}x{Reps}');

    expect(format, isA<InvalidLogFormat>());
    expect(
      (format as InvalidLogFormat).errors,
      contains('Field labels must be unique.'),
    );
  });

  test('rejects unmatched braces and adjacent fields', () {
    expect(
      (parseLogFormat('{Weight') as InvalidLogFormat).errors,
      contains('Opening braces must have a matching closing brace.'),
    );
    expect(
      (parseLogFormat('Weight}') as InvalidLogFormat).errors,
      contains('Closing braces must have a matching opening brace.'),
    );
    expect(
      (parseLogFormat('{Weight}{Reps}') as InvalidLogFormat).errors,
      contains('Adjacent fields need literal text between them.'),
    );
  });

  test('round-trips the five-field DB Step-Up shape with exact keys', () {
    final format =
        parseLogFormat('({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}')
            as ParsedLogFormat;
    const values = {
      'Height (in)': '12',
      'Weight (lbs)': '15',
      'Reps': '8',
      'RPE': '8',
      'Pain': '0',
    };

    expect(format.fieldLabels, values.keys);
    expect(format.renderValues(values), '(12, 15)x8@8,0');
    expect(format.parseValues('(12, 15)x8@8,0'), values);
  });

  test('renders field values and literal segments in format order', () {
    final format = parseLogFormat('{Weight}x{Reps}@{RPE}') as ParsedLogFormat;

    expect(
      format.render({'Weight': '150', 'Reps': '10', 'RPE': '8'}),
      '150x10@8',
    );
  });

  test('renders a representative entry for a parsed format', () {
    final format = parseLogFormat('{Weight}x{Reps}@{RPE}') as ParsedLogFormat;

    expect(format.representativeEntry, '100x8@8');
  });

  test('renders literals even when adjacent field values are blank', () {
    final format =
        parseLogFormat('{Weight}x{Reps}@{RPE},{Pain}') as ParsedLogFormat;

    expect(
      format.render({'Weight': '150', 'Reps': '10', 'RPE': '8', 'Pain': ''}),
      '150x10@8,',
    );
  });

  test('renders repeated literal delimiters without omitting blank fields', () {
    final format = parseLogFormat('{A},{B},{C}') as ParsedLogFormat;

    expect(format.render({'A': 'left', 'B': '', 'C': 'right'}), 'left,,right');
  });

  test('round-trips blank and partial field values', () {
    final format = parseLogFormat('{Weight}x{Reps}@{RPE}') as ParsedLogFormat;

    expect(format.renderValues(const {}), '');
    expect(format.parseValues(''), {'Weight': '', 'Reps': '', 'RPE': ''});
    expect(
      format.parseValues(
        format.renderValues(const {'Weight': '', 'Reps': '8-10', 'RPE': '8'}),
      ),
      {'Weight': '', 'Reps': '8-10', 'RPE': '8'},
    );
  });
}
