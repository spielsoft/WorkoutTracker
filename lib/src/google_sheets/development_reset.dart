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

class DevelopmentSheetResetTabRewritePlan {
  DevelopmentSheetResetTabRewritePlan({
    required int sheetId,
    required DevelopmentSheetResetTab tab,
    required int frozenRowCount,
  }) : requests = List<sheets.Request>.unmodifiable([
         sheets.Request(
           unmergeCells: sheets.UnmergeCellsRequest(
             range: sheets.GridRange(sheetId: sheetId),
           ),
         ),
         sheets.Request(
           updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
             properties: sheets.SheetProperties(
               sheetId: sheetId,
               gridProperties: sheets.GridProperties(
                 rowCount: _usableResetRowCount(tab),
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
               sheetId: sheetId,
               startRowIndex: 0,
               endRowIndex: _usableResetRowCount(tab),
               startColumnIndex: 0,
               endColumnIndex: tab.columnCount,
             ),
             cell: sheets.CellData(
               userEnteredFormat: sheets.CellFormat(
                 numberFormat: sheets.NumberFormat(type: 'TEXT'),
               ),
             ),
             fields: 'userEnteredFormat.numberFormat',
           ),
         ),
         sheets.Request(
           repeatCell: sheets.RepeatCellRequest(
             range: sheets.GridRange(
               sheetId: sheetId,
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
         sheets.Request(
           updateCells: sheets.UpdateCellsRequest(
             start: sheets.GridCoordinate(
               sheetId: sheetId,
               rowIndex: 0,
               columnIndex: 0,
             ),
             rows: _rowDataForReset(tab.rows),
             fields: 'userEnteredValue',
           ),
         ),
       ]);

  final List<sheets.Request> requests;
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
          '=Exercises!A4',
          '=Exercises!C4',
          '=Exercises!D4',
          '=Exercises!E4',
          '=Exercises!F4',
          '=Exercises!G4',
          '=Exercises!H4',
          'Legs',
          'TRUE',
          '',
          '',
          '24x10@7',
        ],
        [
          '=Exercises!A5',
          '=Exercises!C5',
          '=Exercises!D5',
          '=Exercises!E5',
          '=Exercises!F5',
          '=Exercises!G5',
          '=Exercises!H5',
          'Legs',
          'TRUE',
          '',
          '',
          '220x10@8',
        ],
        [
          '=Exercises!A6',
          '=Exercises!C6',
          '=Exercises!D6',
          '=Exercises!E6',
          '=Exercises!F6',
          '=Exercises!G6',
          '=Exercises!H6',
          'Legs',
          '',
          '155x8@8',
          '',
          '150x8@7',
        ],
        [
          '=Exercises!A7',
          '=Exercises!C7',
          '=Exercises!D7',
          '=Exercises!E7',
          '=Exercises!F7',
          '=Exercises!G7',
          '=Exercises!H7',
          'Legs',
          'TRUE',
          '',
          '',
          '',
        ],
        [
          '=Exercises!A8',
          '=Exercises!C8',
          '=Exercises!D8',
          '=Exercises!E8',
          '=Exercises!F8',
          '=Exercises!G8',
          '=Exercises!H8',
          'Legs',
          'TRUE',
          '',
          '',
          '',
        ],
        [
          '=Exercises!A9',
          '=Exercises!C9',
          '=Exercises!D9',
          '=Exercises!E9',
          '=Exercises!F9',
          '=Exercises!G9',
          '=Exercises!H9',
          'Legs',
          '',
          '',
          '',
          '145x15@8',
        ],
        [
          '=Exercises!A10',
          '=Exercises!C10',
          '=Exercises!D10',
          '=Exercises!E10',
          '=Exercises!F10',
          '=Exercises!G10',
          '=Exercises!H10',
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
          '=Exercises!A11',
          '=Exercises!C11',
          '=Exercises!D11',
          '=Exercises!E11',
          '=Exercises!F11',
          '=Exercises!G11',
          '=Exercises!H11',
          'Upper',
          '',
          '155x6@8',
          '',
          '150x6@8',
        ],
        [
          '=Exercises!A12',
          '=Exercises!C12',
          '=Exercises!D12',
          '=Exercises!E12',
          '=Exercises!F12',
          '=Exercises!G12',
          '=Exercises!H12',
          'Upper',
          'TRUE',
          '',
          '',
          '',
        ],
        [
          '=Exercises!A13',
          '=Exercises!C13',
          '=Exercises!D13',
          '=Exercises!E13',
          '=Exercises!F13',
          '=Exercises!G13',
          '=Exercises!H13',
          'Upper',
          'TRUE',
          '',
          '',
          '',
        ],
        [
          '=Exercises!A14',
          '=Exercises!C14',
          '=Exercises!D14',
          '=Exercises!E14',
          '=Exercises!F14',
          '=Exercises!G14',
          '=Exercises!H14',
          'Upper',
          'TRUE',
          '',
          '',
          '',
        ],
        [
          '=Exercises!A15',
          '=Exercises!C15',
          '=Exercises!D15',
          '=Exercises!E15',
          '=Exercises!F15',
          '=Exercises!G15',
          '=Exercises!H15',
          'Upper',
          '',
          '45s@8',
          '',
          '40s@8',
        ],
        [
          '=Exercises!A16',
          '=Exercises!C16',
          '=Exercises!D16',
          '=Exercises!E16',
          '=Exercises!F16',
          '=Exercises!G16',
          '=Exercises!H16',
          'Upper',
          'TRUE',
          '',
          '',
          '',
        ],
        [
          '=Exercises!A17',
          '=Exercises!C17',
          '=Exercises!D17',
          '=Exercises!E17',
          '=Exercises!F17',
          '=Exercises!G17',
          '=Exercises!H17',
          'Upper',
          'TRUE',
          '',
          '',
          '',
        ],
        [
          '=Exercises!A18',
          '=Exercises!C18',
          '=Exercises!D18',
          '=Exercises!E18',
          '=Exercises!F18',
          '=Exercises!G18',
          '=Exercises!H18',
          'Upper',
          '',
          '105x10@8',
          '',
          '100x10@8',
        ],
        [
          '=Exercises!A19',
          '=Exercises!C19',
          '=Exercises!D19',
          '=Exercises!E19',
          '=Exercises!F19',
          '=Exercises!G19',
          '=Exercises!H19',
          'Upper',
          'TRUE',
          '',
          '',
          '',
        ],
        [
          '=Exercises!A20',
          '=Exercises!C20',
          '=Exercises!D20',
          '=Exercises!E20',
          '=Exercises!F20',
          '=Exercises!G20',
          '=Exercises!H20',
          'Upper',
          'TRUE',
          '',
          '',
          '',
        ],
        [
          '=Exercises!A21',
          '=Exercises!C21',
          '=Exercises!D21',
          '=Exercises!E21',
          '=Exercises!F21',
          '=Exercises!G21',
          '=Exercises!H21',
          '',
          '',
          '',
          '',
          '50x40m@8',
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
          'Step-Up',
          'Dumbbell step-up',
          '3',
          '10/side',
          '8',
          '90s',
          '3-1-1',
          'Backup if split squat stations are crowded.',
        ],
        [
          'Leg Press',
          'Machine leg press',
          '3',
          '10',
          '8',
          '2 min',
          '',
          'Backup when unilateral work is not available.',
        ],
        [
          'Romanian Deadlift',
          'Barbell Romanian deadlift',
          '3',
          '8',
          '8',
          '2 min',
          '2-1-1',
          'Hinge at the hips and keep lats tight.',
        ],
        [
          'Dumbbell RDL',
          'Dumbbell Romanian deadlift',
          '3',
          '10',
          '8',
          '90s',
          '',
          'Backup hinge if racks are unavailable.',
        ],
        [
          'Hamstring Curl',
          'Seated or lying hamstring curl',
          '3',
          '12',
          '8',
          '90s',
          '',
          'Backup hinge pattern with less setup.',
        ],
        [
          'Standing Calf Raise',
          'Standing calf raise',
          '3',
          '12-15',
          '9',
          '60s',
          '2-1-1',
          'Pause at the bottom and top.',
        ],
        [
          'Seated Calf Raise',
          'Seated calf raise',
          '3',
          '12-15',
          '9',
          '60s',
          '2-1-1',
          'Backup calf raise station.',
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
          'Dumbbell Floor Press',
          'Dumbbell floor press',
          '4',
          '8',
          '8',
          '2 min',
          '',
          'Backup if benches are full.',
        ],
        [
          'Machine Chest Press',
          'Machine chest press',
          '4',
          '8',
          '8',
          '2 min',
          '',
          'Backup if free-weight pressing is busy.',
        ],
        [
          'Plank',
          'Front plank hold',
          '3',
          '45s',
          '8',
          '60s',
          '',
          'Brace hard and keep hips level.',
        ],
        [
          'Dead Bug',
          'Dead bug core drill',
          '3',
          '10/side',
          '7',
          '45s',
          '',
          'Backup core drill if planks are uncomfortable.',
        ],
        [
          'Side Plank',
          'Side plank hold',
          '3',
          '30s/side',
          '8',
          '45s',
          '',
          'Backup anti-lateral-flexion core drill.',
        ],
        [
          'Seated Cable Row',
          'Seated cable row',
          '3',
          '10',
          '8',
          '90s',
          '',
          'Pull elbows toward hips.',
        ],
        [
          'Chest-Supported Row',
          'Chest-supported dumbbell row',
          '3',
          '10',
          '8',
          '90s',
          '',
          'Backup row if cable station is busy.',
        ],
        [
          'Lat Pulldown',
          'Cable lat pulldown',
          '3',
          '10',
          '8',
          '90s',
          '',
          'Backup vertical pull option.',
        ],
        [
          'Farmer Carry',
          'Loaded carry',
          '3',
          '40m',
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
                rowCount: _usableResetRowCount(fixture.exercisesSheet),
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

    final plan = DevelopmentSheetResetTabRewritePlan(
      sheetId: target.sheetId,
      tab: tab,
      frozenRowCount: frozenRowCount,
    );

    await _api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: plan.requests),
      spreadsheetId,
      $fields: 'spreadsheetId',
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
}

List<sheets.RowData> _rowDataForReset(List<List<String>> rows) {
  return [
    for (final row in rows)
      sheets.RowData(
        values: [
          for (final value in row)
            sheets.CellData(userEnteredValue: _extendedValueForReset(value)),
        ],
      ),
  ];
}

sheets.ExtendedValue? _extendedValueForReset(String value) {
  if (value.isEmpty) {
    return null;
  }
  if (value.startsWith('=')) {
    return sheets.ExtendedValue(formulaValue: value);
  }
  return sheets.ExtendedValue(stringValue: value);
}

int _usableResetRowCount(DevelopmentSheetResetTab tab) {
  final minimumRows = tab.title == 'Exercises' ? 25 : 50;
  return tab.rows.length > minimumRows ? tab.rows.length : minimumRows;
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
