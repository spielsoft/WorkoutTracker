import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

const googleClientIdDef = 'WORKOUT_TRACKER_GOOGLE_CLIENT_ID';
const googleClientId = String.fromEnvironment(googleClientIdDef);
const googleServerClientIdDef = 'WORKOUT_TRACKER_GOOGLE_SERVER_CLIENT_ID';
const googleServerClientId = String.fromEnvironment(googleServerClientIdDef);

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

  Future<void> restoreAccount({List<String> scopes = const []});

  Future<bool> signIn({List<String> scopes = const []});

  Future<void> signOut();
}

abstract interface class SignInAuthGateway implements GoogleAccountSession {
  Future<Map<String, String>?> authorizationHeaders(List<String> scopes);
}

class NativeSignInAuthGateway extends ChangeNotifier
    implements SignInAuthGateway {
  NativeSignInAuthGateway({
    this.clientId = googleClientId,
    this.serverClientId = googleServerClientId,
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
  Future<void> restoreAccount({List<String> scopes = const []}) async {
    await _ensureInitialized();
    final lightweight = _signIn.attemptLightweightAuthentication();
    final account = lightweight == null ? null : await lightweight;
    if (account != null) {
      if (scopes.isNotEmpty &&
          await account.authorizationClient.authorizationHeaders(scopes) ==
              null) {
        await _disconnect();
        return;
      }
      _setAccount(account);
    }
  }

  @override
  Future<Map<String, String>?> authorizationHeaders(List<String> scopes) async {
    await _ensureInitialized();
    final account = _account;
    if (account == null) {
      return null;
    }
    try {
      return account.authorizationClient.authorizationHeaders(scopes);
    } on GoogleSignInException catch (error) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
        case GoogleSignInExceptionCode.uiUnavailable:
          return null;
        default:
          rethrow;
      }
    }
  }

  @override
  Future<bool> signIn({List<String> scopes = const []}) async {
    await _ensureInitialized();
    try {
      final account = _account ?? await _signIn.authenticate(scopeHint: scopes);
      if (scopes.isNotEmpty) {
        final headers = await account.authorizationClient.authorizationHeaders(
          scopes,
          promptIfNecessary: true,
        );
        if (headers == null) {
          await signOut();
          return false;
        }
      }
      _setAccount(account);
      return true;
    } on GoogleSignInException catch (error) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
        case GoogleSignInExceptionCode.uiUnavailable:
          await _disconnect();
          return false;
        default:
          rethrow;
      }
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await _disconnect();
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

  void _setAccount(GoogleSignInAccount? account) {
    if (_account == account) {
      return;
    }
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

  Future<void> _disconnect() async {
    try {
      await _signIn.signOut();
    } finally {
      _setAccount(null);
    }
  }

  static String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
