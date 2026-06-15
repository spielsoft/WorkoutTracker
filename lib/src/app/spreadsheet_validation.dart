import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

const workoutTrackerDevelopmentSpreadsheetUrl =
    'https://docs.google.com/spreadsheets/d/'
    '$workoutTrackerDevelopmentSpreadsheetId/edit?gid=0#gid=0';
const workoutTrackerGoogleSignInClientIdDartDefine =
    'WORKOUT_TRACKER_GOOGLE_CLIENT_ID';
const workoutTrackerGoogleSignInClientId = String.fromEnvironment(
  workoutTrackerGoogleSignInClientIdDartDefine,
);
const workoutTrackerGoogleSignInServerClientIdDartDefine =
    'WORKOUT_TRACKER_GOOGLE_SERVER_CLIENT_ID';
const workoutTrackerGoogleSignInServerClientId = String.fromEnvironment(
  workoutTrackerGoogleSignInServerClientIdDartDefine,
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

typedef GoogleSpreadsheetValidationServiceFactory =
    SpreadsheetValidationService Function(
      sheets.SheetsApi api, {
      required bool canWrite,
    });

class GoogleAccountProfile {
  const GoogleAccountProfile({
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String email;
  final String? displayName;
  final String? photoUrl;

  String get label {
    final name = displayName?.trim();
    return name == null || name.isEmpty ? email : name;
  }
}

abstract interface class GoogleAccountSession implements Listenable {
  GoogleAccountProfile? get currentAccount;

  Future<void> switchAccount();
}

abstract interface class GoogleSignInAuthorizationGateway
    implements GoogleAccountSession {
  Future<Map<String, String>> authorizationHeaders(List<String> scopes);
}

class NativeGoogleSignInAuthorizationGateway extends ChangeNotifier
    implements GoogleSignInAuthorizationGateway {
  NativeGoogleSignInAuthorizationGateway({
    this.clientId = workoutTrackerGoogleSignInClientId,
    this.serverClientId = workoutTrackerGoogleSignInServerClientId,
    GoogleSignIn? signIn,
  }) : _signIn = signIn ?? GoogleSignIn.instance;

  final String clientId;
  final String serverClientId;
  final GoogleSignIn _signIn;
  Future<void>? _initialization;
  GoogleSignInAccount? _account;
  GoogleAccountProfile? _currentAccountProfile;

  @override
  GoogleAccountProfile? get currentAccount => _currentAccountProfile;

  @override
  Future<Map<String, String>> authorizationHeaders(List<String> scopes) async {
    await _ensureInitialized();
    final account = await _currentAccount(scopes);
    final headers = await account.authorizationClient.authorizationHeaders(
      scopes,
      promptIfNecessary: true,
    );
    if (headers == null) {
      throw StateError('Google authorization did not return Sheets headers.');
    }
    return headers;
  }

  @override
  Future<void> switchAccount() async {
    await _ensureInitialized();
    await _signIn.signOut();
    _setAccount(null);
    final account = await _signIn.authenticate();
    _setAccount(account);
  }

  Future<void> _ensureInitialized() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    await _signIn.initialize(
      clientId: _optional(clientId),
      serverClientId: _optional(serverClientId),
    );
    _signIn.authenticationEvents.listen((event) {
      switch (event) {
        case GoogleSignInAuthenticationEventSignIn(:final user):
          _setAccount(user);
        case GoogleSignInAuthenticationEventSignOut():
          _setAccount(null);
      }
    });
  }

  Future<GoogleSignInAccount> _currentAccount(List<String> scopes) async {
    final existing = _account;
    if (existing != null) {
      return existing;
    }

    final lightweight = _signIn.attemptLightweightAuthentication();
    final lightweightAccount = lightweight == null ? null : await lightweight;
    final account =
        lightweightAccount ?? await _signIn.authenticate(scopeHint: scopes);
    _setAccount(account);
    return account;
  }

  void _setAccount(GoogleSignInAccount? account) {
    _account = account;
    _currentAccountProfile = account == null
        ? null
        : GoogleAccountProfile(
            email: account.email,
            displayName: account.displayName,
            photoUrl: account.photoUrl,
          );
    notifyListeners();
  }

  static String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class GoogleSignInSpreadsheetValidationService
    implements SpreadsheetValidationService {
  GoogleSignInSpreadsheetValidationService({
    GoogleSignInAuthorizationGateway? authorizationGateway,
    GoogleSpreadsheetValidationServiceFactory? serviceFactory,
  }) : _authorizationGateway =
           authorizationGateway ?? NativeGoogleSignInAuthorizationGateway(),
       _serviceFactory =
           serviceFactory ?? defaultGoogleSpreadsheetValidationServiceFactory;

  final GoogleSignInAuthorizationGateway _authorizationGateway;
  final GoogleSpreadsheetValidationServiceFactory _serviceFactory;

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    return _withGoogleSheetsService(
      scopes: GoogleApisSheetsSpreadsheetClient.readOnlyScopes,
      canWrite: false,
      action: (service) => service.validateSpreadsheet(spreadsheetId),
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
    return _withGoogleSheetsService(
      scopes: GoogleApisSheetsWriteClient.writeScopes,
      canWrite: true,
      action: (service) => service.applyActiveSheetWritePlan(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        plan: plan,
      ),
    );
  }

  Future<SpreadsheetValidationReport> _withGoogleSheetsService({
    required List<String> scopes,
    required bool canWrite,
    required Future<SpreadsheetValidationReport> Function(
      SpreadsheetValidationService service,
    )
    action,
  }) async {
    final headers = await _authorizationGateway.authorizationHeaders(scopes);
    final client = GoogleAuthorizationHeadersClient(headers: headers);
    try {
      final api = sheets.SheetsApi(client);
      return await action(_serviceFactory(api, canWrite: canWrite));
    } finally {
      client.close();
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

class GoogleAuthorizationHeadersClient extends http.BaseClient {
  GoogleAuthorizationHeadersClient({required this.headers, http.Client? inner})
    : _inner = inner ?? http.Client();

  final Map<String, String> headers;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

String spreadsheetIdFromSelection(String input) {
  final trimmed = input.trim();
  final match = RegExp(r'/spreadsheets/d/([A-Za-z0-9_-]+)').firstMatch(trimmed);
  return match?.group(1) ?? trimmed;
}
