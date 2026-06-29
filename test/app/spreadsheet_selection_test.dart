import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
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
    expect(
      MobileGoogleDriveSpreadsheetPicker(
        callbackReceiverFactory: _unusedCallbackReceiverFactory,
      ).availability.canChoose,
      isTrue,
    );
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

      final selected = await creator.createWorkoutSpreadsheet(
        name: ' User Named Workout Book ',
      );

      expect(
        gateway.requestedScopes.single,
        GoogleApisWorkoutTrackerWorkbookInitializer.writeScopes,
      );
      expect(client.createRequestTitles, ['User Named Workout Book']);
      expect(initializer.initializedSpreadsheetIds, ['created-spreadsheet-id']);
      final workbook = initializer.workbooks.single;
      expect(workbook.activeSheet.title, 'Active Workout');
      expect(workbook.exercisesSheet.title, 'Exercises');
      expect(workbook.activeSheet.rows, [activeSheetFixedColumns]);
      expect(
        workbook.exercisesSheet.rows.skip(1).map((row) => row.first),
        containsAll([
          'Bulgarian Split Squat',
          'Romanian Deadlift',
          'Standing Calf Raise',
        ]),
      );
      expect(selected.spreadsheetId, 'created-spreadsheet-id');
      expect(selected.name, 'User Named Workout Book');
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
        callbackReceiverFactory: _unusedCallbackReceiverFactory,
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
            redirectUri: workoutTrackerGooglePickerHostedCallbackUri,
            state: 'request-state',
          );

      expect(authorizationUrl.host, 'accounts.google.com');
      expect(
        authorizationUrl.queryParameters['redirect_uri'],
        workoutTrackerGooglePickerHostedCallbackUri.toString(),
      );
      expect(authorizationUrl.queryParameters['state'], 'request-state');
    },
  );

  test(
    'hosted picker flow returns selected spreadsheet through app-owned URI',
    () async {
      final previousLauncher = UrlLauncherPlatform.instance;
      final nativeLinks = StreamController<Uri>();
      final launcher = _CompletingHostedGooglePickerLauncher(nativeLinks);
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() async {
        UrlLauncherPlatform.instance = previousLauncher;
        await nativeLinks.close();
      });

      final selected = await MobileGoogleDriveSpreadsheetPicker(
        clientId: 'client-id.apps.googleusercontent.com',
        callbackReceiverFactory: ({required state, required timeout}) async {
          return NativeGooglePickerCallbackReceiver(
            state: state,
            timeout: timeout,
            uriLinkStream: nativeLinks.stream,
          );
        },
      ).chooseSpreadsheet();

      final launchedUrl = Uri.parse(launcher.launchedUrls.single);
      expect(launchedUrl.host, 'accounts.google.com');
      expect(
        launchedUrl.queryParameters['redirect_uri'],
        workoutTrackerGooglePickerHostedCallbackUri.toString(),
      );
      expect(launcher.returnedState, launchedUrl.queryParameters['state']);
      expect(selected?.spreadsheetId, 'picked-spreadsheet-id');
    },
  );

  test('native google picker callback accepts only safe app-owned results', () {
    final success = validateGooglePickerNativeCallback(
      Uri.parse(
        'workouttracker://google-picker-callback'
        '?state=request-state&picked_file_ids=first_sheet,second-sheet',
      ),
      expectedState: 'request-state',
    );

    expect(success.result?.pickedSpreadsheetIds, [
      'first_sheet',
      'second-sheet',
    ]);
    expect(success.errorMessage, isNull);

    final cancelled = validateGooglePickerNativeCallback(
      Uri.parse(
        'workouttracker://google-picker-callback'
        '?state=request-state&error=access_denied',
      ),
      expectedState: 'request-state',
    );
    expect(cancelled.result?.cancelled, isTrue);

    final pickerError = validateGooglePickerNativeCallback(
      Uri.parse(
        'workouttracker://google-picker-callback'
        '?state=request-state&error=server_error',
      ),
      expectedState: 'request-state',
    );
    expect(pickerError.result?.error, 'server_error');

    final missingState = validateGooglePickerNativeCallback(
      Uri.parse(
        'workouttracker://google-picker-callback'
        '?picked_file_ids=spreadsheet-id',
      ),
      expectedState: 'request-state',
    );
    expect(missingState.result, isNull);
    expect(missingState.errorMessage, contains('missing request state'));

    final wrongState = validateGooglePickerNativeCallback(
      Uri.parse(
        'workouttracker://google-picker-callback'
        '?state=other-state&picked_file_ids=spreadsheet-id',
      ),
      expectedState: 'request-state',
    );
    expect(wrongState.result, isNull);
    expect(wrongState.errorMessage, contains('state'));

    final malformedSpreadsheetId = validateGooglePickerNativeCallback(
      Uri.parse(
        'workouttracker://google-picker-callback'
        '?state=request-state&picked_file_ids=spreadsheet.id',
      ),
      expectedState: 'request-state',
    );
    expect(malformedSpreadsheetId.result, isNull);
    expect(malformedSpreadsheetId.errorMessage, contains('spreadsheet ID'));

    final unrelated = validateGooglePickerNativeCallback(
      Uri.parse(
        'com.googleusercontent.apps.client:/oauth2redirect'
        '?state=request-state&picked_file_ids=spreadsheet-id',
      ),
      expectedState: 'request-state',
    );
    expect(unrelated.result, isNull);
    expect(unrelated.errorMessage, contains('workouttracker'));
  });

  test('native google picker callback scheme is app-owned', () {
    final iosInfoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final macosInfoPlist = File('macos/Runner/Info.plist').readAsStringSync();
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(iosInfoPlist, contains('<string>workouttracker</string>'));
    expect(macosInfoPlist, contains('<string>workouttracker</string>'));
    expect(androidManifest, contains('android:scheme="workouttracker"'));
    expect(
      iosInfoPlist,
      contains(
        '<string>\$(WORKOUT_TRACKER_GOOGLE_REVERSED_CLIENT_ID)</string>',
      ),
    );
    expect(
      macosInfoPlist,
      contains(
        '<string>\$(WORKOUT_TRACKER_GOOGLE_REVERSED_CLIENT_ID)</string>',
      ),
    );
  });
}

Future<GooglePickerCallbackReceiver> _unusedCallbackReceiverFactory({
  required String state,
  required Duration timeout,
}) async {
  throw StateError('Spreadsheet picker callback receiver was not expected.');
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

  @override
  Future<void> signOut() async {}
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

class _CompletingHostedGooglePickerLauncher extends UrlLauncherPlatform {
  _CompletingHostedGooglePickerLauncher(this.nativeLinks);

  final StreamController<Uri> nativeLinks;
  final launchedUrls = <String>[];
  String? returnedState;

  @override
  final LinkDelegate? linkDelegate = null;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrls.add(url);
    final launchedUri = Uri.parse(url);
    returnedState = launchedUri.queryParameters['state'];
    scheduleMicrotask(() {
      nativeLinks.add(
        Uri(
          scheme: workoutTrackerGooglePickerNativeCallbackScheme,
          host: workoutTrackerGooglePickerNativeCallbackHost,
          queryParameters: {
            'state': returnedState!,
            'picked_file_ids': 'picked-spreadsheet-id',
          },
        ),
      );
    });
    return true;
  }
}
