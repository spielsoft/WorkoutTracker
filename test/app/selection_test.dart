import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/sheets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'disabled spreadsheet picker reports both actions unavailable',
    () async {
      const picker = DisabledPicker(reason: 'Selection disabled.');

      expect(picker.availability.canChoose, isFalse);
      expect(picker.availability.canCreate, isFalse);
      expect(picker.availability.summary, 'Selection disabled.');
      await expectLater(picker.chooseSheet(), throwsA(isA<StateError>()));
      await expectLater(picker.createSheet(), throwsA(isA<StateError>()));
    },
  );

  test('drive picker keeps sheet choice available without sheet creation', () {
    final picker = DriveSheetPicker(
      googleAccess: _RecordingApiAccess(_DriveListClient(files: const [])),
      showPicker: (_) async => null,
    );

    expect(picker.availability.canChoose, isTrue);
    expect(picker.availability.canCreate, isFalse);
    expect(
      picker.availability.createReason,
      'Google Drive sheet creation is not connected yet.',
    );
  });

  test(
    'connected drive picker searches sheets without another login',
    () async {
      final client = _DriveListClient(
        files: const [
          {
            'id': 'spreadsheet-id',
            'name': 'Morning Log',
            'webViewLink':
                'https://docs.google.com/spreadsheets/d/spreadsheet-id/edit',
            'owners': [
              {'displayName': 'Athlete', 'emailAddress': 'athlete@example.com'},
            ],
            'modifiedTime': '2026-07-06T10:00:00.000Z',
            'viewedByMeTime': '2026-07-06T11:00:00.000Z',
          },
        ],
      );
      final access = _RecordingApiAccess(
        client,
        account: const GoogleAccountProfile(email: 'athlete@example.com'),
      );
      SheetViewReq? req;
      final picker = DriveSheetPicker(
        googleAccess: access,
        showPicker: (pickedReq) async {
          req = pickedReq;
          final matches = await pickedReq.load('morning log');
          expect(matches.single.name, 'Morning Log');
          return matches.single;
        },
      );

      final selected = await picker.chooseSheet();

      expect(req?.accountEmail, 'athlete@example.com');
      expect(access.requestedScopes.single, [driveMetaScope]);
      expect(
        client.requests.single.queryParameters['q'],
        "mimeType = 'application/vnd.google-apps.spreadsheet' and "
        "trashed = false and "
        "name contains 'morning' and "
        "name contains 'log'",
      );
      expect(client.requests.single.queryParameters['orderBy'], 'name_natural');
      expect(client.requests.single.queryParameters['pageSize'], '50');
      expect(selected?.id, 'spreadsheet-id');
      expect(selected?.name, 'Morning Log');
      expect(selected?.accountEmail, 'athlete@example.com');
    },
  );

  test('drive picker loads recent Google Sheets for an empty query', () async {
    final client = _DriveListClient(
      files: const [
        {
          'id': 'recent-sheet-id',
          'name': 'Training Log',
          'webViewLink':
              'https://docs.google.com/spreadsheets/d/recent-sheet-id/edit',
        },
      ],
    );
    final access = _RecordingApiAccess(client);
    final picker = DriveSheetPicker(
      googleAccess: access,
      showPicker: (req) async {
        final recent = await req.load('');
        expect(recent.single.name, 'Training Log');
        return null;
      },
    );

    final selected = await picker.chooseSheet();

    expect(selected, isNull);
    expect(access.requestedScopes.single, [driveMetaScope]);
    expect(
      client.requests.single.queryParameters['q'],
      "mimeType = 'application/vnd.google-apps.spreadsheet' and "
      'trashed = false',
    );
    expect(
      client.requests.single.queryParameters['orderBy'],
      'viewedByMeTime desc,modifiedTime desc,name_natural',
    );
    expect(client.requests.single.queryParameters['pageSize'], '25');
  });

  test(
    'Google Sheets creator runs workbook creation through scoped Sheets access',
    () async {
      final client = _SheetsCreateClient();
      final access = _RecordingApiAccess(client);
      final initializer = _RecordingWbkInit(client);
      final creator = SheetCreator(
        googleAccess: access,
        initFactory: (_) => initializer,
        titleFactory: () => 'Workout Log',
      );

      final selected = await creator.createSheet();

      expect(access.requestedScopes.single, [
        sheets.SheetsApi.spreadsheetsScope,
      ]);
      expect(initializer.initializedSpreadsheetIds, ['created-spreadsheet-id']);
      expect(initializer.clientWasOpenDuringInitialization, isTrue);
      expect(client.closed, isTrue);
      expect(selected.id, 'created-spreadsheet-id');
      expect(selected.name, 'Workout Log');
    },
  );
}

class _RecordingApiAccess implements ApiAccess {
  _RecordingApiAccess(this.client, {this.account});

  final http.Client client;
  @override
  final GoogleAccountProfile? account;
  final List<List<String>> requestedScopes = [];

  @override
  Future<T> run<T>({
    required List<String> scopes,
    required Future<T> Function(ApiResources resources) action,
  }) async {
    requestedScopes.add(scopes);
    try {
      return await action(ApiResources(client));
    } finally {
      client.close();
    }
  }
}

class _DriveListClient extends http.BaseClient {
  _DriveListClient({required this.files});

  final List<Map<String, Object?>> files;
  final List<Uri> requests = [];
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (closed) {
      throw StateError('Client was closed before the Drive action finished.');
    }
    requests.add(request.url);
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'files': files}))),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

class _SheetsCreateClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (closed) {
      throw StateError('Client was closed before the Google action finished.');
    }
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'spreadsheetId': 'created-spreadsheet-id',
            'spreadsheetUrl':
                'https://docs.google.com/spreadsheets/d/created-spreadsheet-id/edit',
            'properties': {'title': 'Workout Log'},
          }),
        ),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

class _RecordingWbkInit implements WbkInit {
  _RecordingWbkInit(this.client);

  final _SheetsCreateClient client;
  final List<String> initializedSpreadsheetIds = [];
  bool clientWasOpenDuringInitialization = false;

  @override
  Future<void> initializeWorkbook({
    required String spreadsheetId,
    required Wbk workbook,
  }) async {
    initializedSpreadsheetIds.add(spreadsheetId);
    clientWasOpenDuringInitialization = !client.closed;
  }
}
