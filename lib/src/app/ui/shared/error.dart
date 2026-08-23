import 'package:flutter/material.dart';

import 'status.dart';

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    required this.message,
    required this.onDismiss,
    super.key,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final content = _content(message);
    final semantics = [content.title, ...content.details].join('. ');
    return Semantics(
      key: const ValueKey('error-banner'),
      container: true,
      button: true,
      label: 'Dismiss error',
      value: semantics,
      onTap: onDismiss,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: StCallout(
              state: VisualSt.error,
              icon: Icons.error_outline,
              title: content.title,
              children: [for (final detail in content.details) Text(detail)],
            ),
          ),
        ),
      ),
    );
  }
}

({String title, List<String> details}) _content(String message) {
  final duplicate = RegExp(
    r'^History block (.+) already exists\.$',
  ).firstMatch(message.trim());
  if (duplicate != null) {
    return (
      title: 'History block already exists',
      details: ['${duplicate.group(1)} already exists.'],
    );
  }

  final separator = message.indexOf(': ');
  if (separator > 0 && separator < message.length - 2) {
    return (
      title: message.substring(0, separator),
      details: [message.substring(separator + 2)],
    );
  }
  return (title: message, details: const []);
}
