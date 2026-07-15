import 'package:flutter/material.dart';

class NextFieldButton extends StatelessWidget {
  const NextFieldButton({
    required this.focusNode,
    required this.nextLabel,
    super.key,
  });

  final FocusNode focusNode;
  final String nextLabel;

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
            onTap: focusNode.nextFocus,
            child: ExcludeSemantics(
              child: ExcludeFocus(
                child: IconButton(
                  onPressed: focusNode.nextFocus,
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
