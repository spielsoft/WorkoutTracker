import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:workout_tracker/google_sheets.dart';

void main() {
  test(
    'converts one-based row and column deletes into Google dimension requests',
    () async {
      final httpClient = _RecordingHttpClient();
      final workbook = GoogleApisSheetsWorkbookClient(
        sheets.SheetsApi(httpClient),
      );
      const activeSheet = SheetsSheetIdentity(sheetId: 42, title: 'Workout');

      await workbook.applyOperations(
        spreadsheetId: 'spreadsheet-id',
        operations: const [
          SheetsRowDeletion(sheet: activeSheet, sheetRowNumber: 4, rowCount: 2),
          SheetsColumnDeletion(
            sheet: activeSheet,
            sheetColumnNumber: 11,
            columnCount: 3,
          ),
        ],
      );

      expect(httpClient.requests, hasLength(1));
      expect(httpClient.requests.single.url.path, endsWith(':batchUpdate'));
      expect(jsonDecode(httpClient.requests.single.body), {
        'requests': [
          {
            'deleteDimension': {
              'range': {
                'sheetId': 42,
                'dimension': 'ROWS',
                'startIndex': 3,
                'endIndex': 5,
              },
            },
          },
          {
            'deleteDimension': {
              'range': {
                'sheetId': 42,
                'dimension': 'COLUMNS',
                'startIndex': 10,
                'endIndex': 13,
              },
            },
          },
        ],
      });
    },
  );

  test(
    'converts one-based row and column moves into Google dimension requests',
    () async {
      final httpClient = _RecordingHttpClient();
      final workbook = GoogleApisSheetsWorkbookClient(
        sheets.SheetsApi(httpClient),
      );
      const activeSheet = SheetsSheetIdentity(sheetId: 42, title: 'Workout');

      await workbook.applyOperations(
        spreadsheetId: 'spreadsheet-id',
        operations: const [
          SheetsRowMove(
            sheet: activeSheet,
            sourceSheetRowNumber: 5,
            rowCount: 2,
            destinationSheetRowNumber: 10,
          ),
          SheetsColumnMove(
            sheet: activeSheet,
            sourceSheetColumnNumber: 3,
            columnCount: 4,
            destinationSheetColumnNumber: 12,
          ),
        ],
      );

      expect(httpClient.requests, hasLength(1));
      expect(jsonDecode(httpClient.requests.single.body), {
        'requests': [
          {
            'moveDimension': {
              'source': {
                'sheetId': 42,
                'dimension': 'ROWS',
                'startIndex': 4,
                'endIndex': 6,
              },
              'destinationIndex': 9,
            },
          },
          {
            'moveDimension': {
              'source': {
                'sheetId': 42,
                'dimension': 'COLUMNS',
                'startIndex': 2,
                'endIndex': 6,
              },
              'destinationIndex': 11,
            },
          },
        ],
      });
    },
  );

  test('does not call Google for empty operation batches', () async {
    final httpClient = _RecordingHttpClient();
    final workbook = GoogleApisSheetsWorkbookClient(
      sheets.SheetsApi(httpClient),
    );

    await workbook.applyOperations(
      spreadsheetId: 'spreadsheet-id',
      operations: const [],
    );

    expect(httpClient.requests, isEmpty);
  });
}

class _RecordingHttpClient extends http.BaseClient {
  final requests = <_RecordedRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().bytesToString();
    requests.add(_RecordedRequest(url: request.url, body: body));
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([
        utf8.encode('{"spreadsheetId":"spreadsheet-id"}'),
      ]),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _RecordedRequest {
  const _RecordedRequest({required this.url, required this.body});

  final Uri url;
  final String body;
}
