import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/format.dart';

void main() {
  test('renders and extracts fields around literal text', () {
    final format = parseLogFormat('{Weight}x{Reps}@{RPE}') as ParsedLogFormat;
    const values = {'Weight': '150', 'Reps': '10', 'RPE': '8'};

    expect(format.renderValues(values), '150x10@8');
    expect(format.parseValues('150x10@8'), values);
  });

  test('blank format parses as the default weighted reps format', () {
    final format = parseLogFormat('');

    expect(format, isA<ParsedLogFormat>());
    final parsed = format as ParsedLogFormat;
    expect(
      parsed.renderValues(const {'Weight': '100', 'Reps': '8', 'RPE': '8'}),
      '100x8@8',
    );
  });

  test('accepts formats with one to five exact fields', () {
    final oneField = parseLogFormat('{Reps}');
    final fiveFields = parseLogFormat('{A},{b},{C c},{D (kg)},{E}');

    expect((oneField as ParsedLogFormat).parseValues('8'), const {'Reps': '8'});
    expect((fiveFields as ParsedLogFormat).parseValues('1,2,3,4,5'), const {
      'A': '1',
      'b': '2',
      'C c': '3',
      'D (kg)': '4',
      'E': '5',
    });
  });

  test('rejects every malformed-format boundary with useful feedback', () {
    const cases = {
      '{Weight}x{}': 'Field labels must not be blank.',
      '{Weight{x{Reps}': 'Field labels cannot contain braces.',
      '{A},{B},{C},{D},{E},{F}': 'Log formats support one to five fields.',
      '{Reps}x{Reps}': 'Field labels must be unique.',
      '{Weight': 'Opening braces must have a matching closing brace.',
      'Weight}': 'Closing braces must have a matching opening brace.',
      '{Weight}{Reps}': 'Adjacent fields need literal text between them.',
    };

    for (final entry in cases.entries) {
      final parsed = parseLogFormat(entry.key);
      expect(parsed, isA<InvalidLogFormat>(), reason: entry.key);
      expect(
        (parsed as InvalidLogFormat).errors,
        contains(entry.value),
        reason: entry.key,
      );
    }
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
