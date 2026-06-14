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
    'runtime credential environment is used before host ADC lookup',
    () async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'workout-tracker-runtime-credentials-test-',
      );
      addTearDown(() {
        tempDirectory.deleteSync(recursive: true);
      });
      final credentialsFile = File('${tempDirectory.path}/credentials.json')
        ..writeAsStringSync('[]');

      await expectLater(
        clientViaWorkoutTrackerDevelopmentCredentials(
          scopes: GoogleApisSheetsSpreadsheetClient.readOnlyScopes,
          environment: {
            workoutTrackerDevelopmentCredentialsDartDefine:
                credentialsFile.path,
          },
          applicationDefaultClientFactory: ({required scopes}) {
            throw StateError('host ADC should not be used');
          },
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
    'standard gcloud ADC file is used before metadata-server ADC lookup',
    () async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'workout-tracker-well-known-credentials-test-',
      );
      addTearDown(() {
        tempDirectory.deleteSync(recursive: true);
      });
      final credentialsFile =
          File(
              '${tempDirectory.path}/.config/gcloud/'
              'application_default_credentials.json',
            )
            ..createSync(recursive: true)
            ..writeAsStringSync('[]');

      await expectLater(
        clientViaWorkoutTrackerDevelopmentCredentials(
          scopes: GoogleApisSheetsSpreadsheetClient.readOnlyScopes,
          environment: {'HOME': tempDirectory.path},
          applicationDefaultClientFactory: ({required scopes}) {
            throw StateError('metadata ADC should not be used');
          },
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains(credentialsFile.path),
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

  test(
    'native Google sign-in validation requests read-only Sheets authorization',
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

      await service.validateSpreadsheet('spreadsheet-id');

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
        ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', '', ''],
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

class _RecordingGoogleSignInAuthorizationGateway
    implements GoogleSignInAuthorizationGateway {
  final List<List<String>> requestedScopes = [];

  @override
  Future<Map<String, String>> authorizationHeaders(List<String> scopes) async {
    requestedScopes.add(scopes);
    return const {'Authorization': 'Bearer test-token'};
  }
}
