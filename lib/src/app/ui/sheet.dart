import 'package:flutter/material.dart';

import '../account.dart';
import '../repair.dart';
import '../selection.dart';
import '../validation.dart';
import '../workspace.dart';
import 'view.dart';
import 'shared/a11y.dart';
import 'shared/error.dart';
import 'shared/header.dart';
import 'shared/name_dialog.dart';

final class SheetView extends AppView {
  const SheetView({
    required super.isBusy,
    required this.isRestoring,
    required this.sheetText,
    required this.selectedSheet,
    required this.availability,
    required this.showAvailability,
    required this.showTextFallback,
    required this.hasLoadedWorkout,
    required this.report,
    required this.account,
    required this.hasPicker,
    required this.showAccount,
    this.accountMismatch,
    super.error,
  });

  final bool isRestoring;
  final String sheetText;
  final SelectedSheet? selectedSheet;
  final PickerAvail availability;
  final bool showAvailability;
  final bool showTextFallback;
  final bool hasLoadedWorkout;
  final ValReport? report;
  final GoogleAccountProfile? account;
  final bool hasPicker;
  final bool showAccount;
  final AcctMismatch? accountMismatch;
}

sealed class SheetCmd {
  const SheetCmd();
}

final class SetSheetText extends SheetCmd {
  const SetSheetText(this.text);

  final String text;
}

final class ValidateSheet extends SheetCmd {
  const ValidateSheet();
}

final class ChooseSheet extends SheetCmd {
  const ChooseSheet();
}

final class SignIn extends SheetCmd {
  const SignIn();
}

final class CreateSheet extends SheetCmd {
  const CreateSheet(this.name);

  final String name;
}

final class SignOut extends SheetCmd {
  const SignOut();
}

final class ConfirmAccount extends SheetCmd {
  const ConfirmAccount();
}

final class ReturnToSheet extends SheetCmd {
  const ReturnToSheet();
}

final class ReturnToWorkout extends SheetCmd {
  const ReturnToWorkout();
}

final class RepairAll extends SheetCmd {
  const RepairAll();
}

final class RepairOne extends SheetCmd {
  const RepairOne({required this.activeRow, required this.exerciseRow});

  final int activeRow;
  final int exerciseRow;
}

final class OpenSheet extends SheetCmd {
  const OpenSheet();
}

final class DismissSheetError extends SheetCmd {
  const DismissSheetError();
}

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
        if (view.showTextFallback && !view.isRestoring)
          _SheetText(view: view, ctrl: _ctrl, run: widget.run),
        const SizedBox(height: 24),
        if (view.error case final error?) ...[
          ErrorBanner(
            message: error,
            onDismiss: () => widget.run(const DismissSheetError()),
          ),
          const SizedBox(height: 16),
        ],
        if (view.accountMismatch case final mismatch?) ...[
          IssuePanel(
            icon: Icons.manage_accounts_outlined,
            title: 'Saved sheet uses another account',
            lines: [
              'This sheet was saved for ${mismatch.savedEmail ?? 'an unbound account'}, '
                  'but the current account is ${mismatch.currentEmail ?? 'signed out'}.',
              'Confirm the current account or choose another sheet.',
            ],
            tone: IssueTone.warning,
            action: FilledButton.icon(
              key: const ValueKey('confirm-sheet-account'),
              onPressed: view.isBusy
                  ? null
                  : () => widget.run(const ConfirmAccount()),
              icon: const Icon(Icons.check_outlined),
              label: const Text('Use current account'),
            ),
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
    final connected = !view.showAccount || view.account != null;
    final title = view.isRestoring
        ? 'Connecting to Google Sheets…'
        : selected?.displayLabel ??
              (connected ? 'No workout sheet selected' : 'Not logged in');
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
                Expanded(
                  child: ScreenTitle(
                    title,
                    key: const ValueKey('selected-spreadsheet-label'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (view.showAccount) ...[
                  const SizedBox(width: 8),
                  AccountMenu(
                    account: view.account,
                    run: run,
                    enabled: !view.isRestoring,
                  ),
                ],
              ],
            ),
            if (view.isRestoring) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(
                key: ValueKey('workspace-restore-progress'),
                minHeight: 2,
              ),
            ] else if (!connected) ...[
              const SizedBox(height: 8),
              Text(
                'Log in from the account menu.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
            if (connected && !view.isRestoring) ...[
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
              if (selected != null && view.hasLoadedWorkout)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final change = OutlinedButton.icon(
                      key: const ValueKey('choose-google-spreadsheet'),
                      onPressed: view.isBusy || !view.availability.canChoose
                          ? null
                          : () => run(const ChooseSheet()),
                      icon: const Icon(Icons.drive_folder_upload_outlined),
                      label: const Text('Change sheet'),
                    );
                    final create = OutlinedButton.icon(
                      key: const ValueKey('create-google-spreadsheet'),
                      onPressed: view.isBusy || !view.availability.canCreate
                          ? null
                          : onCreate,
                      icon: const Icon(Icons.add_to_drive_outlined),
                      label: const Text('Create sheet'),
                    );
                    if (constraints.maxWidth < 400) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [change, const SizedBox(height: 8), create],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: change),
                        const SizedBox(width: 8),
                        Expanded(child: create),
                      ],
                    );
                  },
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey('create-google-spreadsheet'),
                    onPressed: view.isBusy || !view.availability.canCreate
                        ? null
                        : onCreate,
                    icon: const Icon(Icons.add_to_drive_outlined),
                    label: const Text('Create sheet'),
                  ),
                ),
              if (view.showAvailability &&
                  view.availability.summary != null) ...[
                const SizedBox(height: 8),
                Text(
                  view.availability.summary!,
                  key: const ValueKey('spreadsheet-picker-availability'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
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
