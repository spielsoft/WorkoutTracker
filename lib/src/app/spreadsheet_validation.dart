import 'dart:convert';
import 'dart:io';

import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

const workoutTrackerDevelopmentSpreadsheetUrl =
    'https://docs.google.com/spreadsheets/d/'
    '$workoutTrackerDevelopmentSpreadsheetId/edit?gid=0#gid=0';
const workoutTrackerDevelopmentCredentialsDartDefine =
    'WORKOUT_TRACKER_GOOGLE_APPLICATION_CREDENTIALS';
const workoutTrackerDevelopmentCredentialsPath = String.fromEnvironment(
  workoutTrackerDevelopmentCredentialsDartDefine,
);

abstract interface class SpreadsheetValidationService {
  /// Reads and reparses the active sheet for [spreadsheetId].
  ///
  /// The returned [ParsedActiveSheet] becomes the ordering source for every
  /// later workout, history-block, and row selection passed back through this
  /// Interface.
  Future<SpreadsheetValidationReport> validateSpreadsheet(String spreadsheetId);

  /// Creates a new visible history block on the active sheet and rereads it.
  ///
  /// Callers must pass the latest [activeSheet] returned for [spreadsheetId].
  /// Mixing a stale [ParsedActiveSheet] from an older read or a different
  /// spreadsheet violates the Interface ordering rules.
  Future<SpreadsheetValidationReport> createHistoryBlock({
    required String spreadsheetId,
    required String label,
    required ParsedActiveSheet activeSheet,
  });

  /// Applies [plan] to the active sheet and rereads the spreadsheet.
  ///
  /// Callers should treat [plan] as row-order-sensitive and build it from the
  /// same [activeSheet] they pass here. The sheet contract Module owns row and
  /// history-block validity; callers should pass row numbers obtained from the
  /// parsed read models rather than inventing them.
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  });
}

class SpreadsheetValidationReport {
  const SpreadsheetValidationReport({
    required this.spreadsheetId,
    required this.activeSheet,
  });

  final String spreadsheetId;
  final ParsedActiveSheet activeSheet;

  List<SchemaViolation> get schemaViolations {
    return activeSheet.schemaViolations;
  }

  List<FormulaHealingIssue> get formulaHealingIssues {
    return activeSheet.formulaHealingIssues;
  }

  bool get hasBlockingSchemaViolations {
    return schemaViolations.isNotEmpty;
  }
}

class GoogleSpreadsheetValidationService
    implements SpreadsheetValidationService {
  const GoogleSpreadsheetValidationService({
    required this.readAdapter,
    this.writeAdapter,
  });

  final GoogleSheetsReadAdapter readAdapter;
  final GoogleSheetsWriteAdapter? writeAdapter;

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: await readAdapter.readParsedActiveSheet(spreadsheetId),
    );
  }

  @override
  Future<SpreadsheetValidationReport> createHistoryBlock({
    required String spreadsheetId,
    required String label,
    required ParsedActiveSheet activeSheet,
  }) async {
    return applyActiveSheetWritePlan(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
      plan: activeSheet.planNewHistoryBlock(label: label),
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    final writeAdapter = this.writeAdapter;
    if (writeAdapter == null) {
      throw StateError('Sheet writes require a write adapter.');
    }
    await writeAdapter.applyActiveSheetWritePlan(
      spreadsheetId: spreadsheetId,
      plan: plan,
    );
    return validateSpreadsheet(spreadsheetId);
  }
}

typedef WorkoutTrackerAuthClientFactory =
    Future<auth.AutoRefreshingAuthClient> Function({
      required List<String> scopes,
      required String credentialsPath,
    });

typedef ApplicationDefaultAuthClientFactory =
    Future<auth.AutoRefreshingAuthClient> Function({
      required List<String> scopes,
    });

typedef GoogleSpreadsheetValidationServiceFactory =
    SpreadsheetValidationService Function(
      sheets.SheetsApi api, {
      required bool canWrite,
    });

class AdcSpreadsheetValidationService implements SpreadsheetValidationService {
  const AdcSpreadsheetValidationService({
    this.credentialsPath = workoutTrackerDevelopmentCredentialsPath,
    this.clientFactory = clientViaWorkoutTrackerDevelopmentCredentials,
    GoogleSpreadsheetValidationServiceFactory? serviceFactory,
  }) : _serviceFactory =
           serviceFactory ?? defaultGoogleSpreadsheetValidationServiceFactory;

  final String credentialsPath;
  final WorkoutTrackerAuthClientFactory clientFactory;
  final GoogleSpreadsheetValidationServiceFactory _serviceFactory;

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    auth.AutoRefreshingAuthClient? client;
    try {
      client = await clientFactory(
        scopes: GoogleApisSheetsSpreadsheetClient.readOnlyScopes,
        credentialsPath: credentialsPath,
      );
      final api = sheets.SheetsApi(client);
      return await _serviceFactory(
        api,
        canWrite: false,
      ).validateSpreadsheet(spreadsheetId);
    } finally {
      client?.close();
    }
  }

  @override
  Future<SpreadsheetValidationReport> createHistoryBlock({
    required String spreadsheetId,
    required String label,
    required ParsedActiveSheet activeSheet,
  }) async {
    return applyActiveSheetWritePlan(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
      plan: activeSheet.planNewHistoryBlock(label: label),
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    auth.AutoRefreshingAuthClient? client;
    try {
      client = await clientFactory(
        scopes: GoogleApisSheetsWriteClient.writeScopes,
        credentialsPath: credentialsPath,
      );
      final api = sheets.SheetsApi(client);
      return await _serviceFactory(
        api,
        canWrite: true,
      ).applyActiveSheetWritePlan(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        plan: plan,
      );
    } finally {
      client?.close();
    }
  }
}

SpreadsheetValidationService defaultGoogleSpreadsheetValidationServiceFactory(
  sheets.SheetsApi api, {
  required bool canWrite,
}) {
  return GoogleSpreadsheetValidationService(
    readAdapter: GoogleSheetsReadAdapter(
      client: GoogleApisSheetsSpreadsheetClient(api),
    ),
    writeAdapter: canWrite
        ? GoogleSheetsWriteAdapter(client: GoogleApisSheetsWriteClient(api))
        : null,
  );
}

Future<auth.AutoRefreshingAuthClient>
clientViaWorkoutTrackerDevelopmentCredentials({
  required List<String> scopes,
  String credentialsPath = workoutTrackerDevelopmentCredentialsPath,
  Map<String, String>? environment,
  ApplicationDefaultAuthClientFactory applicationDefaultClientFactory =
      _clientViaApplicationDefaultCredentials,
}) async {
  final resolvedPath = resolveWorkoutTrackerGoogleCredentialsPath(
    credentialsPath: credentialsPath,
    environment: environment ?? Platform.environment,
  );
  if (resolvedPath == null) {
    try {
      return await applicationDefaultClientFactory(scopes: scopes);
    } on Exception catch (error) {
      throw StateError(
        'No local Google credentials file was found. Set '
        '$workoutTrackerDevelopmentCredentialsDartDefine, set '
        'GOOGLE_APPLICATION_CREDENTIALS, or run '
        '`gcloud auth application-default login` so the standard ADC file '
        'exists. Original error: $error',
      );
    }
  }

  final credentials = jsonDecode(await File(resolvedPath).readAsString());
  if (credentials is! Map<String, dynamic>) {
    throw FormatException(
      'Google credentials file must contain a JSON object: $resolvedPath',
    );
  }

  final quotaProject = credentials['quota_project_id'] as String?;
  if (credentials case {
    'type': 'authorized_user',
    'client_id': final String clientId,
    'client_secret': final String? clientSecret,
    'refresh_token': final String refreshToken,
  }) {
    return auth.clientViaRefreshToken(
      auth.ClientId(clientId, clientSecret),
      refreshToken,
      scopes,
      quotaProject: quotaProject,
    );
  }

  if (credentials['type'] == 'service_account') {
    return auth.clientViaServiceAccount(
      auth.ServiceAccountCredentials.fromJson(credentials),
      scopes,
      quotaProject: quotaProject,
    );
  }

  throw FormatException(
    'Unsupported Google credentials type for $resolvedPath: '
    '${credentials['type']}',
  );
}

String? resolveWorkoutTrackerGoogleCredentialsPath({
  String credentialsPath = workoutTrackerDevelopmentCredentialsPath,
  Map<String, String>? environment,
}) {
  final env = environment ?? Platform.environment;
  final explicitPath = credentialsPath.trim();
  if (explicitPath.isNotEmpty) {
    return explicitPath;
  }

  final workoutTrackerPath =
      env[workoutTrackerDevelopmentCredentialsDartDefine]?.trim() ?? '';
  if (workoutTrackerPath.isNotEmpty) {
    return workoutTrackerPath;
  }

  final googlePath = env['GOOGLE_APPLICATION_CREDENTIALS']?.trim() ?? '';
  if (googlePath.isNotEmpty) {
    return googlePath;
  }

  final home = env['HOME']?.trim() ?? '';
  if (home.isNotEmpty) {
    final wellKnownPath =
        '$home/.config/gcloud/application_default_credentials.json';
    if (File(wellKnownPath).existsSync()) {
      return wellKnownPath;
    }
  }

  return null;
}

Future<auth.AutoRefreshingAuthClient> _clientViaApplicationDefaultCredentials({
  required List<String> scopes,
}) {
  return auth.clientViaApplicationDefaultCredentials(scopes: scopes);
}

String spreadsheetIdFromSelection(String input) {
  final trimmed = input.trim();
  final match = RegExp(r'/spreadsheets/d/([A-Za-z0-9_-]+)').firstMatch(trimmed);
  return match?.group(1) ?? trimmed;
}
