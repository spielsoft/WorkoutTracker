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
    await _signIn.signOut();
    _setAccount(null);
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
