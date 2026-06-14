sealed class SetNotation {
  const SetNotation();

  String render();
}

class LoggedSet extends SetNotation {
  const LoggedSet({
    required this.result,
    required this.rpe,
    this.pain,
    this.note,
  });

  final SetResult result;
  final String rpe;
  final String? pain;
  final String? note;

  @override
  String render() {
    final core = '${result.render()}@$rpe${pain == null ? '' : ',$pain'}';
    return note == null ? core : '$core; $note';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LoggedSet &&
            result == other.result &&
            rpe == other.rpe &&
            pain == other.pain &&
            note == other.note;
  }

  @override
  int get hashCode => Object.hash(result, rpe, pain, note);

  @override
  String toString() {
    return 'LoggedSet(result: $result, rpe: $rpe, pain: $pain, note: $note)';
  }
}

class RawSetNotation extends SetNotation {
  const RawSetNotation(this.text);

  final String text;

  @override
  String render() => text;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RawSetNotation && text == other.text;
  }

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'RawSetNotation($text)';
}

sealed class SetResult {
  const SetResult();

  String render();
}

class WeightedReps extends SetResult {
  const WeightedReps({required this.weight, required this.reps});

  final String weight;
  final String reps;

  @override
  String render() => '${weight}x$reps';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WeightedReps && weight == other.weight && reps == other.reps;
  }

  @override
  int get hashCode => Object.hash(weight, reps);

  @override
  String toString() => 'WeightedReps(weight: $weight, reps: $reps)';
}

class BodyweightReps extends SetResult {
  const BodyweightReps({required this.reps});

  final String reps;

  @override
  String render() => reps;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BodyweightReps && reps == other.reps;
  }

  @override
  int get hashCode => reps.hashCode;

  @override
  String toString() => 'BodyweightReps(reps: $reps)';
}

class TimedSet extends SetResult {
  const TimedSet({required this.seconds});

  final String seconds;

  @override
  String render() => '${seconds}s';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TimedSet && seconds == other.seconds;
  }

  @override
  int get hashCode => seconds.hashCode;

  @override
  String toString() => 'TimedSet(seconds: $seconds)';
}

class HeightReps extends SetResult {
  const HeightReps({
    required this.height,
    required this.unit,
    required this.reps,
  });

  final String height;
  final String unit;
  final String reps;

  @override
  String render() => '$height${unit}x$reps';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HeightReps &&
            height == other.height &&
            unit == other.unit &&
            reps == other.reps;
  }

  @override
  int get hashCode => Object.hash(height, unit, reps);

  @override
  String toString() {
    return 'HeightReps(height: $height, unit: $unit, reps: $reps)';
  }
}

SetNotation parseSetNotation(String text) {
  final semicolonIndex = text.indexOf(';');
  final coreText = semicolonIndex == -1
      ? text
      : text.substring(0, semicolonIndex);
  final note = semicolonIndex == -1
      ? null
      : text.substring(semicolonIndex + 1).trim();

  final height = RegExp(
    r'^(\d+(?:\.\d+)?)(in|cm)x(\d+)@(\d+(?:\.\d+)?)(?:,(\d+))?$',
  ).firstMatch(coreText);
  if (height != null) {
    return LoggedSet(
      result: HeightReps(
        height: height[1]!,
        unit: height[2]!,
        reps: height[3]!,
      ),
      rpe: height[4]!,
      pain: height[5],
      note: note,
    );
  }

  final weighted = RegExp(
    r'^(\d+(?:\.\d+)?)x(\d+)@(\d+(?:\.\d+)?)(?:,(\d+))?$',
  ).firstMatch(coreText);
  if (weighted != null) {
    return LoggedSet(
      result: WeightedReps(weight: weighted[1]!, reps: weighted[2]!),
      rpe: weighted[3]!,
      pain: weighted[4],
      note: note,
    );
  }

  final bodyweight = RegExp(
    r'^(\d+)@(\d+(?:\.\d+)?)(?:,(\d+))?$',
  ).firstMatch(coreText);
  if (bodyweight != null) {
    return LoggedSet(
      result: BodyweightReps(reps: bodyweight[1]!),
      rpe: bodyweight[2]!,
      pain: bodyweight[3],
      note: note,
    );
  }

  final timed = RegExp(
    r'^(\d+(?:\.\d+)?)s@(\d+(?:\.\d+)?)(?:,(\d+))?$',
  ).firstMatch(coreText);
  if (timed != null) {
    return LoggedSet(
      result: TimedSet(seconds: timed[1]!),
      rpe: timed[2]!,
      pain: timed[3],
      note: note,
    );
  }

  return RawSetNotation(text);
}

String renderSetNotation(SetNotation set) => set.render();
