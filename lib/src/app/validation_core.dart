import 'package:workout_tracker/contract.dart';
import 'package:url_launcher/url_launcher.dart';

abstract class WbkSvc {
  const WbkSvc();

  /// Reads and reparses the active sheet for [spreadsheetId].
  ///
  /// The returned [ParsedActiveSheet] becomes the ordering source for every
  /// later workout, history-block, and row selection passed back through this
  /// Interface.
  Future<ValReport> validateSheet(String spreadsheetId);

  /// Applies [plan] to the active sheet and rereads the spreadsheet.
  ///
  /// Callers should treat [plan] as row-order-sensitive and build it from the
  /// same [activeSheet] they pass here. The sheet contract Module owns row and
  /// history-block validity; callers should pass row numbers obtained from the
  /// parsed read models rather than inventing them.
  Future<ValReport> applyWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  });

  Future<ValReport> createExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ExerciseDef exercise,
  }) {
    throw UnsupportedError('Exercise authoring is not supported.');
  }

  Future<ValReport> updateExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required ExerciseDef exercise,
  }) {
    throw UnsupportedError('Exercise authoring is not supported.');
  }

  Future<ValReport> addExerciseToWorkout({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise exercise,
    required WorkoutPlacementMetadata metadata,
    required ExercisePlacementTarget placement,
  }) {
    throw UnsupportedError('Exercise placement is not supported.');
  }

  Future<ValReport> reorderExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ReorderIntent intent,
  }) {
    throw UnsupportedError('Exercise reorder is not supported.');
  }

  Future<ValReport> reorderWorkoutExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required String workout,
    required ReorderIntent intent,
  }) {
    throw UnsupportedError('Workout exercise reorder is not supported.');
  }

  Future<ValReport> deleteWorkoutExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required int primaryRow,
  }) {
    throw UnsupportedError('Workout exercise deletion is not supported.');
  }
}

class ExercisePlacementTarget {
  const ExercisePlacementTarget.primary({required this.workout})
    : primaryRow = null;

  const ExercisePlacementTarget.backup({required this.primaryRow})
    : workout = null;

  final String? workout;
  final int? primaryRow;

  bool get isBackup => primaryRow != null;
}

abstract interface class SheetOpener {
  Future<void> openSheet(String url);
}

class UrlSheetOpener implements SheetOpener {
  const UrlSheetOpener();

  @override
  Future<void> openSheet(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw StateError('Unable to open Google Sheets URL: $url');
    }
  }
}

class ValReport {
  ValReport({
    required String spreadsheetId,
    required this.activeSheet,
    Iterable<WriteRejection> writeRejections = const [],
  }) : sheetId = spreadsheetId,
       writeRejections = List<WriteRejection>.unmodifiable(writeRejections);

  final String sheetId;
  final ParsedActiveSheet activeSheet;
  final List<WriteRejection> writeRejections;

  String get sheetUrl {
    return sheetUrlForId(sheetId);
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

  List<FormulaHealingIssue> get healingIssues {
    return activeSheet.healingIssues;
  }

  bool get hasSchemaDamage {
    return schemaViolations.isNotEmpty || writeRejections.isNotEmpty;
  }

  bool get hasBlockingIssues {
    return schemaViolations.isNotEmpty ||
        healingIssues.isNotEmpty ||
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

String sheetIdFromSelection(String input) {
  final trimmed = input.trim();
  final match = RegExp(r'/spreadsheets/d/([A-Za-z0-9_-]+)').firstMatch(trimmed);
  return match?.group(1) ?? trimmed;
}

String sheetUrlForId(String spreadsheetId) {
  return 'https://docs.google.com/spreadsheets/d/'
      '$spreadsheetId/edit?gid=0#gid=0';
}
