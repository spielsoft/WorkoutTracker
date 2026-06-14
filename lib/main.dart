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
  const GoogleSpreadsheetValidationService({required this.readAdapter});

  final GoogleSheetsReadAdapter readAdapter;

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: await readAdapter.readParsedActiveSheet(spreadsheetId),
    );
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
      final adapter = GoogleSheetsReadAdapter(
        client: GoogleApisSheetsSpreadsheetClient(sheets.SheetsApi(client)),
      );
      return GoogleSpreadsheetValidationService(
        readAdapter: adapter,
      ).validateSpreadsheet(spreadsheetId);
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
  SpreadsheetValidationReport? _report;
  String? _error;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _spreadsheetController = TextEditingController(
      text: widget.initialSpreadsheetText,
    );
  }

  @override
  void dispose() {
    _spreadsheetController.dispose();
    super.dispose();
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
        _report = report;
        _error = null;
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
                  if (_report != null) _ValidationSummary(report: _report!),
                ],
              ),
            ),
          ],
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
