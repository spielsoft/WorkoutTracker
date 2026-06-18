part of 'workout_tracker_shell.dart';

class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({
    required this.report,
    this.onRepairUnambiguousFormulaIssues,
  });

  final SpreadsheetValidationReport report;
  final Future<void> Function()? onRepairUnambiguousFormulaIssues;

  @override
  Widget build(BuildContext context) {
    final unambiguousFormulaIssues = report.formulaHealingIssues.where(
      (issue) => !issue.requiresUserSelection,
    );
    final panels = <Widget>[
      if (report.hasBlockingSchemaViolations)
        _IssuePanel(
          icon: Icons.report_problem_outlined,
          title: 'Sheet contract issues',
          lines: report.schemaViolations.map(_schemaViolationLine).toList(),
          tone: _IssueTone.error,
        ),
      if (report.formulaHealingIssues.isNotEmpty)
        _IssuePanel(
          icon: Icons.build_outlined,
          title: 'Formula repair needed',
          lines: report.formulaHealingIssues
              .expand(_formulaHealingIssueLines)
              .toList(),
          action: unambiguousFormulaIssues.isEmpty
              ? null
              : FilledButton.icon(
                  key: const ValueKey('repair-unambiguous-formulas'),
                  onPressed: onRepairUnambiguousFormulaIssues == null
                      ? null
                      : () => unawaited(onRepairUnambiguousFormulaIssues!()),
                  icon: const Icon(Icons.build_circle_outlined),
                  label: const Text('Repair unambiguous formulas'),
                ),
          tone: _IssueTone.warning,
        ),
    ];

    if (panels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < panels.length; index += 1) ...[
          if (index > 0) const SizedBox(height: 12),
          panels[index],
        ],
      ],
    );
  }
}

String _schemaViolationLine(SchemaViolation violation) {
  return 'Row ${violation.sheetRowNumber}, ${violation.workout}: '
      '${violation.message}';
}

Iterable<String> _formulaHealingIssueLines(FormulaHealingIssue issue) sync* {
  final selection = issue.requiresUserSelection
      ? 'requires exercise selection'
      : 'preselects Exercises row ${issue.preselectedExerciseSheetRowNumber}';
  yield 'Row ${issue.activeSheetRowNumber}, ${issue.displayedExerciseName}: '
      '$selection.';
  for (final cell in issue.cells) {
    yield '${cell.columnName}: ${_formulaReasonLabel(cell.reason)}';
  }
}

String _formulaReasonLabel(FormulaHealingIssueReason reason) {
  switch (reason) {
    case FormulaHealingIssueReason.missingFormula:
      return 'missing formula';
    case FormulaHealingIssueReason.brokenFormula:
      return 'broken formula';
  }
}

enum _IssueTone { error, warning }

class _IssuePanel extends StatelessWidget {
  const _IssuePanel({
    required this.icon,
    required this.title,
    required this.lines,
    required this.tone,
    this.action,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final _IssueTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForTone(Theme.of(context).colorScheme, tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.foreground),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line),
              ),
            if (action != null) ...[
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerLeft, child: action),
            ],
          ],
        ),
      ),
    );
  }
}

({Color background, Color border, Color foreground}) _colorsForTone(
  ColorScheme colorScheme,
  _IssueTone tone,
) {
  switch (tone) {
    case _IssueTone.error:
      return (
        background: colorScheme.errorContainer,
        border: colorScheme.error.withValues(alpha: 0.5),
        foreground: colorScheme.onErrorContainer,
      );
    case _IssueTone.warning:
      return (
        background: const Color(0xFFFFF6D6),
        border: const Color(0xFFB28A00),
        foreground: const Color(0xFF5F4600),
      );
  }
}
