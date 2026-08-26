import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const _idleTimeout = Duration(minutes: 10);

typedef AwakeSetter = Future<void> Function(bool enabled);

class IdleAwake extends StatefulWidget {
  const IdleAwake({
    required this.child,
    this.setAwake = _setAwake,
    this.timeout = _idleTimeout,
    super.key,
  });

  final Widget child;
  final AwakeSetter setAwake;
  final Duration timeout;

  @override
  State<IdleAwake> createState() => _IdleAwakeSt();
}

class _IdleAwakeSt extends State<IdleAwake> with WidgetsBindingObserver {
  Timer? _timer;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _renew();
  }

  @override
  void didUpdateWidget(IdleAwake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeout != widget.timeout) _renew();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _renew();
        break;
      case AppLifecycleState.inactive ||
          AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        _release();
        break;
    }
  }

  void _renew() {
    _timer?.cancel();
    _apply(true);
    _timer = Timer(widget.timeout, _release);
  }

  void _release() {
    _timer?.cancel();
    _timer = null;
    _apply(false);
  }

  void _apply(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    unawaited(_send(enabled));
  }

  Future<void> _send(bool enabled) async {
    try {
      await widget.setAwake(enabled);
    } on MissingPluginException {
      // Keep workout entry usable if the platform wake-lock channel is absent.
    } on PlatformException {
      // Keep workout entry usable if the platform wake-lock channel is absent.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _renew(),
      onPointerSignal: (_) => _renew(),
      child: Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent) _renew();
          return KeyEventResult.ignored;
        },
        child: widget.child,
      ),
    );
  }
}

Future<void> _setAwake(bool enabled) {
  return enabled ? WakelockPlus.enable() : WakelockPlus.disable();
}
