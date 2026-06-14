import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/set_notation.dart';

void main() {
  test('parses and renders weighted reps', () {
    final set = parseSetNotation('150x10@8');

    expect(
      set,
      LoggedSet(
        result: WeightedReps(weight: '150', reps: '10'),
        rpe: '8',
      ),
    );
    expect(renderSetNotation(set), '150x10@8');
  });

  test('parses and renders optional pain', () {
    final set = parseSetNotation('150x10@8,1');

    expect(
      set,
      LoggedSet(
        result: WeightedReps(weight: '150', reps: '10'),
        rpe: '8',
        pain: '1',
      ),
    );
    expect(renderSetNotation(set), '150x10@8,1');
  });

  test('parses and renders bodyweight reps', () {
    final set = parseSetNotation('15@8');

    expect(
      set,
      LoggedSet(
        result: BodyweightReps(reps: '15'),
        rpe: '8',
      ),
    );
    expect(renderSetNotation(set), '15@8');
  });

  test('parses and renders timed entries', () {
    final set = parseSetNotation('45s@8');

    expect(
      set,
      LoggedSet(
        result: TimedSet(seconds: '45'),
        rpe: '8',
      ),
    );
    expect(renderSetNotation(set), '45s@8');
  });

  test('parses and renders height reps with explicit units', () {
    final set = parseSetNotation('24inx10@8');

    expect(
      set,
      LoggedSet(
        result: HeightReps(height: '24', unit: 'in', reps: '10'),
        rpe: '8',
      ),
    );
    expect(renderSetNotation(set), '24inx10@8');
  });

  test('preserves optional notes after a semicolon', () {
    final set = parseSetNotation('150x10@8,1; felt fast');

    expect(
      set,
      LoggedSet(
        result: WeightedReps(weight: '150', reps: '10'),
        rpe: '8',
        pain: '1',
        note: 'felt fast',
      ),
    );
    expect(renderSetNotation(set), '150x10@8,1; felt fast');
  });

  test('preserves unparseable cells as raw text', () {
    final set = parseSetNotation('worked up, knee felt odd');

    expect(set, RawSetNotation('worked up, knee felt odd'));
    expect(renderSetNotation(set), 'worked up, knee felt odd');
  });
}
