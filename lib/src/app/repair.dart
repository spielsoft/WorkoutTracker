import 'dart:async';

import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/migration.dart';

import 'validation.dart';
import 'ui/shared/status.dart';

class ValidationSummary extends StatelessWidget {
  const ValidationSummary({
    required this.report,
    this.onRepairFormulas,
    this.onRepairFormulaIssue,
    this.onOpenSpreadsheet,
    this.migration,
    this.onMigrate,
    super.key,
  });

  final ValReport report;
  final Future<void> Function()? onRepairFormulas;
  final Future<void> Function({
    required int activeSheetRowNumber,
    required int selectedRow,
  })?
  onRepairFormulaIssue;
  final Future<void> Function()? onOpenSpreadsheet;
  final WbkMigrationReport? migration;
  final Future<void> Function()? onMigrate;

  @override
  Widget build(BuildContext context) {
    final unambiguousFormulaIssues = report.healingIssues
        .where((issue) => !issue.needsChoice)
        .toList();
    final choiceFormulaIssues = report.healingIssues.where(
      (issue) => issue.needsChoice,
    );
    final panels = <Widget>[
      if (migration case final migration?)
        IssuePanel(
          icon: Icons.upgrade_outlined,
          title: _migrationTitle(migration),
          lines: [
            if (migration.canApply)
              migration.kind == WbkMigrationKind.format09
                  ? 'This declared 0.9 sheet uses older bracket-token Log Formats.'
                  : 'This sheet uses an older WorkoutTracker column layout.',
            ...migration.changes,
            if (migration.blockers.isNotEmpty) 'Spreadsheet details',
            ...migration.blockers,
          ],
          action: migration.canApply
              ? FilledButton.icon(
                  key: ValueKey(
                    migration.kind == WbkMigrationKind.format09
                        ? 'convert-format-sheet'
                        : 'convert-legacy-sheet',
                  ),
                  onPressed: onMigrate == null
                      ? null
                      : () => unawaited(onMigrate!()),
                  icon: const Icon(Icons.upgrade_outlined),
                  label: Text(
                    migration.kind == WbkMigrationKind.format09
                        ? 'Update formats'
                        : 'Convert old sheet',
                  ),
                )
              : FilledButton.icon(
                  key: const ValueKey('open-legacy-sheet'),
                  onPressed: onOpenSpreadsheet == null
                      ? null
                      : () => unawaited(onOpenSpreadsheet!()),
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('Open in Google Sheets'),
                ),
          tone: migration.canApply ? IssueTone.warning : IssueTone.error,
        )
      else if (report.hasSchemaDamage)
        IssuePanel(
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
          tone: IssueTone.error,
        ),
      if (!report.hasSchemaDamage && report.healingIssues.isNotEmpty)
        IssuePanel(
          icon: Icons.build_outlined,
          title: 'Reconnect exercises to logging rows',
          lines: unambiguousFormulaIssues.expand(_issueLines).toList(),
          action: unambiguousFormulaIssues.isEmpty
              ? null
              : FilledButton.icon(
                  key: const ValueKey('repair-unambiguous-formulas'),
                  onPressed: onRepairFormulas == null
                      ? null
                      : () => unawaited(onRepairFormulas!()),
                  icon: const Icon(Icons.build_circle_outlined),
                  label: const Text('Repair unambiguous formulas'),
                ),
          extraContent: [
            for (final issue in choiceFormulaIssues)
              _RepairChoiceItem(
                key: ValueKey(
                  'formula-repair-item-${issue.activeSheetRowNumber}',
                ),
                issue: issue,
                onRepairFormulaIssue: onRepairFormulaIssue,
              ),
          ],
          tone: IssueTone.warning,
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

String _migrationTitle(WbkMigrationReport report) {
  if (report.kind == WbkMigrationKind.format09) {
    return report.canApply
        ? 'Update workout sheet formats'
        : 'Workout sheet format update needs attention';
  }
  return report.canApply
      ? 'Convert old workout sheet'
      : 'Old workout sheet needs attention';
}

String _manualRepairItemLine(ManualRepairItem item) {
  return 'Active sheet row ${item.sheetRowNumber}: ${item.problem}';
}

class _RepairChoiceItem extends StatefulWidget {
  const _RepairChoiceItem({
    super.key,
    required this.issue,
    this.onRepairFormulaIssue,
  });

  final FormulaHealingIssue issue;
  final Future<void> Function({
    required int activeSheetRowNumber,
    required int selectedRow,
  })?
  onRepairFormulaIssue;

  @override
  State<_RepairChoiceItem> createState() {
    return _RepairChoiceItemSt();
  }
}

class _RepairChoiceItemSt extends State<_RepairChoiceItem> {
  int? _selectedRow;

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final warningStyle = stateStyle(
      Theme.of(context).colorScheme,
      VisualSt.warning,
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
                'Choose the exercise for ${issue.exerciseName}',
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
                    _selectedRow = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: ValueKey(
                  'repair-formula-row-${issue.activeSheetRowNumber}',
                ),
                onPressed:
                    _selectedRow == null || widget.onRepairFormulaIssue == null
                    ? null
                    : () => unawaited(
                        widget.onRepairFormulaIssue!(
                          activeSheetRowNumber: issue.activeSheetRowNumber,
                          selectedRow: _selectedRow!,
                        ),
                      ),
                icon: const Icon(Icons.build_circle_outlined),
                label: Text('Repair ${issue.exerciseName}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Iterable<String> _issueLines(FormulaHealingIssue issue) sync* {
  yield 'Repair formula cells so each workout row points to the correct '
      'Exercises entry.';
  yield '${issue.exerciseName} can be reconnected automatically.';
  yield 'Spreadsheet details';
  final selectedRow = issue.preselectedRow;
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

String _formulaReasonLabel(HealingIssueReason reason) {
  switch (reason) {
    case HealingIssueReason.missingFormula:
      return 'missing formula';
    case HealingIssueReason.brokenFormula:
      return 'broken formula';
  }
}

enum IssueTone { error, warning }

class IssuePanel extends StatelessWidget {
  const IssuePanel({
    required this.icon,
    required this.title,
    required this.lines,
    required this.tone,
    this.action,
    this.extraContent = const [],
    super.key,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final IssueTone tone;
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

    return StCallout(
      state: switch (tone) {
        IssueTone.error => VisualSt.error,
        IssueTone.warning => VisualSt.warning,
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
