import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _tick = Duration(seconds: 1);
const _extra = Duration(seconds: 30);

typedef RestSignal = Future<void> Function();

Duration? restDuration(String value) {
  final text = value.trim().toLowerCase();
  final clock = RegExp(r'^(\d+):(\d{1,2})$').firstMatch(text);
  if (clock != null) {
    final minutes = int.parse(clock.group(1)!);
    final seconds = int.parse(clock.group(2)!);
    if (seconds >= 60) return null;
    return _positiveDuration(minutes * 60 + seconds);
  }

  final match = RegExp(
    r'^(\d+(?:\.\d+)?)\s*(s|sec|secs|second|seconds|m|min|mins|minute|minutes)$',
  ).firstMatch(text);
  if (match == null) return null;
  final amount = double.parse(match.group(1)!);
  final unit = match.group(2)!;
  final multiplier = unit.startsWith('s') ? 1 : 60;
  return _positiveDuration((amount * multiplier).round());
}

Duration? _positiveDuration(int seconds) {
  return seconds <= 0 ? null : Duration(seconds: seconds);
}

final class RestCtrl extends ChangeNotifier with WidgetsBindingObserver {
  RestCtrl({DateTime Function()? now, RestSignal? signal})
    : _now = now ?? DateTime.now,
      _signal = signal ?? _signalRest {
    WidgetsBinding.instance.addObserver(this);
  }

  final DateTime Function() _now;
  final RestSignal _signal;
  Timer? _ticker;
  DateTime? _inactiveAt;
  int _seconds = 0;
  bool _paused = false;

  bool get active => _seconds > 0;
  bool get paused => _paused;
  int get seconds => _seconds;

  void start(Duration duration) {
    _ticker?.cancel();
    _seconds = duration.inSeconds;
    _paused = false;
    _inactiveAt = null;
    if (!active) {
      notifyListeners();
      return;
    }
    _startTicker();
    notifyListeners();
  }

  void toggle() {
    if (!active) return;
    _paused = !_paused;
    if (_paused) {
      _ticker?.cancel();
    } else {
      _startTicker();
    }
    notifyListeners();
  }

  void addTime() {
    if (!active) return;
    _seconds += _extra.inSeconds;
    notifyListeners();
  }

  void done() {
    if (!active) return;
    _finish();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
      return;
    }
    if (!active || _paused || _inactiveAt != null) return;
    _inactiveAt = _now();
    _ticker?.cancel();
  }

  void _resume() {
    final inactiveAt = _inactiveAt;
    if (inactiveAt == null || !active || _paused) return;
    _inactiveAt = null;
    _seconds -= _now().difference(inactiveAt).inSeconds;
    if (_seconds <= 0) {
      _finish(signal: true);
      return;
    }
    _startTicker();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) {
      if (_paused || !active) return;
      _seconds -= 1;
      if (_seconds <= 0) {
        _finish(signal: true);
      } else {
        notifyListeners();
      }
    });
  }

  void _finish({bool signal = false}) {
    _ticker?.cancel();
    _seconds = 0;
    _paused = false;
    _inactiveAt = null;
    notifyListeners();
    if (signal) unawaited(_emitSignal());
  }

  Future<void> _emitSignal() async {
    try {
      await _signal();
    } catch (_) {
      // Keep the timer usable when the platform haptic channel is absent.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }
}

Future<void> _signalRest() => HapticFeedback.mediumImpact();

class RestBar extends StatelessWidget {
  const RestBar({required this.ctrl, super.key});

  final RestCtrl ctrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('rest-timer'),
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  key: const ValueKey('rest-add'),
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
              key: const ValueKey('rest-countdown'),
              container: true,
              explicitChildNodes: true,
              excludeSemantics: true,
              label:
                  '${ctrl.paused ? 'Resume' : 'Pause'} timer, '
                  '${ctrl.seconds} seconds remaining',
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
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
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
                  key: const ValueKey('rest-done'),
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
      ),
    );
  }
}
