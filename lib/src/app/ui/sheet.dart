import 'package:flutter/material.dart';

import '../account.dart';
import '../repair.dart';
import '../selection.dart';
import 'flow.dart';
import 'shared/a11y.dart';
import 'shared/name_dialog.dart';

class SheetScreen extends StatefulWidget {
  const SheetScreen({required this.view, required this.run, super.key});

  final SheetView view;
  final Future<CmdResult> Function(SheetCmd cmd) run;

  @override
  State<SheetScreen> createState() => _SheetScreenSt();
}

class _SheetScreenSt extends State<SheetScreen> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.view.sheetText);
  }

  @override
  void didUpdateWidget(SheetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.view.sheetText;
    if (text != _ctrl.text) {
      _ctrl.text = text;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _createSheet() async {
    final auth = await widget.run(const AuthorizeCreate());
    if (!mounted || !auth.ok) {
      final message = auth.message;
      if (message != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    final initial = defaultSheetTitle();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => NameDialog(
        title: 'Create sheet',
        label: 'Sheet name',
        initialValue: initial,
        submitLabel: 'Create',
        textFieldKey: const ValueKey('create-spreadsheet-name'),
      ),
    );
    if (!mounted || value == null) {
      return;
    }
    final name = value.trim();
    await widget.run(CreateSheet(name.isEmpty ? initial : name));
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (view.hasPicker) ...[
          _SheetPick(view: view, run: widget.run, onCreate: _createSheet),
          if (view.showTextFallback) const SizedBox(height: 12),
        ],
        if (view.showTextFallback)
          _SheetText(view: view, ctrl: _ctrl, run: widget.run),
        const SizedBox(height: 24),
        if (view.error case final error?) ...[
          IssuePanel(
            icon: Icons.error_outline,
            title: 'Connection or validation failed',
            lines: [error],
            tone: IssueTone.error,
          ),
          const SizedBox(height: 16),
        ],
        if (view.report case final report?)
          ValidationSummary(
            report: report,
            onRepairFormulas: view.isBusy
                ? null
                : () async {
                    await widget.run(const RepairAll());
                  },
            onRepairFormulaIssue: view.isBusy
                ? null
                : ({
                    required activeSheetRowNumber,
                    required selectedRow,
                  }) async {
                    await widget.run(
                      RepairOne(
                        activeRow: activeSheetRowNumber,
                        exerciseRow: selectedRow,
                      ),
                    );
                  },
            onOpenSpreadsheet: view.isBusy
                ? null
                : () async {
                    await widget.run(const OpenSheet());
                  },
          ),
      ],
    );
  }
}

class _SheetPick extends StatelessWidget {
  const _SheetPick({
    required this.view,
    required this.run,
    required this.onCreate,
  });

  final SheetView view;
  final Future<CmdResult> Function(SheetCmd cmd) run;
  final Future<void> Function() onCreate;

  @override
  Widget build(BuildContext context) {
    final selected = view.selectedSheet;
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selected?.displayLabel ?? 'No workout sheet selected',
                    key: const ValueKey('selected-spreadsheet-label'),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (view.showAccount) ...[
                  const SizedBox(width: 8),
                  AccountMenu(account: view.account, run: run),
                ],
              ],
            ),
            if (selected?.accountEmail case final email?) ...[
              const SizedBox(height: 4),
              Text(
                email,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            if (selected != null && view.hasLoadedWorkout)
              FilledButton.tonalIcon(
                key: const ValueKey('return-to-selected-workout'),
                onPressed: view.isBusy
                    ? null
                    : () => run(const ReturnToWorkout()),
                icon: const Icon(Icons.fitness_center_outlined),
                label: const Text('Return to workout'),
              )
            else
              FilledButton.icon(
                key: const ValueKey('choose-google-spreadsheet'),
                onPressed: view.isBusy || !view.availability.canChoose
                    ? null
                    : () => run(const ChooseSheet()),
                icon: const Icon(Icons.drive_folder_upload_outlined),
                label: Text(
                  selected == null ? 'Choose workout sheet' : 'Change sheet',
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (selected != null && view.hasLoadedWorkout)
                  OutlinedButton.icon(
                    key: const ValueKey('choose-google-spreadsheet'),
                    onPressed: view.isBusy || !view.availability.canChoose
                        ? null
                        : () => run(const ChooseSheet()),
                    icon: const Icon(Icons.drive_folder_upload_outlined),
                    label: const Text('Change sheet'),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('create-google-spreadsheet'),
                  onPressed: view.isBusy || !view.availability.canCreate
                      ? null
                      : onCreate,
                  icon: const Icon(Icons.add_to_drive_outlined),
                  label: const Text('Create sheet'),
                ),
              ],
            ),
            if (view.showAvailability && view.availability.summary != null) ...[
              const SizedBox(height: 8),
              Text(
                view.availability.summary!,
                key: const ValueKey('spreadsheet-picker-availability'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetText extends StatelessWidget {
  const _SheetText({required this.view, required this.ctrl, required this.run});

  final SheetView view;
  final TextEditingController ctrl;
  final Future<CmdResult> Function(SheetCmd cmd) run;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('spreadsheet-url-fallback'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: A11yTextField(
                label: 'Google Sheets URL or ID',
                valueListenable: ctrl,
                hint: 'Paste a Google Sheets URL or spreadsheet ID.',
                child: TextField(
                  key: const ValueKey('spreadsheet-selection-input'),
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Paste Google Sheets URL or ID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.table_chart_outlined),
                  ),
                  onChanged: (text) => run(SetSheetText(text)),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => run(const ValidateSheet()),
                ),
              ),
            ),
            if (view.showAccount) ...[
              const SizedBox(width: 8),
              AccountMenu(account: view.account, run: run),
            ],
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('validate-spreadsheet'),
          onPressed: view.isBusy ? null : () => run(const ValidateSheet()),
          icon: view.isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_outlined),
          label: const Text('Select'),
        ),
      ],
    );
  }
}
