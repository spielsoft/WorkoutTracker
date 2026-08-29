import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/shared/a11y.dart';

const _tick = Duration(seconds: 1);
const _extra = Duration(seconds: 30);

/// Requests the platform's full alert vibration once a countdown expires.
typedef CountdownSignal = Future<void> Function();

/// Reports how long a countdown actually ran once it ends.
typedef CountdownEnd = void Function(Duration elapsed);

/// One countdown and the policy that owns it.
///
/// Callers supply the policy explicitly so rest and exercise timing can share
/// the countdown mechanics without sharing each other's behavior.
@immutable
final class Countdown {
  const Countdown({
    required this.heading,
    required this.duration,
    this.modal = false,
    this.onEnd,
  });

  /// Full-width heading shown above the controls, such as `REST` or a
  /// complete exercise name.
  final String heading;

  /// Exact length of the countdown. Fractional seconds are honored.
  final Duration duration;

  /// Whether this countdown locks the rest of the app while it runs.
  ///
  /// A modal countdown stays locked while paused and releases the app only
  /// when it expires or the athlete presses Done.
  final bool modal;

  /// Called with the time actually counted down when Done or expiry ends this
  /// countdown. A countdown replaced by a newer one never reports.
  final CountdownEnd? onEnd;
}

/// The single global countdown: an exact deadline, pause and resume, added
/// time, lifecycle correction, Done, and one completion signal.
final class CountdownCtrl extends ChangeNotifier with WidgetsBindingObserver {
  CountdownCtrl({DateTime Function()? now, CountdownSignal? signal})
    : _now = now ?? _ambientNow,
      _signal = signal ?? _vibrate {
    WidgetsBinding.instance.addObserver(this);
  }

  final DateTime Function() _now;
  final CountdownSignal _signal;
  Timer? _ticker;
  Countdown? _countdown;
  DateTime? _deadline;
  Duration _held = Duration.zero;
  Duration _total = Duration.zero;
  bool _paused = false;

  bool get active => _countdown != null;

  bool get paused => _paused;

  /// Whether a countdown is running that locks the rest of the app.
  bool get modal => _countdown?.modal ?? false;

  String get heading => _countdown?.heading ?? '';

  /// Exact time left, measured against the deadline rather than accumulated
  /// from whole ticks, so suspension cannot lose a fraction of a second.
  Duration get remaining {
    if (!active) return Duration.zero;
    if (_paused) return _held;
    final left = _deadline!.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Remaining time as ordinary nearest-integer seconds, for display.
  int get seconds {
    return (remaining.inMicroseconds / Duration.microsecondsPerSecond).round();
  }

  /// Replaces any running countdown. The replaced countdown can no longer
  /// report its elapsed time or signal.
  void start(Countdown countdown) {
    _clear();
    if (countdown.duration <= Duration.zero) {
      notifyListeners();
      return;
    }
    _countdown = countdown;
    _total = countdown.duration;
    _deadline = _now().add(countdown.duration);
    _schedule();
    notifyListeners();
  }

  void toggle() {
    if (!active) return;
    if (_paused) {
      _paused = false;
      _deadline = _now().add(_held);
      _held = Duration.zero;
      _schedule();
    } else {
      _held = remaining;
      _paused = true;
      _ticker?.cancel();
    }
    notifyListeners();
  }

  void addTime() {
    if (!active) return;
    _total += _extra;
    if (_paused) {
      _held += _extra;
    } else {
      _deadline = _deadline!.add(_extra);
      _schedule();
    }
    notifyListeners();
  }

  void done() {
    if (!active) return;
    _end(signal: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!active || _paused) return;
    if (state == AppLifecycleState.resumed) {
      // The deadline is absolute, so resuming only reschedules the ticker and
      // expires immediately when the deadline already passed. Notifying
      // refreshes a display that could not tick while the app was away.
      _schedule();
      if (active) notifyListeners();
      return;
    }
    _ticker?.cancel();
  }

  void _schedule() {
    _ticker?.cancel();
    final left = remaining;
    if (left <= Duration.zero) {
      _end(signal: true);
      return;
    }
    _ticker = left <= _tick
        ? Timer(left, () => _end(signal: true))
        : Timer(_tick, _onTick);
  }

  void _onTick() {
    notifyListeners();
    _schedule();
  }

  void _end({required bool signal}) {
    final ended = _countdown;
    final ran = _total - remaining;
    _clear();
    notifyListeners();
    ended?.onEnd?.call(ran);
    if (signal) unawaited(_emitSignal());
  }

  void _clear() {
    _ticker?.cancel();
    _ticker = null;
    _countdown = null;
    _deadline = null;
    _held = Duration.zero;
    _total = Duration.zero;
    _paused = false;
  }

  Future<void> _emitSignal() async {
    try {
      await _signal();
    } on MissingPluginException {
      // Keep the countdown usable when the platform haptic channel is absent.
    } on PlatformException {
      // Keep the countdown usable when the platform haptic channel is absent.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }
}

DateTime _ambientNow() => clock.now();

Future<void> _vibrate() => HapticFeedback.vibrate();

/// The global countdown bar: a full-width heading above symmetric controls.
class CountdownBar extends StatelessWidget {
  const CountdownBar({required this.ctrl, super.key});

  final CountdownCtrl ctrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      key: const ValueKey('countdown-bar'),
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            A11yHeader(
              key: const ValueKey('countdown-heading'),
              label: ctrl.heading,
              child: ExcludeSemantics(
                child: Text(
                  ctrl.heading,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      key: const ValueKey('countdown-add'),
                      onPressed: ctrl.addTime,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.onTertiaryContainer,
                        side: BorderSide(color: colors.tertiary),
                      ),
                      child: const Text('+30 s'),
                    ),
                  ),
                ),
                Semantics(
                  key: const ValueKey('countdown-toggle'),
                  container: true,
                  explicitChildNodes: true,
                  excludeSemantics: true,
                  label:
                      '${ctrl.paused ? 'Resume' : 'Pause'} ${ctrl.heading} '
                      'timer, ${ctrl.seconds} seconds remaining',
                  button: true,
                  toggled: ctrl.paused,
                  onTap: ctrl.toggle,
                  child: TextButton(
                    onPressed: ctrl.toggle,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onTertiaryContainer,
                      backgroundColor: ctrl.paused
                          ? colors.onTertiaryContainer.withValues(alpha: 0.12)
                          : null,
                      minimumSize: const Size(88, 56),
                    ),
                    child: Text(
                      '${ctrl.seconds}',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: colors.onTertiaryContainer,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      key: const ValueKey('countdown-done'),
                      onPressed: ctrl.done,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.tertiary,
                        foregroundColor: colors.onTertiary,
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
