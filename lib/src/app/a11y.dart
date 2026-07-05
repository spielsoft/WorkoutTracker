part of 'shell.dart';

class _A11yScreen extends StatelessWidget {
  const _A11yScreen({required this.label, required this.child});

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

class _A11yHeader extends StatelessWidget {
  const _A11yHeader({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(header: true, label: label, child: child);
  }
}

class _A11yTextField extends StatelessWidget {
  const _A11yTextField({
    required this.label,
    required this.child,
    this.identifier,
    this.valueListenable,
    this.hint,
  });

  final String label;
  final String? identifier;
  final String? hint;
  final ValueListenable<TextEditingValue>? valueListenable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final valueListenable = this.valueListenable;
    if (valueListenable == null) {
      return _build(value: null);
    }
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: valueListenable,
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

class _A11yStatus extends StatelessWidget {
  const _A11yStatus({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(container: true, label: label, child: child);
  }
}
