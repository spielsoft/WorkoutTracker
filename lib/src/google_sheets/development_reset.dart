import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:workout_tracker/sheet_contract.dart';

const workoutTrackerDevelopmentSpreadsheetId =
    '1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E';

class DevelopmentSheetResetHarness {
  DevelopmentSheetResetHarness({required this.client});

  final DevelopmentSheetResetClient client;

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

    await client.resetSpreadsheet(
      spreadsheetId: spreadsheetId,
      fixture: developmentSheetResetFixture(),
    );
  }
}

abstract interface class DevelopmentSheetResetClient {
  Future<void> resetSpreadsheet({
    required String spreadsheetId,
    required DevelopmentSheetResetFixture fixture,
  });
}

class DevelopmentSheetResetFixture {
  DevelopmentSheetResetFixture({
    required this.activeSheet,
    required this.exercisesSheet,
  });

  final DevelopmentSheetResetTab activeSheet;
  final DevelopmentSheetResetTab exercisesSheet;
}

class DevelopmentSheetResetTab {
  DevelopmentSheetResetTab({
    required this.title,
    required Iterable<Iterable<String>> rows,
  }) : rows = List<List<String>>.unmodifiable(
         rows.map((row) => List<String>.unmodifiable(row)),
       );

  final String title;
  final List<List<String>> rows;

  int get columnCount {
    var maxColumns = 0;
    for (final row in rows) {
      if (row.length > maxColumns) {
        maxColumns = row.length;
      }
    }
    return maxColumns;
  }
}

DevelopmentSheetResetFixture developmentSheetResetFixture() {
  return DevelopmentSheetResetFixture(
    activeSheet: DevelopmentSheetResetTab(
      title: 'Active Workout',
      rows: [
        [...activeSheetFixedColumns, 'Week 2', '', 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2', 'S1'],
        [
          '=Exercises!A2',
          '=Exercises!C2',
          '=Exercises!D2',
          '=Exercises!E2',
          '=Exercises!F2',
          '=Exercises!G2',
          '=Exercises!H2',
          'Legs',
          '',
          '',
          '',
          '70x8@8',
        ],
        [
          '=Exercises!A3',
          '=Exercises!C3',
          '=Exercises!D3',
          '=Exercises!E3',
          '=Exercises!F3',
          '=Exercises!G3',
          '=Exercises!H3',
          'Legs',
          'TRUE',
          '',
          '',
          '',
        ],
        [
          '',
          'Upper body notes',
          '',
          '',
          '',
          '',
          'Human section row ignored by the app.',
          '',
          '',
          '',
          '',
          '',
        ],
        [
          '=Exercises!A4',
          '=Exercises!C4',
          '=Exercises!D4',
          '=Exercises!E4',
          '=Exercises!F4',
          '=Exercises!G4',
          '=Exercises!H4',
          'Upper',
          '',
          '155x6@8',
          '',
          '150x6@8',
        ],
        [
          '=Exercises!A5',
          '=Exercises!C5',
          '=Exercises!D5',
          '=Exercises!E5',
          '=Exercises!F5',
          '=Exercises!G5',
          '=Exercises!H5',
          'Upper',
          'TRUE',
          '',
          '',
          '',
        ],
        [
          '=Exercises!A6',
          '=Exercises!C6',
          '=Exercises!D6',
          '=Exercises!E6',
          '=Exercises!F6',
          '=Exercises!G6',
          '=Exercises!H6',
          '',
          '',
          '45s@8',
          '',
          '40s@8',
        ],
      ],
    ),
    exercisesSheet: DevelopmentSheetResetTab(
      title: 'Exercises',
      rows: [
        [
          'Exercise',
          'Description',
          'Default Sets',
          'Default Reps',
          'Default RPE',
          'Default Rest',
          'Default Tempo',
          'Notes',
        ],
        [
          'Bulgarian Split Squat',
          'Rear-foot elevated split squat',
          '3',
          '8/side',
          '8',
          '2 min',
          '3-1-1',
          'Use straps if grip limits load.',
        ],
        [
          'Reverse Lunge',
          'Dumbbell reverse lunge',
          '3',
          '10/side',
          '8',
          '90s',
          '',
          'Backup if benches are taken.',
        ],
        [
          'Bench Press',
          'Barbell bench press',
          '4',
          '6',
          '8',
          '3 min',
          '',
          'Pause the first rep.',
        ],
        [
          'Push-Up',
          'Bodyweight push-up',
          '4',
          'AMRAP',
          '8',
          '2 min',
          '',
          'Backup if benches are full.',
        ],
        [
          'Plank',
          'Front plank hold',
          '3',
          '45s',
          '8',
          '60s',
          '',
          'Default workout row with blank Workout.',
        ],
      ],
    ),
  );
}

class GoogleApisDevelopmentSheetResetClient
    implements DevelopmentSheetResetClient {
  GoogleApisDevelopmentSheetResetClient(this._api);

  final sheets.SheetsApi _api;

  static const writeScopes = [sheets.SheetsApi.spreadsheetsScope];

  @override
  Future<void> resetSpreadsheet({
    required String spreadsheetId,
    required DevelopmentSheetResetFixture fixture,
  }) async {
    final targets = await _ensureResetTargets(spreadsheetId, fixture);
    await _rewriteSheet(
      spreadsheetId: spreadsheetId,
      target: targets.exercisesSheet,
      tab: fixture.exercisesSheet,
      frozenRowCount: 1,
    );
    await _rewriteSheet(
      spreadsheetId: spreadsheetId,
      target: targets.activeSheet,
      tab: fixture.activeSheet,
      frozenRowCount: 2,
    );
  }

  Future<_ResetTargets> _ensureResetTargets(
    String spreadsheetId,
    DevelopmentSheetResetFixture fixture,
  ) async {
    var shape = await _fetchSpreadsheetShape(spreadsheetId);
    if (shape.sheets.isEmpty) {
      throw StateError('Spreadsheet has no sheets.');
    }

    var activeSheet = shape.sheets.first;
    final requests = <sheets.Request>[];
    if (activeSheet.title != fixture.activeSheet.title &&
        !shape.hasSheetTitle(fixture.activeSheet.title)) {
      requests.add(
        sheets.Request(
          updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
            properties: sheets.SheetProperties(
              sheetId: activeSheet.sheetId,
              title: fixture.activeSheet.title,
            ),
            fields: 'title',
          ),
        ),
      );
      activeSheet = _SheetShape(
        sheetId: activeSheet.sheetId,
        index: activeSheet.index,
        title: fixture.activeSheet.title,
      );
    }

    if (!shape.hasSheetTitle(fixture.exercisesSheet.title)) {
      requests.add(
        sheets.Request(
          addSheet: sheets.AddSheetRequest(
            properties: sheets.SheetProperties(
              title: fixture.exercisesSheet.title,
              gridProperties: sheets.GridProperties(
                rowCount: _usableRowCount(fixture.exercisesSheet),
                columnCount: fixture.exercisesSheet.columnCount,
                frozenRowCount: 1,
              ),
            ),
          ),
        ),
      );
    }

    if (requests.isNotEmpty) {
      await _api.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: requests),
        spreadsheetId,
        $fields: 'spreadsheetId,replies(addSheet(properties(sheetId)))',
      );
      shape = await _fetchSpreadsheetShape(spreadsheetId);
      activeSheet = shape.sheets.first;
    }

    final exercisesSheet = shape.sheetByTitle(fixture.exercisesSheet.title);
    if (exercisesSheet == null) {
      throw StateError('Exercises sheet could not be created.');
    }

    return _ResetTargets(
      activeSheet: activeSheet,
      exercisesSheet: exercisesSheet,
    );
  }

  Future<void> _rewriteSheet({
    required String spreadsheetId,
    required _SheetShape target,
    required DevelopmentSheetResetTab tab,
    required int frozenRowCount,
  }) async {
    await _api.spreadsheets.values.clear(
      sheets.ClearValuesRequest(),
      spreadsheetId,
      '${_quotedSheetTitle(target.title)}!A1:ZZ1000',
      $fields: 'spreadsheetId,clearedRange',
    );

    await _api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            unmergeCells: sheets.UnmergeCellsRequest(
              range: sheets.GridRange(sheetId: target.sheetId),
            ),
          ),
          sheets.Request(
            updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
              properties: sheets.SheetProperties(
                sheetId: target.sheetId,
                gridProperties: sheets.GridProperties(
                  rowCount: _usableRowCount(tab),
                  columnCount: tab.columnCount,
                  frozenRowCount: frozenRowCount,
                ),
              ),
              fields: 'gridProperties(rowCount,columnCount,frozenRowCount)',
            ),
          ),
          sheets.Request(
            repeatCell: sheets.RepeatCellRequest(
              range: sheets.GridRange(
                sheetId: target.sheetId,
                startRowIndex: 0,
                endRowIndex: frozenRowCount,
              ),
              cell: sheets.CellData(
                userEnteredFormat: sheets.CellFormat(
                  textFormat: sheets.TextFormat(bold: true),
                ),
              ),
              fields: 'userEnteredFormat.textFormat.bold',
            ),
          ),
        ],
      ),
      spreadsheetId,
      $fields: 'spreadsheetId',
    );

    await _api.spreadsheets.values.update(
      sheets.ValueRange(values: tab.rows),
      spreadsheetId,
      '${_quotedSheetTitle(target.title)}!A1',
      valueInputOption: 'USER_ENTERED',
      $fields: 'spreadsheetId,updatedCells',
    );
  }

  Future<_SpreadsheetShape> _fetchSpreadsheetShape(String spreadsheetId) async {
    final spreadsheet = await _api.spreadsheets.get(
      spreadsheetId,
      $fields: 'sheets(properties(sheetId,index,title,sheetType))',
    );
    final apiSheets = [...?spreadsheet.sheets]
      ..sort((left, right) {
        return (left.properties?.index ?? 0).compareTo(
          right.properties?.index ?? 0,
        );
      });

    return _SpreadsheetShape(
      sheets: [
        for (final sheet in apiSheets)
          if (sheet.properties?.sheetId != null)
            _SheetShape(
              sheetId: sheet.properties!.sheetId!,
              index: sheet.properties?.index ?? 0,
              title: sheet.properties?.title ?? '',
            ),
      ],
    );
  }

  int _usableRowCount(DevelopmentSheetResetTab tab) {
    final minimumRows = tab.title == 'Exercises' ? 25 : 50;
    return tab.rows.length > minimumRows ? tab.rows.length : minimumRows;
  }
}

class _ResetTargets {
  const _ResetTargets({
    required this.activeSheet,
    required this.exercisesSheet,
  });

  final _SheetShape activeSheet;
  final _SheetShape exercisesSheet;
}

class _SpreadsheetShape {
  _SpreadsheetShape({required Iterable<_SheetShape> sheets})
    : sheets = List<_SheetShape>.unmodifiable(sheets);

  final List<_SheetShape> sheets;

  bool hasSheetTitle(String title) {
    return sheetByTitle(title) != null;
  }

  _SheetShape? sheetByTitle(String title) {
    for (final sheet in sheets) {
      if (sheet.title == title) {
        return sheet;
      }
    }
    return null;
  }
}

class _SheetShape {
  const _SheetShape({
    required this.sheetId,
    required this.index,
    required this.title,
  });

  final int sheetId;
  final int index;
  final String title;
}

String _quotedSheetTitle(String title) {
  return "'${title.replaceAll("'", "''")}'";
}
