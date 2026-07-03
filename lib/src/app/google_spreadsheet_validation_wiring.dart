import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:workout_tracker/google_sheets.dart';

import 'google_spreadsheet_validation_service.dart';
import 'spreadsheet_validation_core.dart';

typedef GoogleSpreadsheetValidationServiceFactory =
    SpreadsheetValidationService Function(
      sheets.SheetsApi api, {
      required bool canWrite,
    });

SpreadsheetValidationService defaultGoogleSpreadsheetValidationServiceFactory(
  sheets.SheetsApi api, {
  required bool canWrite,
}) {
  final workbookClient = GoogleApisSheetsWorkbookClient(api);
  return GoogleSpreadsheetValidationService(
    readAdapter: GoogleSheetsReadAdapter(client: workbookClient),
    writeAdapter: canWrite
        ? GoogleSheetsWriteAdapter(client: workbookClient)
        : null,
  );
}
