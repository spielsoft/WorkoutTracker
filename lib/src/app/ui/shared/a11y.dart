import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class A11yScreen extends StatelessWidget {
  const A11yScreen({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label,
      child: child,
    );
  }
}

class A11yHeader extends StatelessWidget {
  const A11yHeader({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(header: true, label: label, child: child);
  }
}

class A11yTextField extends StatelessWidget {
  const A11yTextField({
    required this.label,
    required this.child,
    this.identifier,
    this.valueListenable,
    this.hint,
    super.key,
  });

  final String label;
  final String? identifier;
  final String? hint;
  final ValueListenable<TextEditingValue>? valueListenable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final values = valueListenable;
    if (values == null) {
      return _build(value: null);
    }
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: values,
      builder: (context, value, child) => _build(
        value: value.text.trim().isEmpty ? null : value.text,
        child: child,
      ),
      child: child,
    );
  }

  Widget _build({required String? value, Widget? child}) {
    return Semantics(
      identifier: identifier,
      textField: true,
      label: label,
      value: value,
      hint: hint,
      child: child ?? this.child,
    );
  }
}

class A11yStatus extends StatelessWidget {
  const A11yStatus({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(container: true, label: label, child: child);
  }
}
