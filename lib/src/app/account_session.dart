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

  Future<void> restoreAccount();

  Future<void> switchAccount({List<String> scopes = const []});

  Future<void> signOut();
}

abstract interface class SignInAuthGateway implements GoogleAccountSession {
  Future<String?> authorizationToken(
    List<String> scopes, {
    bool promptIfNecessary = false,
  });

  Future<Map<String, String>> authorizationHeaders(List<String> scopes);
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
  Future<void> restoreAccount() async {
    await _ensureInitialized();
    final lightweight = _signIn.attemptLightweightAuthentication();
    final account = lightweight == null ? null : await lightweight;
    if (account != null) {
      _setAccount(account);
    }
  }

  @override
  Future<String?> authorizationToken(
    List<String> scopes, {
    bool promptIfNecessary = false,
  }) async {
    await _ensureInitialized();
    try {
      final account = await _currentAccount(scopes);
      final auth =
          await account.authorizationClient.authorizationForScopes(scopes) ??
          (promptIfNecessary
              ? await account.authorizationClient.authorizeScopes(scopes)
              : null);
      return auth?.accessToken;
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
  Future<Map<String, String>> authorizationHeaders(List<String> scopes) async {
    final accessToken = await authorizationToken(
      scopes,
      promptIfNecessary: true,
    );
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw StateError('Google authorization did not return Sheets headers.');
    }
    return {'Authorization': 'Bearer $accessToken', 'X-Goog-AuthUser': '0'};
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
