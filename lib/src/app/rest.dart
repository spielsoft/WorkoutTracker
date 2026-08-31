import 'countdown.dart';

const _restHeading = 'REST';

/// Reads a workbook Rest cell such as `90`, `90s`, `1.5 min`, or `1:30`.
Duration? restDuration(String value) {
  final text = value.trim().toLowerCase();
  final minuteSecond = RegExp(r'^(\d+):(\d{1,2})$').firstMatch(text);
  if (minuteSecond != null) {
    final minutes = int.parse(minuteSecond.group(1)!);
    final seconds = int.parse(minuteSecond.group(2)!);
    if (seconds >= 60) return null;
    return _positiveDuration(minutes * 60 + seconds);
  }

  final match = RegExp(
    r'^(\d+(?:\.\d+)?)\s*(s|sec|secs|second|seconds|m|min|mins|minute|minutes)?$',
  ).firstMatch(text);
  if (match == null) return null;
  final amount = double.parse(match.group(1)!);
  final unit = match.group(2);
  final multiplier = unit == null || unit.startsWith('s') ? 1 : 60;
  return _positiveDuration((amount * multiplier).round());
}

Duration? _positiveDuration(int seconds) {
  return seconds <= 0 ? null : Duration(seconds: seconds);
}

/// Rest policy for the shared countdown: labeled `REST`, nonmodal, and
/// recording nothing when it ends.
Countdown restCountdown(Duration duration) {
  return Countdown(heading: _restHeading, duration: duration);
}
