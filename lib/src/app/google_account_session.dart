import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  Future<void> restoreAccount();

  Future<void> switchAccount({List<String> scopes = const []});

  Future<void> signOut();
}

abstract interface class GoogleSignInAuthorizationGateway
    implements GoogleAccountSession {
  Future<Map<String, String>> authorizationHeaders(List<String> scopes);
}

abstract interface class GooglePickerAuthorizationStore {
  GooglePickerAuthorizationSnapshot? get currentAuthorization;

  void restoreGooglePickerAuthorization(
    GooglePickerAuthorizationSnapshot? authorization,
  );

  void updateGooglePickerAuthorization(
    GooglePickerAuthorizationSnapshot authorization,
  );
}

class GooglePickerAuthorizationSnapshot {
  const GooglePickerAuthorizationSnapshot({
    required this.accessToken,
    this.accountEmail,
  });

  final String accessToken;
  final String? accountEmail;

  Map<String, Object?> toJson() {
    return {
      'accessToken': accessToken,
      if (accountEmail != null) 'accountEmail': accountEmail,
    };
  }

  static GooglePickerAuthorizationSnapshot? fromJson(Object? value) {
    if (value case <String, Object?>{'accessToken': final String accessToken}) {
      final trimmedToken = accessToken.trim();
      if (trimmedToken.isEmpty) {
        return null;
      }
      return GooglePickerAuthorizationSnapshot(
        accessToken: trimmedToken,
        accountEmail: value['accountEmail'] as String?,
      );
    }
    return null;
  }
}

class GooglePickerAuthorizationGateway extends ChangeNotifier
    implements
        GoogleSignInAuthorizationGateway,
        GooglePickerAuthorizationStore {
  GooglePickerAuthorizationGateway({GooglePickerAuthorizationSnapshot? initial})
    : _authorization = initial;

  GooglePickerAuthorizationSnapshot? _authorization;

  @override
  GooglePickerAuthorizationSnapshot? get currentAuthorization => _authorization;

  @override
  GoogleAccountProfile? get currentAccount {
    final email = _authorization?.accountEmail?.trim();
    if (email == null || email.isEmpty) {
      return null;
    }
    return GoogleAccountProfile(email: email);
  }

  @override
  Future<void> restoreAccount() async {}

  @override
  Future<void> switchAccount({List<String> scopes = const []}) async {
    throw StateError(
      'Use Choose workout sheet or Create sheet to connect Google Sheets.',
    );
  }

  @override
  Future<void> signOut() async {
    restoreGooglePickerAuthorization(null);
  }

  @override
  Future<Map<String, String>> authorizationHeaders(List<String> scopes) async {
    final accessToken = _authorization?.accessToken.trim();
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Choose a Google Sheets file before using Google APIs.');
    }
    return {'Authorization': 'Bearer $accessToken'};
  }

  @override
  void restoreGooglePickerAuthorization(
    GooglePickerAuthorizationSnapshot? authorization,
  ) {
    _authorization = authorization;
    notifyListeners();
  }

  @override
  void updateGooglePickerAuthorization(
    GooglePickerAuthorizationSnapshot authorization,
  ) {
    restoreGooglePickerAuthorization(authorization);
  }
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
  Future<void> restoreAccount() async {
    await _ensureInitialized();
    final lightweight = _signIn.attemptLightweightAuthentication();
    final account = lightweight == null ? null : await lightweight;
    if (account != null) {
      _setAccount(account);
    }
  }

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
  Future<void> switchAccount({List<String> scopes = const []}) async {
    await _ensureInitialized();
    await signOut();
    final account = await _signIn.authenticate(scopeHint: scopes);
    if (scopes.isNotEmpty) {
      final headers = await account.authorizationClient.authorizationHeaders(
        scopes,
        promptIfNecessary: true,
      );
      if (headers == null) {
        throw StateError('Google authorization did not return Sheets headers.');
      }
    }
    _setAccount(account);
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await _signIn.signOut();
    _setAccount(null);
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

    await restoreAccount();
    final lightweightAccount = _account;
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
