import 'package:workout_tracker/sheets.dart';

const workoutTrackerDevelopmentSpreadsheetId =
    '1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E';

class DevelopmentSheetResetHarness {
  DevelopmentSheetResetHarness({required this.initializer});

  final WbkInit initializer;

  Future<void> reset({
    String spreadsheetId = workoutTrackerDevelopmentSpreadsheetId,
  }) async {
    if (spreadsheetId != workoutTrackerDevelopmentSpreadsheetId) {
      throw ArgumentError.value(
        spreadsheetId,
        'spreadsheetId',
        'Development sheet reset is limited to the known development spreadsheet.',
      );
    }

    final workbook = await loadWbkTmpl();
    await initializer.initializeWorkbook(
      spreadsheetId: spreadsheetId,
      workbook: workbook,
    );
  }
}
