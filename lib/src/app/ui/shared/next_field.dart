import 'package:flutter/material.dart';

class NextFieldButton extends StatelessWidget {
  const NextFieldButton({
    required this.focusNode,
    required this.nextLabel,
    this.onNext,
    super.key,
  });

  final FocusNode focusNode;
  final String nextLabel;

  /// Moves focus to [nextLabel] when plain traversal would land elsewhere.
  final VoidCallback? onNext;

  void _advance() {
    final next = onNext;
    if (next != null) {
      next();
      return;
    }
    focusNode.nextFocus();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        if (!focusNode.hasFocus) return const SizedBox.shrink();
        final label = 'Next field $nextLabel';
        return Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: Semantics(
            container: true,
            label: label,
            button: true,
            onTap: _advance,
            child: ExcludeSemantics(
              child: ExcludeFocus(
                child: IconButton(
                  onPressed: _advance,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
