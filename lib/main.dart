import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

const workoutTrackerDevelopmentSpreadsheetUrl =
    'https://docs.google.com/spreadsheets/d/'
    '$workoutTrackerDevelopmentSpreadsheetId/edit?gid=0#gid=0';

void main() {
  runApp(
    const WorkoutTrackerApp(
      validationService: AdcSpreadsheetValidationService(),
      initialSpreadsheetText: workoutTrackerDevelopmentSpreadsheetUrl,
    ),
  );
}

abstract interface class SpreadsheetValidationService {
  Future<SpreadsheetValidationReport> validateSpreadsheet(String spreadsheetId);

  Future<SpreadsheetValidationReport> createHistoryBlock({
    required String spreadsheetId,
    required String label,
    required ParsedActiveSheet activeSheet,
  });
}

class SpreadsheetValidationReport {
  const SpreadsheetValidationReport({
    required this.spreadsheetId,
    required this.activeSheet,
  });

  final String spreadsheetId;
  final ParsedActiveSheet activeSheet;

  List<SchemaViolation> get schemaViolations {
    return activeSheet.schemaViolations;
  }

  List<FormulaHealingIssue> get formulaHealingIssues {
    return activeSheet.formulaHealingIssues;
  }

  bool get hasBlockingSchemaViolations {
    return schemaViolations.isNotEmpty;
  }
}

class GoogleSpreadsheetValidationService
    implements SpreadsheetValidationService {
  const GoogleSpreadsheetValidationService({
    required this.readAdapter,
    this.writeAdapter,
  });

  final GoogleSheetsReadAdapter readAdapter;
  final GoogleSheetsWriteAdapter? writeAdapter;

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: await readAdapter.readParsedActiveSheet(spreadsheetId),
    );
  }

  @override
  Future<SpreadsheetValidationReport> createHistoryBlock({
    required String spreadsheetId,
    required String label,
    required ParsedActiveSheet activeSheet,
  }) async {
    final writeAdapter = this.writeAdapter;
    if (writeAdapter == null) {
      throw StateError('History block creation requires a write adapter.');
    }
    final plan = activeSheet.planNewHistoryBlock(label: label);
    await writeAdapter.applyActiveSheetWritePlan(
      spreadsheetId: spreadsheetId,
      plan: plan,
    );
    return validateSpreadsheet(spreadsheetId);
  }
}

class AdcSpreadsheetValidationService implements SpreadsheetValidationService {
  const AdcSpreadsheetValidationService();

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    auth.AutoRefreshingAuthClient? client;
    try {
      client = await auth.clientViaApplicationDefaultCredentials(
        scopes: GoogleApisSheetsSpreadsheetClient.readOnlyScopes,
      );
      final api = sheets.SheetsApi(client);
      final adapter = GoogleSheetsReadAdapter(
        client: GoogleApisSheetsSpreadsheetClient(api),
      );
      return GoogleSpreadsheetValidationService(
        readAdapter: adapter,
      ).validateSpreadsheet(spreadsheetId);
    } finally {
      client?.close();
    }
  }

  @override
  Future<SpreadsheetValidationReport> createHistoryBlock({
    required String spreadsheetId,
    required String label,
    required ParsedActiveSheet activeSheet,
  }) async {
    auth.AutoRefreshingAuthClient? client;
    try {
      client = await auth.clientViaApplicationDefaultCredentials(
        scopes: GoogleApisSheetsWriteClient.writeScopes,
      );
      final api = sheets.SheetsApi(client);
      return GoogleSpreadsheetValidationService(
        readAdapter: GoogleSheetsReadAdapter(
          client: GoogleApisSheetsSpreadsheetClient(api),
        ),
        writeAdapter: GoogleSheetsWriteAdapter(
          client: GoogleApisSheetsWriteClient(api),
        ),
      ).createHistoryBlock(
        spreadsheetId: spreadsheetId,
        label: label,
        activeSheet: activeSheet,
      );
    } finally {
      client?.close();
    }
  }
}

class WorkoutTrackerApp extends StatelessWidget {
  const WorkoutTrackerApp({
    required this.validationService,
    this.initialSpreadsheetText = '',
    super.key,
  });

  final SpreadsheetValidationService validationService;
  final String initialSpreadsheetText;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkoutTracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C66)),
        useMaterial3: true,
      ),
      home: SpreadsheetValidationShell(
        validationService: validationService,
        initialSpreadsheetText: initialSpreadsheetText,
      ),
    );
  }
}

class SpreadsheetValidationShell extends StatefulWidget {
  const SpreadsheetValidationShell({
    required this.validationService,
    required this.initialSpreadsheetText,
    super.key,
  });

  final SpreadsheetValidationService validationService;
  final String initialSpreadsheetText;

  @override
  State<SpreadsheetValidationShell> createState() {
    return _SpreadsheetValidationShellState();
  }
}

class _SpreadsheetValidationShellState
    extends State<SpreadsheetValidationShell> {
  late final TextEditingController _spreadsheetController;
  late final TextEditingController _newHistoryBlockController;
  SpreadsheetValidationReport? _report;
  String? _error;
  String? _selectedWorkout;
  String? _selectedHistoryBlock;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _spreadsheetController = TextEditingController(
      text: widget.initialSpreadsheetText,
    );
    _newHistoryBlockController = TextEditingController();
  }

  @override
  void dispose() {
    _spreadsheetController.dispose();
    _newHistoryBlockController.dispose();
    super.dispose();
  }

  void _adoptReport(SpreadsheetValidationReport report) {
    _report = report;
    _error = null;
    _selectedWorkout = report.activeSheet.selectableWorkouts.firstOrNull;
    _selectedHistoryBlock = report.activeSheet.historyBlocks.firstOrNull?.label;
  }

  Future<void> _validateSelectedSpreadsheet() async {
    final spreadsheetId = spreadsheetIdFromSelection(
      _spreadsheetController.text,
    );
    if (spreadsheetId.isEmpty) {
      setState(() {
        _report = null;
        _error = 'Enter a Google Sheets URL or spreadsheet ID.';
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _report = null;
      _error = null;
    });

    try {
      final report = await widget.validationService.validateSpreadsheet(
        spreadsheetId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _adoptReport(report);
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _report = null;
        _error = 'Unable to validate spreadsheet: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  Future<void> _createHistoryBlock() async {
    final report = _report;
    final label = _newHistoryBlockController.text.trim();
    if (report == null || label.isEmpty) {
      setState(() {
        _error = 'Enter a visible history block label.';
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _error = null;
    });

    try {
      final updatedReport = await widget.validationService.createHistoryBlock(
        spreadsheetId: report.spreadsheetId,
        label: label,
        activeSheet: report.activeSheet,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _report = updatedReport;
        _error = null;
        _selectedHistoryBlock = label;
        if (!updatedReport.activeSheet.selectableWorkouts.contains(
          _selectedWorkout,
        )) {
          _selectedWorkout =
              updatedReport.activeSheet.selectableWorkouts.firstOrNull;
        }
        _newHistoryBlockController.clear();
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Unable to create history block: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  void _useDevelopmentSheet() {
    _spreadsheetController.text = workoutTrackerDevelopmentSpreadsheetUrl;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('WorkoutTracker'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Spreadsheet validation',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _spreadsheetController,
                    decoration: const InputDecoration(
                      labelText: 'Google Sheets URL or spreadsheet ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.table_chart_outlined),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _validateSelectedSpreadsheet(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _isValidating
                            ? null
                            : _validateSelectedSpreadsheet,
                        icon: _isValidating
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.verified_outlined),
                        label: const Text('Validate spreadsheet'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isValidating ? null : _useDevelopmentSheet,
                        icon: const Icon(Icons.science_outlined),
                        label: const Text('Use development sheet'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    _IssuePanel(
                      icon: Icons.error_outline,
                      title: 'Connection or validation failed',
                      lines: [_error!],
                      tone: _IssueTone.error,
                    ),
                  if (_report != null) ...[
                    _ValidationSummary(report: _report!),
                    if (!_report!.hasBlockingSchemaViolations) ...[
                      const SizedBox(height: 24),
                      _WorkoutAndHistorySelection(
                        activeSheet: _report!.activeSheet,
                        selectedWorkout: _selectedWorkout,
                        selectedHistoryBlock: _selectedHistoryBlock,
                        newHistoryBlockController: _newHistoryBlockController,
                        onWorkoutChanged: (workout) {
                          setState(() {
                            _selectedWorkout = workout;
                          });
                        },
                        onHistoryBlockChanged: (historyBlock) {
                          setState(() {
                            _selectedHistoryBlock = historyBlock;
                          });
                        },
                        onCreateHistoryBlock: _isValidating
                            ? null
                            : _createHistoryBlock,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutAndHistorySelection extends StatelessWidget {
  const _WorkoutAndHistorySelection({
    required this.activeSheet,
    required this.selectedWorkout,
    required this.selectedHistoryBlock,
    required this.newHistoryBlockController,
    required this.onWorkoutChanged,
    required this.onHistoryBlockChanged,
    required this.onCreateHistoryBlock,
  });

  final ParsedActiveSheet activeSheet;
  final String? selectedWorkout;
  final String? selectedHistoryBlock;
  final TextEditingController newHistoryBlockController;
  final ValueChanged<String?> onWorkoutChanged;
  final ValueChanged<String?> onHistoryBlockChanged;
  final VoidCallback? onCreateHistoryBlock;

  @override
  Widget build(BuildContext context) {
    final workouts = activeSheet.selectableWorkouts;
    final historyBlocks = activeSheet.historyBlocks;
    final selectedWorkout = workouts.contains(this.selectedWorkout)
        ? this.selectedWorkout
        : workouts.firstOrNull;
    final selectedHistoryBlock =
        historyBlocks.any((block) => block.label == this.selectedHistoryBlock)
        ? this.selectedHistoryBlock
        : historyBlocks.firstOrNull?.label;
    final overview = selectedWorkout == null || selectedHistoryBlock == null
        ? null
        : activeSheet.buildWorkoutOverview(
            workout: selectedWorkout,
            historyBlockLabel: selectedHistoryBlock,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Workout setup', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                initialValue: selectedWorkout,
                decoration: const InputDecoration(
                  labelText: 'Workout',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.fitness_center_outlined),
                ),
                items: [
                  for (final workout in workouts)
                    DropdownMenuItem(value: workout, child: Text(workout)),
                ],
                onChanged: onWorkoutChanged,
              ),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                initialValue: selectedHistoryBlock,
                decoration: const InputDecoration(
                  labelText: 'History block',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.history_outlined),
                ),
                items: [
                  for (final block in historyBlocks)
                    DropdownMenuItem(
                      value: block.label,
                      child: Text(block.label),
                    ),
                ],
                onChanged: onHistoryBlockChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: newHistoryBlockController,
                decoration: const InputDecoration(
                  labelText: 'New history block label',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.add_chart_outlined),
                ),
                textInputAction: TextInputAction.done,
              ),
            ),
            FilledButton.icon(
              onPressed: onCreateHistoryBlock,
              icon: const Icon(Icons.add_outlined),
              label: const Text('Create history block'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (overview != null) _WorkoutOverviewList(overview: overview),
      ],
    );
  }
}

class _WorkoutOverviewList extends StatelessWidget {
  const _WorkoutOverviewList({required this.overview});

  final WorkoutOverview overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${overview.workout} exercises',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        for (final slot in overview.slots) _WorkoutOverviewTile(slot: slot),
      ],
    );
  }
}

class _WorkoutOverviewTile extends StatelessWidget {
  const _WorkoutOverviewTile({required this.slot});

  final WorkoutOverviewSlot slot;

  @override
  Widget build(BuildContext context) {
    final setLabel = slot.setCount == 1 ? '1 set' : '${slot.setCount} sets';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      slot.exercise,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(setLabel),
                ],
              ),
              for (final backup in slot.backups) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.subdirectory_arrow_right, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(backup.exercise)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String spreadsheetIdFromSelection(String input) {
  final trimmed = input.trim();
  final match = RegExp(r'/spreadsheets/d/([A-Za-z0-9_-]+)').firstMatch(trimmed);
  return match?.group(1) ?? trimmed;
}

class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({required this.report});

  final SpreadsheetValidationReport report;

  @override
  Widget build(BuildContext context) {
    final panels = <Widget>[
      _IssuePanel(
        icon: report.hasBlockingSchemaViolations
            ? Icons.report_problem_outlined
            : Icons.check_circle_outline,
        title: report.hasBlockingSchemaViolations
            ? 'Sheet contract issues'
            : 'Sheet contract valid',
        lines: report.hasBlockingSchemaViolations
            ? report.schemaViolations.map(_schemaViolationLine).toList()
            : [
                'No blocking schema errors found in spreadsheet '
                    '${report.spreadsheetId}.',
              ],
        tone: report.hasBlockingSchemaViolations
            ? _IssueTone.error
            : _IssueTone.success,
      ),
    ];

    if (report.formulaHealingIssues.isEmpty) {
      panels.add(
        const _IssuePanel(
          icon: Icons.check_circle_outline,
          title: 'Formulas valid',
          lines: ['No formula repair issues found.'],
          tone: _IssueTone.success,
        ),
      );
    } else {
      panels.add(
        _IssuePanel(
          icon: Icons.build_outlined,
          title: 'Formula repair needed',
          lines: report.formulaHealingIssues
              .expand(_formulaHealingIssueLines)
              .toList(),
          tone: _IssueTone.warning,
        ),
      );
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

enum _IssueTone { error, warning, success }

class _IssuePanel extends StatelessWidget {
  const _IssuePanel({
    required this.icon,
    required this.title,
    required this.lines,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final _IssueTone tone;

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
    case _IssueTone.success:
      return (
        background: const Color(0xFFE6F4EA),
        border: const Color(0xFF4F9D69),
        foreground: const Color(0xFF145A32),
      );
  }
}
