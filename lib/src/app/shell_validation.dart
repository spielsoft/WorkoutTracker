part of 'shell.dart';

class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({
    required this.report,
    this.onRepairUnambiguousFormulaIssues,
    this.onRepairFormulaIssue,
    this.onOpenSpreadsheet,
  });

  final ValidationReport report;
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
          title: 'Fix the active sheet structure',
          lines: [
            'Open Google Sheets to repair rows or headers before logging.',
            'Spreadsheet details',
            for (final item in report.manualRepairItems)
              _manualRepairItemLine(item),
          ],
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
          title: 'Reconnect exercises to logging rows',
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

String _manualRepairItemLine(ManualRepairItem item) {
  return 'Active sheet row ${item.sheetRowNumber}: ${item.problem}';
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
    final warningStyle = _stateStyle(
      Theme.of(context).colorScheme,
      _WorkoutVisualState.warning,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: warningStyle.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose the exercise for ${issue.displayedExerciseName}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select the Exercises entry that this logging row should use.',
              ),
              const SizedBox(height: 8),
              Text(
                'Spreadsheet details',
                style: _diagnosticLabelStyle(context),
              ),
              const SizedBox(height: 4),
              Text(
                'Active sheet row ${issue.activeSheetRowNumber}.',
                style: _diagnosticTextStyle(context),
              ),
              for (final cell in issue.cells)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${cell.columnName}: ${_formulaReasonLabel(cell.reason)}',
                    style: _diagnosticTextStyle(context),
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
                label: const Text('Exercise to reconnect'),
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
                label: Text('Repair ${issue.displayedExerciseName}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Iterable<String> _formulaHealingIssueLines(FormulaHealingIssue issue) sync* {
  yield 'Repair formula cells so each workout row points to the correct '
      'Exercises entry.';
  yield '${issue.displayedExerciseName} can be reconnected automatically.';
  yield 'Spreadsheet details';
  final selectedRow = issue.preselectedExerciseSheetRowNumber;
  if (selectedRow == null) {
    yield 'Active sheet row ${issue.activeSheetRowNumber}; '
        'needs an Exercises row selection.';
  } else {
    yield 'Active sheet row ${issue.activeSheetRowNumber}; '
        'will use Exercises row $selectedRow.';
  }
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
    var isDiagnostic = false;
    final issueLines = <Widget>[];
    for (final line in lines) {
      if (line == 'Spreadsheet details') {
        isDiagnostic = true;
        issueLines.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(line, style: _diagnosticLabelStyle(context)),
          ),
        );
      } else {
        issueLines.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              line,
              style: isDiagnostic ? _diagnosticTextStyle(context) : null,
            ),
          ),
        );
      }
    }

    return _StateCallout(
      state: switch (tone) {
        _IssueTone.error => _WorkoutVisualState.error,
        _IssueTone.warning => _WorkoutVisualState.warning,
      },
      icon: icon,
      title: title,
      action: action,
      children: [...issueLines, ...extraContent],
    );
  }
}

TextStyle? _diagnosticLabelStyle(BuildContext context) {
  return Theme.of(context).textTheme.labelMedium?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    fontWeight: FontWeight.w700,
  );
}

TextStyle? _diagnosticTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}
