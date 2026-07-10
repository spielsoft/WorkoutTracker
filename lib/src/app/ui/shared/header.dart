import 'package:flutter/material.dart';

import 'a11y.dart';

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    required this.title,
    required this.backTooltip,
    required this.onBack,
    this.subtitle,
    this.compactTitle = false,
    this.trailing,
    super.key,
  });

  final String title;
  final String backTooltip;
  final VoidCallback onBack;
  final String? subtitle;
  final bool compactTitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final subtitle = this.subtitle;
    return Row(
      children: [
        IconButton(
          tooltip: backTooltip,
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_outlined),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              A11yHeader(
                label: subtitle == null ? title : '$title, $subtitle',
                child: Text(
                  title,
                  key: compactTitle
                      ? const ValueKey('current-workout-sheet-label')
                      : null,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: compactTitle
                      ? Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        )
                      : Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}
