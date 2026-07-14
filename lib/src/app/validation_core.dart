import 'package:workout_tracker/contract.dart';
import 'package:url_launcher/url_launcher.dart';

abstract interface class WbkAccess {
  WbkSess open(String sheetId);
}

abstract interface class WbkSess {
  String get sheetId;

  Future<ValReport> read();

  Future<ValReport> execute(WbkCmd cmd);
}

sealed class WbkCmd {
  const WbkCmd();
}

class NewHistoryCmd extends WbkCmd {
  const NewHistoryCmd(this.label);

  final String label;
}

class RepairAllCmd extends WbkCmd {
  const RepairAllCmd();
}

class RepairOneCmd extends WbkCmd {
  const RepairOneCmd({required this.activeRow, required this.exerciseRow});

  final int activeRow;
  final int exerciseRow;
}

class SaveSetCmd extends WbkCmd {
  SaveSetCmd({
    required this.blockLabel,
    required this.sheetRow,
    required Map<String, String> fields,
  }) : fields = Map<String, String>.unmodifiable(fields);

  final String blockLabel;
  final int sheetRow;
  final Map<String, String> fields;
}

class EditSetCmd extends WbkCmd {
  EditSetCmd({
    required this.blockLabel,
    required this.sheetRow,
    required this.setNumber,
    required Map<String, String> fields,
  }) : fields = Map<String, String>.unmodifiable(fields);

  final String blockLabel;
  final int sheetRow;
  final int setNumber;
  final Map<String, String> fields;
}

class EditRawSetCmd extends WbkCmd {
  const EditRawSetCmd({
    required this.blockLabel,
    required this.sheetRow,
    required this.setNumber,
    required this.rawText,
  });

  final String blockLabel;
  final int sheetRow;
  final int setNumber;
  final String rawText;
}

class ClearSetCmd extends WbkCmd {
  const ClearSetCmd({
    required this.blockLabel,
    required this.sheetRow,
    required this.setNumber,
  });

  final String blockLabel;
  final int sheetRow;
  final int setNumber;
}

class CreateExeCmd extends WbkCmd {
  const CreateExeCmd(this.exercise);

  final ExerciseDef exercise;
}

class UpdateExeCmd extends WbkCmd {
  const UpdateExeCmd({required this.selected, required this.exercise});

  final CanonicalExercise selected;
  final ExerciseDef exercise;
}

class ConfirmExeUpdateCmd extends WbkCmd {
  ConfirmExeUpdateCmd({
    required this.impact,
    required Map<int, Map<String, String>> valuesByRow,
  }) : valuesByRow = Map<int, Map<String, String>>.unmodifiable({
         for (final entry in valuesByRow.entries)
           entry.key: Map<String, String>.unmodifiable(entry.value),
       });

  final ExeFormatImpact impact;
  final Map<int, Map<String, String>> valuesByRow;
}

class PlaceExeCmd extends WbkCmd {
  const PlaceExeCmd({
    required this.exercise,
    required this.metadata,
    required this.placement,
  });

  final CanonicalExercise exercise;
  final WorkoutPlacementMetadata metadata;
  final ExercisePlacementTarget placement;
}

class ReorderExesCmd extends WbkCmd {
  const ReorderExesCmd(this.intent);

  final ReorderIntent intent;
}

class ReorderWorkoutCmd extends WbkCmd {
  const ReorderWorkoutCmd({required this.workout, required this.intent});

  final String workout;
  final ReorderIntent intent;
}

class DeleteWorkoutExeCmd extends WbkCmd {
  const DeleteWorkoutExeCmd(this.primaryRow);

  final int primaryRow;
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
    this.exeFormatImpact,
  }) : sheetId = spreadsheetId,
       writeRejections = List<WriteRejection>.unmodifiable(writeRejections);

  final String sheetId;
  final ParsedActiveSheet activeSheet;
  final List<WriteRejection> writeRejections;
  final ExeFormatImpact? exeFormatImpact;

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
