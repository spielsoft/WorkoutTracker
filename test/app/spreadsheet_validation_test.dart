import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  test(
    'explicit development credentials path is used before host ADC lookup',
    () async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'workout-tracker-credentials-test-',
      );
      addTearDown(() {
        tempDirectory.deleteSync(recursive: true);
      });
      final credentialsFile = File('${tempDirectory.path}/credentials.json')
        ..writeAsStringSync('[]');

      await expectLater(
        clientViaWorkoutTrackerDevelopmentCredentials(
          scopes: GoogleApisSheetsSpreadsheetClient.readOnlyScopes,
          credentialsPath: credentialsFile.path,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Google credentials file must contain a JSON object'),
          ),
        ),
      );
    },
  );

  test(
    'keeps the development auth client open until validation finishes',
    () async {
      final client = _CloseTrackingAuthClient();
      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [...activeSheetFixedColumns, 'Week 1'],
            [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
            ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', '', ''],
          ],
        ),
      );
      final service = AdcSpreadsheetValidationService(
        clientFactory: ({required scopes, required credentialsPath}) async {
          return client;
        },
        serviceFactory: (sheets.SheetsApi api, {required bool canWrite}) {
          return _DelayedValidationService(
            client: client,
            activeSheet: activeSheet,
          );
        },
      );

      await service.validateSpreadsheet('spreadsheet-id');

      expect(client.closedDuringAction, isFalse);
      expect(client.closed, isTrue);
    },
  );

  test(
    'keeps the development auth client open until history block creation finishes',
    () async {
      final client = _CloseTrackingAuthClient();
      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [...activeSheetFixedColumns, 'Week 1'],
            [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
            ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', '', ''],
          ],
        ),
      );
      final service = AdcSpreadsheetValidationService(
        clientFactory: ({required scopes, required credentialsPath}) async {
          return client;
        },
        serviceFactory: (sheets.SheetsApi api, {required bool canWrite}) {
          return _DelayedValidationService(
            client: client,
            activeSheet: activeSheet,
          );
        },
      );

      await service.createHistoryBlock(
        spreadsheetId: 'spreadsheet-id',
        label: 'Week 2',
        activeSheet: activeSheet,
      );

      expect(client.closedDuringAction, isFalse);
      expect(client.closed, isTrue);
    },
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

class _CloseTrackingAuthClient extends http.BaseClient
    implements auth.AutoRefreshingAuthClient {
  bool closed = false;
  bool closedDuringAction = false;

  @override
  auth.AccessCredentials get credentials {
    throw UnimplementedError();
  }

  @override
  Stream<auth.AccessCredentials> get credentialUpdates {
    return const Stream.empty();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }

  @override
  void close() {
    closed = true;
  }
}
