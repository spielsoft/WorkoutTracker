import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  test(
    'native Google sign-in validation uses the app-wide Sheets authorization',
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
        sheets.SheetsApi.spreadsheetsScope,
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

      await service.createHistoryBlock(
        spreadsheetId: 'spreadsheet-id',
        label: 'Week 2',
        activeSheet: activeSheet,
      );

      expect(gateway.requestedScopes.single, [
        sheets.SheetsApi.spreadsheetsScope,
      ]);
      expect(requestedWriteAccess, isTrue);
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
  Future<SpreadsheetValidationReport> createHistoryBlock({
    required String spreadsheetId,
    required String label,
    required ParsedActiveSheet activeSheet,
  }) async {
    await _expectClientStillOpen();
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: this.activeSheet,
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
