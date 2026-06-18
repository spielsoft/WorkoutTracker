part of 'workout_tracker_shell.dart';

class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({
    required this.report,
    this.onRepairUnambiguousFormulaIssues,
    this.onRepairFormulaIssue,
    this.onOpenSpreadsheet,
  });

  final SpreadsheetValidationReport report;
  final Future<void> Function()? onRepairUnambiguousFormulaIssues;
  final Future<void> Function({
    required int activeSheetRowNumber,
    required int selectedExerciseSheetRowNumber,
  })?
  onRepairFormulaIssue;
  final Future<void> Function()? onOpenSpreadsheet;

  @override
  Widget build(BuildContext context) {
    final unambiguousFormulaIssues = report.formulaHealingIssues
        .where((issue) => !issue.requiresUserSelection)
        .toList();
    final choiceFormulaIssues = report.formulaHealingIssues.where(
      (issue) => issue.requiresUserSelection,
    );
    final panels = <Widget>[
      if (report.hasBlockingSchemaViolations)
        _IssuePanel(
          icon: Icons.report_problem_outlined,
          title: 'Manual repair needed',
          lines: report.manualRepairItems
              .map((item) => item.displayText)
              .toList(),
          action: FilledButton.icon(
            key: const ValueKey('open-spreadsheet-manual-repair'),
            onPressed: onOpenSpreadsheet == null
                ? null
                : () => unawaited(onOpenSpreadsheet!()),
            icon: const Icon(Icons.open_in_new_outlined),
            label: const Text('Open in Google Sheets'),
          ),
          tone: _IssueTone.error,
        ),
      if (!report.hasBlockingSchemaViolations &&
          report.formulaHealingIssues.isNotEmpty)
        _IssuePanel(
          icon: Icons.build_outlined,
          title: 'Formula repair needed',
          lines: unambiguousFormulaIssues
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
          extraContent: [
            for (final issue in choiceFormulaIssues)
              _FormulaChoiceRepairItem(
                key: ValueKey(
                  'formula-repair-item-${issue.activeSheetRowNumber}',
                ),
                issue: issue,
                onRepairFormulaIssue: onRepairFormulaIssue,
              ),
          ],
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

class _FormulaChoiceRepairItem extends StatefulWidget {
  const _FormulaChoiceRepairItem({
    super.key,
    required this.issue,
    this.onRepairFormulaIssue,
  });

  final FormulaHealingIssue issue;
  final Future<void> Function({
    required int activeSheetRowNumber,
    required int selectedExerciseSheetRowNumber,
  })?
  onRepairFormulaIssue;

  @override
  State<_FormulaChoiceRepairItem> createState() {
    return _FormulaChoiceRepairItemState();
  }
}

class _FormulaChoiceRepairItemState extends State<_FormulaChoiceRepairItem> {
  int? _selectedExerciseSheetRowNumber;

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFB28A00)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Row ${issue.activeSheetRowNumber}, '
                '${issue.displayedExerciseName}: choose the Exercises row to use.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final cell in issue.cells)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${cell.columnName}: ${_formulaReasonLabel(cell.reason)}',
                  ),
                ),
              const SizedBox(height: 8),
              DropdownMenu<int>(
                key: ValueKey(
                  'formula-repair-picker-${issue.activeSheetRowNumber}',
                ),
                expandedInsets: EdgeInsets.zero,
                enableFilter: true,
                enableSearch: true,
                label: const Text('Exercises row'),
                dropdownMenuEntries: [
                  for (final choice in issue.exerciseChoices)
                    DropdownMenuEntry<int>(
                      value: choice.sheetRowNumber,
                      label: choice.label,
                    ),
                ],
                onSelected: (value) {
                  setState(() {
                    _selectedExerciseSheetRowNumber = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: ValueKey(
                  'repair-formula-row-${issue.activeSheetRowNumber}',
                ),
                onPressed:
                    _selectedExerciseSheetRowNumber == null ||
                        widget.onRepairFormulaIssue == null
                    ? null
                    : () => unawaited(
                        widget.onRepairFormulaIssue!(
                          activeSheetRowNumber: issue.activeSheetRowNumber,
                          selectedExerciseSheetRowNumber:
                              _selectedExerciseSheetRowNumber!,
                        ),
                      ),
                icon: const Icon(Icons.build_circle_outlined),
                label: const Text('Repair selected row'),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    this.extraContent = const [],
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final _IssueTone tone;
  final Widget? action;
  final List<Widget> extraContent;

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
            ...extraContent,
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
