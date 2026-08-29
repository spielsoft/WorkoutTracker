import 'countdown.dart';

/// Seconds beyond which an exact microsecond deadline is unrepresentable.
const _maxTimerSeconds = 9.2e12;

/// Reads a timed set field's current text as an exact countdown duration.
///
/// Only a positive finite number of seconds can start a countdown. Blank,
/// zero, negative, nonfinite, out-of-range, and otherwise nonnumeric text
/// returns null so an unusable prescription fails safely instead of starting
/// a meaningless timer. Fractional seconds are kept exactly.
Duration? timerDuration(String value) {
  final seconds = double.tryParse(value.trim());
  if (seconds == null || !seconds.isFinite) return null;
  if (seconds <= 0 || seconds > _maxTimerSeconds) return null;
  final micros = (seconds * Duration.microsecondsPerSecond).round();
  return micros <= 0 ? null : Duration(microseconds: micros);
}

/// Exercise policy for the shared countdown: headed by the full exercise
/// name, modal, and reporting its measured duration back to the field that
/// started it.
Countdown exerciseCountdown({
  required String exercise,
  required Duration duration,
  CountdownEnd? onEnd,
}) {
  return Countdown(
    heading: exercise,
    duration: duration,
    modal: true,
    onEnd: onEnd,
  );
}
