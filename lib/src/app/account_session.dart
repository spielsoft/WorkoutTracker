import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

const googleClientIdDef = 'WORKOUT_TRACKER_GOOGLE_CLIENT_ID';
const googleClientId = String.fromEnvironment(googleClientIdDef);
const googleServerClientIdDef = 'WORKOUT_TRACKER_GOOGLE_SERVER_CLIENT_ID';
const googleServerClientId = String.fromEnvironment(googleServerClientIdDef);
const googleCfgGuide = 'docs/google_sheets_development_auth.md';

final class GoogleSignInCfgError implements Exception {
  const GoogleSignInCfgError(this.message);

  final String message;

  @override
  String toString() => message;
}

class GoogleSignInCfg {
  const GoogleSignInCfg({this.clientId = '', this.serverClientId = ''});

  final String clientId;
  final String serverClientId;

  void validate() {
    _validateClientId(googleClientIdDef, clientId);
    _validateClientId(googleServerClientIdDef, serverClientId);
  }

  static void _validateClientId(String key, String value) {
    final id = value.trim();
    if (id.isEmpty) return;
    if (!RegExp(
      r'^[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$',
    ).hasMatch(id)) {
      throw GoogleSignInCfgError(
        'Malformed $key. Follow $googleCfgGuide before logging in.',
      );
    }
  }
}

const googleSignInCfg = GoogleSignInCfg(
  clientId: googleClientId,
  serverClientId: googleServerClientId,
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

  Future<void> restoreAccount({List<String> scopes = const []});

  Future<bool> signIn({List<String> scopes = const []});

  Future<void> signOut();
}

abstract interface class SignInAuthGateway implements GoogleAccountSession {
  Future<Map<String, String>?> authorizationHeaders(List<String> scopes);
}

abstract interface class AuthEvents {
  Future<Stream<GoogleSignInAuthenticationEvent>> initialize({
    String? clientId,
    String? serverClientId,
  });
}

class NativeSignInAuthGateway extends ChangeNotifier
    implements SignInAuthGateway {
  factory NativeSignInAuthGateway({
    GoogleSignInCfg cfg = googleSignInCfg,
    GoogleSignIn? signIn,
    AuthEvents? authEvents,
  }) {
    final native = signIn ?? GoogleSignIn.instance;
    return NativeSignInAuthGateway._(
      native,
      authEvents ?? _NativeAuthEvents(native),
      cfg,
    );
  }

  NativeSignInAuthGateway._(this._signIn, this._authEvents, this._cfg);

  final GoogleSignInCfg _cfg;
  final GoogleSignIn _signIn;
  final AuthEvents _authEvents;
  Future<void>? _initialization;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;
  GoogleSignInAccount? _account;
  GoogleAccountProfile? _currentAccountProfile;
  bool _disposed = false;

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
    _cfg.validate();
    final events = await _authEvents.initialize(
      clientId: _optional(_cfg.clientId),
      serverClientId: _optional(_cfg.serverClientId),
    );
    if (_disposed) {
      return;
    }
    _authSub ??= events.listen(_handleAuthEvent);
  }

  void _handleAuthEvent(GoogleSignInAuthenticationEvent event) {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn(:final user):
        _setAccount(user);
      case GoogleSignInAuthenticationEventSignOut():
        _setAccount(null);
    }
  }

  void _setAccount(GoogleSignInAccount? account) {
    if (_disposed || _account == account) {
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

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final authSub = _authSub;
    _authSub = null;
    if (authSub != null) {
      unawaited(authSub.cancel());
    }
    super.dispose();
  }
}

class _NativeAuthEvents implements AuthEvents {
  const _NativeAuthEvents(this._signIn);

  final GoogleSignIn _signIn;

  @override
  Future<Stream<GoogleSignInAuthenticationEvent>> initialize({
    String? clientId,
    String? serverClientId,
  }) async {
    await _signIn.initialize(
      clientId: clientId,
      serverClientId: serverClientId,
    );
    return _signIn.authenticationEvents;
  }
}
