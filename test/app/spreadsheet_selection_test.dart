import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  test('selected spreadsheet encodes display metadata separately from ID', () {
    const selected = SelectedSpreadsheet(
      spreadsheetId: 'spreadsheet-id',
      name: '2026 Workouts',
      drivePath: 'My Drive / Workouts / 2026 Workouts',
      webViewLink: 'https://docs.google.com/spreadsheets/d/spreadsheet-id',
      accountEmail: 'user@example.com',
    );

    final decoded = decodeSelectedSpreadsheet(
      encodeSelectedSpreadsheet(selected),
    );

    expect(decoded?.spreadsheetId, 'spreadsheet-id');
    expect(decoded?.displayLabel, 'My Drive / Workouts / 2026 Workouts');
    expect(decoded?.accountEmail, 'user@example.com');
  });

  test(
    'disabled spreadsheet picker reports both actions unavailable',
    () async {
      const picker = DisabledSpreadsheetPicker(reason: 'Selection disabled.');

      expect(picker.availability.canChoose, isFalse);
      expect(picker.availability.canCreate, isFalse);
      expect(picker.availability.summary, 'Selection disabled.');
      await expectLater(picker.chooseSpreadsheet(), throwsA(isA<StateError>()));
      await expectLater(picker.createSpreadsheet(), throwsA(isA<StateError>()));
    },
  );

  test('production picker client ID enables app builds', () {
    expect(workoutTrackerGooglePickerClientId, isNotEmpty);
    expect(MobileGoogleDriveSpreadsheetPicker().availability.canChoose, isTrue);
  });

  test(
    'created spreadsheets are initialized as WorkoutTracker workbooks',
    () async {
      final gateway = _RecordingAuthorizationGateway();
      final client = _CreateSpreadsheetClient();
      final initializer = _RecordingWorkbookInitializer();
      final creator = GoogleSheetsSpreadsheetCreator(
        authorizationGateway: gateway,
        authorizationClientFactory: (_) => client,
        titleFactory: () => ' New Workout Book ',
        workbookInitializerFactory: (_) => initializer,
      );

      final selected = await creator.createWorkoutSpreadsheet();

      expect(
        gateway.requestedScopes.single,
        GoogleApisWorkoutTrackerWorkbookInitializer.writeScopes,
      );
      expect(client.createRequestTitles, ['New Workout Book']);
      expect(initializer.initializedSpreadsheetIds, ['created-spreadsheet-id']);
      final workbook = initializer.workbooks.single;
      expect(workbook.activeSheet.title, 'Active Workout');
      expect(workbook.exercisesSheet.title, 'Exercises');
      expect(selected.spreadsheetId, 'created-spreadsheet-id');
      expect(selected.name, 'New Workout Book');
      expect(selected.accountEmail, 'user@example.com');
      expect(client.isClosed, isTrue);
    },
  );

  test(
    'selected spreadsheet metadata resolution uses writable Sheets authorization',
    () async {
      final gateway = _RecordingAuthorizationGateway();
      final client = _GetSpreadsheetClient();
      final picker = MobileGoogleDriveSpreadsheetPicker(
        clientId: 'client-id.apps.googleusercontent.com',
        authorizationGateway: gateway,
        authorizationClientFactory: (_) => client,
      );

      final selected = await picker.resolveSelectedSpreadsheet(
        const SelectedSpreadsheet(
          spreadsheetId: 'picked-spreadsheet-id',
          name: 'picked-spreadsheet-id',
        ),
      );

      expect(gateway.requestedScopes.single, [
        GoogleApisSheetsWriteClient.writeScopes.single,
      ]);
      expect(selected.spreadsheetId, 'picked-spreadsheet-id');
      expect(selected.name, 'Picked Workout Book');
      expect(selected.accountEmail, 'user@example.com');
      expect(client.isClosed, isTrue);
    },
  );

  test(
    'google picker authorization URL carries callback path and request state',
    () {
      final authorizationUrl =
          MobileGoogleDriveSpreadsheetPicker.googlePickerAuthorizationUrl(
            clientId: 'client-id.apps.googleusercontent.com',
            redirectUri: Uri.parse(
              'http://localhost:1234/google-picker-callback',
            ),
            state: 'request-state',
          );

      expect(authorizationUrl.host, 'accounts.google.com');
      expect(
        authorizationUrl.queryParameters['redirect_uri'],
        'http://localhost:1234/google-picker-callback',
      );
      expect(authorizationUrl.queryParameters['state'], 'request-state');
    },
  );

  test('google picker callback accepts only matching path and state', () {
    final accepted = validateGooglePickerLoopbackCallback(
      Uri.parse(
        'http://localhost:1234/google-picker-callback'
        '?state=request-state&picked_file_ids=first,%20second',
      ),
      expectedState: 'request-state',
    );

    expect(accepted.result?.pickedSpreadsheetIds, ['first', 'second']);
    expect(accepted.errorMessage, isNull);

    final wrongPath = validateGooglePickerLoopbackCallback(
      Uri.parse(
        'http://localhost:1234/'
        '?state=request-state&picked_file_ids=spreadsheet-id',
      ),
      expectedState: 'request-state',
    );
    expect(wrongPath.result, isNull);
    expect(wrongPath.statusCode, HttpStatus.notFound);
    expect(wrongPath.errorMessage, contains('/google-picker-callback'));

    final wrongState = validateGooglePickerLoopbackCallback(
      Uri.parse(
        'http://localhost:1234/google-picker-callback'
        '?state=other-state&picked_file_ids=spreadsheet-id',
      ),
      expectedState: 'request-state',
    );
    expect(wrongState.result, isNull);
    expect(wrongState.statusCode, HttpStatus.badRequest);
    expect(wrongState.errorMessage, contains('state'));

    final missingState = validateGooglePickerLoopbackCallback(
      Uri.parse(
        'http://localhost:1234/google-picker-callback'
        '?picked_file_ids=spreadsheet-id',
      ),
      expectedState: 'request-state',
    );
    expect(missingState.result, isNull);
    expect(missingState.statusCode, HttpStatus.badRequest);
    expect(missingState.errorMessage, contains('missing request state'));
  });
}

class _RecordingAuthorizationGateway extends ChangeNotifier
    implements GoogleSignInAuthorizationGateway {
  final requestedScopes = <List<String>>[];

  @override
  GoogleAccountProfile? get currentAccount {
    return const GoogleAccountProfile(email: 'user@example.com');
  }

  @override
  Future<Map<String, String>> authorizationHeaders(List<String> scopes) async {
    requestedScopes.add(List<String>.unmodifiable(scopes));
    return const {'Authorization': 'Bearer token'};
  }

  @override
  Future<void> restoreAccount() async {}

  @override
  Future<void> switchAccount({List<String> scopes = const []}) async {}
}

class _RecordingWorkbookInitializer
    implements WorkoutTrackerWorkbookInitializer {
  final initializedSpreadsheetIds = <String>[];
  final workbooks = <WorkoutTrackerWorkbook>[];

  @override
  Future<void> initializeWorkbook({
    required String spreadsheetId,
    required WorkoutTrackerWorkbook workbook,
  }) async {
    initializedSpreadsheetIds.add(spreadsheetId);
    workbooks.add(workbook);
  }
}

class _CreateSpreadsheetClient extends http.BaseClient {
  final createRequestTitles = <String>[];
  var isClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'POST' ||
        !request.url.path.endsWith('/spreadsheets')) {
      throw StateError(
        'Unexpected request: ${request.runtimeType} '
        '${request.method} ${request.url}',
      );
    }

    final body = utf8.decode(await request.finalize().toBytes());
    final decoded = jsonDecode(body) as Map<String, Object?>;
    final properties = decoded['properties'] as Map<String, Object?>;
    createRequestTitles.add(properties['title']! as String);

    return http.StreamedResponse(
      Stream<List<int>>.value(
        utf8.encode(
          jsonEncode({
            'spreadsheetId': 'created-spreadsheet-id',
            'spreadsheetUrl':
                'https://docs.google.com/spreadsheets/d/created-spreadsheet-id/edit',
            'properties': {'title': properties['title']},
          }),
        ),
      ),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }

  @override
  void close() {
    isClosed = true;
    super.close();
  }
}

class _GetSpreadsheetClient extends http.BaseClient {
  var isClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET' ||
        !request.url.path.endsWith('/spreadsheets/picked-spreadsheet-id')) {
      throw StateError(
        'Unexpected request: ${request.runtimeType} '
        '${request.method} ${request.url}',
      );
    }

    return http.StreamedResponse(
      Stream<List<int>>.value(
        utf8.encode(
          jsonEncode({
            'spreadsheetId': 'picked-spreadsheet-id',
            'spreadsheetUrl':
                'https://docs.google.com/spreadsheets/d/picked-spreadsheet-id/edit',
            'properties': {'title': 'Picked Workout Book'},
          }),
        ),
      ),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }

  @override
  void close() {
    isClosed = true;
    super.close();
  }
}
