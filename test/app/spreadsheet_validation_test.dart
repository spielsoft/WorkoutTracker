import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  test(
    'native Google sign-in validation uses read-only Sheets authorization',
    () async {
      final gateway = _RecordingGoogleSignInAuthorizationGateway();
      final activeSheet = _minimalParsedActiveSheet();
      bool? requestedWriteAccess;
      final authClient = _CloseTrackingAuthClient();
      final service = GoogleSignInSpreadsheetValidationService(
        authorizationGateway: gateway,
        authorizationClientFactory: (_) => authClient,
        serviceFactory: (sheets.SheetsApi api, {required bool canWrite}) {
          requestedWriteAccess = canWrite;
          return _DelayedValidationService(
            client: authClient,
            activeSheet: activeSheet,
          );
        },
      );

      await service.validateSpreadsheet('spreadsheet-id');

      expect(authClient.closedDuringAction, isFalse);
      expect(authClient.closed, isTrue);
      expect(gateway.requestedScopes.single, [
        sheets.SheetsApi.spreadsheetsReadonlyScope,
      ]);
      expect(requestedWriteAccess, isFalse);
    },
  );

  test(
    'native Google sign-in history block creation requests write authorization',
    () async {
      final gateway = _RecordingGoogleSignInAuthorizationGateway();
      final activeSheet = _minimalParsedActiveSheet();
      bool? requestedWriteAccess;
      final service = GoogleSignInSpreadsheetValidationService(
        authorizationGateway: gateway,
        serviceFactory: (sheets.SheetsApi api, {required bool canWrite}) {
          requestedWriteAccess = canWrite;
          return _DelayedValidationService(
            client: _CloseTrackingAuthClient(),
            activeSheet: activeSheet,
          );
        },
      );

      await service.applyActiveSheetWritePlan(
        spreadsheetId: 'spreadsheet-id',
        activeSheet: activeSheet,
        plan: activeSheet.planNewHistoryBlock(label: 'Week 2'),
      );

      expect(gateway.requestedScopes.single, [
        sheets.SheetsApi.spreadsheetsScope,
      ]);
      expect(requestedWriteAccess, isTrue);
    },
  );

  test(
    'rejects a set write when the current row identity no longer matches the visible target',
    () async {
      final staleRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ];
      final changedRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Deadlift', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ];
      final readClient = _SequencedSpreadsheetClient([
        _snapshot(staleRows),
        _snapshot(changedRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = GoogleSpreadsheetValidationService(
        readAdapter: GoogleSheetsReadAdapter(client: readClient),
        writeAdapter: GoogleSheetsWriteAdapter(client: writeClient),
      );

      final report = await service.validateSpreadsheet('spreadsheet-id');
      final plan = report.activeSheet.planSetLoggingWrite(
        historyBlockLabel: 'Week 1',
        sheetRowNumber: 3,
        fieldValues: const {'Weight': '225', 'Reps': '5', 'RPE': '8'},
      );

      final rejected = await service.applyActiveSheetWritePlan(
        spreadsheetId: 'spreadsheet-id',
        activeSheet: report.activeSheet,
        plan: plan,
      );

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.single.problem,
        contains('Row 3 no longer matches Squat'),
      );
      expect(writeClient.writeCount, 0);
    },
  );

  test(
    'rejects a new set save when the visible empty target cell changed before apply',
    () async {
      final staleRows = [
        [...activeSheetFixedColumns, 'Week 1', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          '',
          '',
          'Legs',
          '',
          '225x5@8',
          '',
        ],
      ];
      final changedRows = [
        [...activeSheetFixedColumns, 'Week 1', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          '',
          '',
          'Legs',
          '',
          '225x5@8',
          '230x5@8',
        ],
      ];
      final readClient = _SequencedSpreadsheetClient([
        _snapshot(staleRows),
        _snapshot(changedRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = GoogleSpreadsheetValidationService(
        readAdapter: GoogleSheetsReadAdapter(client: readClient),
        writeAdapter: GoogleSheetsWriteAdapter(client: writeClient),
      );

      final report = await service.validateSpreadsheet('spreadsheet-id');
      final plan = report.activeSheet.planSetLoggingWrite(
        historyBlockLabel: 'Week 1',
        sheetRowNumber: 3,
        fieldValues: const {'Weight': '230', 'Reps': '5', 'RPE': '8'},
      );

      final rejected = await service.applyActiveSheetWritePlan(
        spreadsheetId: 'spreadsheet-id',
        activeSheet: report.activeSheet,
        plan: plan,
      );

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.single.problem,
        contains('Cell row 3 column 12 no longer matches'),
      );
      expect(writeClient.writeCount, 0);
    },
  );

  test(
    'rejects a set write when workout or backup state changed before apply',
    () async {
      final staleRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ];
      final changedRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Upper', 'TRUE', ''],
      ];
      final readClient = _SequencedSpreadsheetClient([
        _snapshot(staleRows),
        _snapshot(changedRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = GoogleSpreadsheetValidationService(
        readAdapter: GoogleSheetsReadAdapter(client: readClient),
        writeAdapter: GoogleSheetsWriteAdapter(client: writeClient),
      );

      final report = await service.validateSpreadsheet('spreadsheet-id');
      final plan = report.activeSheet.planSetLoggingWrite(
        historyBlockLabel: 'Week 1',
        sheetRowNumber: 3,
        fieldValues: const {'Weight': '225', 'Reps': '5', 'RPE': '8'},
      );

      final rejected = await service.applyActiveSheetWritePlan(
        spreadsheetId: 'spreadsheet-id',
        activeSheet: report.activeSheet,
        plan: plan,
      );

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.map((item) => item.problem),
        contains(contains('Row 3 no longer matches Squat')),
      );
      expect(writeClient.writeCount, 0);
    },
  );

  test(
    'rejects an edit or clear when the visible set column no longer exists',
    () async {
      final staleRows = [
        [...activeSheetFixedColumns, 'Week 1', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          '',
          '',
          'Legs',
          '',
          '225x5@8',
          '230x5@8',
        ],
      ];
      final changedRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '225x5@8'],
      ];
      final readClient = _SequencedSpreadsheetClient([
        _snapshot(staleRows),
        _snapshot(changedRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = GoogleSpreadsheetValidationService(
        readAdapter: GoogleSheetsReadAdapter(client: readClient),
        writeAdapter: GoogleSheetsWriteAdapter(client: writeClient),
      );

      final report = await service.validateSpreadsheet('spreadsheet-id');
      final plan = report.activeSheet.planSetClear(
        historyBlockLabel: 'Week 1',
        sheetRowNumber: 3,
        setNumber: 2,
      );

      final rejected = await service.applyActiveSheetWritePlan(
        spreadsheetId: 'spreadsheet-id',
        activeSheet: report.activeSheet,
        plan: plan,
      );

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.map((item) => item.problem),
        contains(contains('Set column Week 1 S2 no longer exists')),
      );
      expect(writeClient.writeCount, 0);
    },
  );

  test(
    'rejects history block insertion when the header insertion point changed before apply',
    () async {
      final staleRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ];
      final changedRows = [
        [...activeSheetFixedColumns, 'Unexpected', 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '', ''],
      ];
      final readClient = _SequencedSpreadsheetClient([
        _snapshot(staleRows),
        _snapshot(changedRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = GoogleSpreadsheetValidationService(
        readAdapter: GoogleSheetsReadAdapter(client: readClient),
        writeAdapter: GoogleSheetsWriteAdapter(client: writeClient),
      );

      final report = await service.validateSpreadsheet('spreadsheet-id');
      final plan = report.activeSheet.planNewHistoryBlock(label: 'Week 2');

      final rejected = await service.applyActiveSheetWritePlan(
        spreadsheetId: 'spreadsheet-id',
        activeSheet: report.activeSheet,
        plan: plan,
      );

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.single.problem,
        contains('History insertion point at column 11 no longer matches'),
      );
      expect(writeClient.writeCount, 0);
    },
  );

  test(
    'rejects history block growth when the selected block changed before apply',
    () async {
      final staleRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '225x5@8'],
      ];
      final changedRows = [
        [...activeSheetFixedColumns, 'Renamed'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '225x5@8'],
      ];
      final readClient = _SequencedSpreadsheetClient([
        _snapshot(staleRows),
        _snapshot(changedRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = GoogleSpreadsheetValidationService(
        readAdapter: GoogleSheetsReadAdapter(client: readClient),
        writeAdapter: GoogleSheetsWriteAdapter(client: writeClient),
      );

      final report = await service.validateSpreadsheet('spreadsheet-id');
      final plan = report.activeSheet.planSetLoggingWrite(
        historyBlockLabel: 'Week 1',
        sheetRowNumber: 3,
        fieldValues: const {'Weight': '230', 'Reps': '5', 'RPE': '8'},
      );

      final rejected = await service.applyActiveSheetWritePlan(
        spreadsheetId: 'spreadsheet-id',
        activeSheet: report.activeSheet,
        plan: plan,
      );

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.map((item) => item.problem),
        contains(contains('Set column Week 1 S1 no longer exists')),
      );
      expect(writeClient.writeCount, 0);
    },
  );
}

ParsedActiveSheet _minimalParsedActiveSheet() {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ],
    ),
  );
}

GoogleSpreadsheetSnapshot _snapshot(List<List<String>> rows) {
  return GoogleSpreadsheetSnapshot(
    sheets: [GoogleSheetSnapshot(title: 'Active Workout', rows: rows)],
  );
}

class _SequencedSpreadsheetClient implements GoogleSheetsSpreadsheetClient {
  _SequencedSpreadsheetClient(this.snapshots);

  final List<GoogleSpreadsheetSnapshot> snapshots;
  var _nextSnapshot = 0;

  @override
  Future<GoogleSpreadsheetSnapshot> fetchSpreadsheet(
    String spreadsheetId,
  ) async {
    if (_nextSnapshot >= snapshots.length) {
      return snapshots.last;
    }
    return snapshots[_nextSnapshot++];
  }
}

class _RecordingWriteClient implements GoogleSheetsWriteClient {
  var writeCount = 0;

  @override
  Future<GoogleSheetsActiveSheetTarget> fetchActiveSheetTarget(
    String spreadsheetId,
  ) async {
    return const GoogleSheetsActiveSheetTarget(
      sheetId: 42,
      title: 'Active Workout',
    );
  }

  @override
  Future<void> insertColumns({
    required String spreadsheetId,
    required int sheetId,
    required int sheetColumnNumber,
    required int columnCount,
  }) async {
    writeCount += 1;
  }

  @override
  Future<void> insertRows({
    required String spreadsheetId,
    required int sheetId,
    required int sheetRowNumber,
    required int rowCount,
  }) async {
    writeCount += rowCount;
  }

  @override
  Future<void> writeCells({
    required String spreadsheetId,
    required String sheetTitle,
    required Iterable<GoogleSheetsCellWrite> cells,
    required GoogleSheetsValueInputMode mode,
  }) async {
    writeCount += cells.length;
  }

  @override
  Future<void> clearCells({
    required String spreadsheetId,
    required String sheetTitle,
    required Iterable<GoogleSheetsCellClear> cells,
  }) async {
    writeCount += cells.length;
  }
}

class _DelayedValidationService implements SpreadsheetValidationService {
  _DelayedValidationService({required this.client, required this.activeSheet});

  final _CloseTrackingAuthClient client;
  final ParsedActiveSheet activeSheet;

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    await _expectClientStillOpen();
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    await _expectClientStillOpen();
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: this.activeSheet,
    );
  }

  Future<void> _expectClientStillOpen() async {
    await Future<void>.delayed(Duration.zero);
    if (client.closed) {
      client.closedDuringAction = true;
    }
  }
}

class _CloseTrackingAuthClient extends http.BaseClient {
  bool closed = false;
  bool closedDuringAction = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }

  @override
  void close() {
    closed = true;
  }
}

class _RecordingGoogleSignInAuthorizationGateway extends ChangeNotifier
    implements GoogleSignInAuthorizationGateway {
  final List<List<String>> requestedScopes = [];

  @override
  GoogleAccountProfile? get currentAccount => null;

  @override
  Future<void> restoreAccount() async {}

  @override
  Future<void> switchAccount({List<String> scopes = const []}) async {}

  @override
  Future<Map<String, String>> authorizationHeaders(List<String> scopes) async {
    requestedScopes.add(scopes);
    return const {'Authorization': 'Bearer test-token'};
  }
}
