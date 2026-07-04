import 'package:workout_tracker/sheet_contract.dart';
import 'package:url_launcher/url_launcher.dart';

abstract class WorkbookCommandService {
  const WorkbookCommandService();

  /// Reads and reparses the active sheet for [spreadsheetId].
  ///
  /// The returned [ParsedActiveSheet] becomes the ordering source for every
  /// later workout, history-block, and row selection passed back through this
  /// Interface.
  Future<SpreadsheetValidationReport> validateSpreadsheet(String spreadsheetId);

  /// Applies [plan] to the active sheet and rereads the spreadsheet.
  ///
  /// Callers should treat [plan] as row-order-sensitive and build it from the
  /// same [activeSheet] they pass here. The sheet contract Module owns row and
  /// history-block validity; callers should pass row numbers obtained from the
  /// parsed read models rather than inventing them.
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  });

  Future<SpreadsheetValidationReport> createCanonicalExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExerciseDefinition exercise,
  }) {
    throw UnsupportedError('Exercise authoring is not supported.');
  }

  Future<SpreadsheetValidationReport> updateCanonicalExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required CanonicalExerciseDefinition exercise,
  }) {
    throw UnsupportedError('Exercise authoring is not supported.');
  }

  Future<SpreadsheetValidationReport> addExistingExerciseToWorkout({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise exercise,
    required WorkoutPlacementMetadata metadata,
    required ExercisePlacementTarget placement,
  }) {
    throw UnsupportedError('Exercise placement is not supported.');
  }

  Future<SpreadsheetValidationReport> reorderCanonicalExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ReorderIntent intent,
  }) {
    throw UnsupportedError('Exercise reorder is not supported.');
  }

  Future<SpreadsheetValidationReport> reorderWorkoutExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required String workout,
    required ReorderIntent intent,
  }) {
    throw UnsupportedError('Workout exercise reorder is not supported.');
  }

  Future<SpreadsheetValidationReport> deleteWorkoutExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required int primarySheetRowNumber,
  }) {
    throw UnsupportedError('Workout exercise deletion is not supported.');
  }
}

class ExercisePlacementTarget {
  const ExercisePlacementTarget.primary({required this.workout})
    : primarySheetRowNumber = null;

  const ExercisePlacementTarget.backup({required this.primarySheetRowNumber})
    : workout = null;

  final String? workout;
  final int? primarySheetRowNumber;

  bool get isBackup => primarySheetRowNumber != null;
}

abstract interface class SpreadsheetOpener {
  Future<void> openSpreadsheet(String url);
}

class UrlLauncherSpreadsheetOpener implements SpreadsheetOpener {
  const UrlLauncherSpreadsheetOpener();

  @override
  Future<void> openSpreadsheet(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw StateError('Unable to open Google Sheets URL: $url');
    }
  }
}

class SpreadsheetValidationReport {
  SpreadsheetValidationReport({
    required this.spreadsheetId,
    required this.activeSheet,
    Iterable<ActiveSheetWriteRejection> writeRejections = const [],
  }) : writeRejections = List<ActiveSheetWriteRejection>.unmodifiable(
         writeRejections,
       );

  final String spreadsheetId;
  final ParsedActiveSheet activeSheet;
  final List<ActiveSheetWriteRejection> writeRejections;

  String get spreadsheetUrl {
    return spreadsheetUrlForId(spreadsheetId);
  }

  List<SchemaViolation> get schemaViolations {
    return activeSheet.schemaViolations;
  }

  List<ManualRepairItem> get manualRepairItems {
    return [
      for (final violation in schemaViolations)
        ManualRepairItem(
          sheetRowNumber: violation.sheetRowNumber,
          workout: violation.workout,
          problem: violation.message,
        ),
      for (final rejection in writeRejections)
        ManualRepairItem(
          sheetRowNumber: 1,
          workout: defaultWorkoutName,
          problem: rejection.message,
        ),
    ];
  }

  List<FormulaHealingIssue> get formulaHealingIssues {
    return activeSheet.formulaHealingIssues;
  }

  bool get hasBlockingSchemaViolations {
    return schemaViolations.isNotEmpty || writeRejections.isNotEmpty;
  }

  bool get hasBlockingIssues {
    return schemaViolations.isNotEmpty ||
        formulaHealingIssues.isNotEmpty ||
        writeRejections.isNotEmpty;
  }
}

class ManualRepairItem {
  const ManualRepairItem({
    required this.sheetRowNumber,
    required this.workout,
    required this.problem,
  });

  final int sheetRowNumber;
  final String workout;
  final String problem;

  String get instruction {
    return 'Open the spreadsheet and edit the active sheet.';
  }

  String get displayText {
    return 'Row $sheetRowNumber: $problem $instruction';
  }
}

String spreadsheetIdFromSelection(String input) {
  final trimmed = input.trim();
  final match = RegExp(r'/spreadsheets/d/([A-Za-z0-9_-]+)').firstMatch(trimmed);
  return match?.group(1) ?? trimmed;
}

String spreadsheetUrlForId(String spreadsheetId) {
  return 'https://docs.google.com/spreadsheets/d/'
      '$spreadsheetId/edit?gid=0#gid=0';
}
