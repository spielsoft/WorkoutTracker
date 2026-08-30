import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:workout_tracker/app.dart';

void main() {
  group('GoogleSignInCfg', () {
    test('accepts a native OAuth client ID', () {
      const cfg = GoogleSignInCfg(
        clientId: 'public-id.apps.googleusercontent.com',
      );

      expect(cfg.validate, returnsNormally);
    });

    test('allows Apple to load its native client ID from Info.plist', () {
      const cfg = GoogleSignInCfg();

      expect(cfg.validate, returnsNormally);
    });

    test('malformed client ID does not expose its value', () {
      const bad = 'private-builder-value';
      const cfg = GoogleSignInCfg(clientId: bad);

      expect(
        cfg.validate,
        throwsA(
          isA<GoogleSignInCfgError>()
              .having(
                (error) => error.toString(),
                'message',
                contains(googleClientIdDef),
              )
              .having(
                (error) => error.toString(),
                'contents',
                isNot(contains(bad)),
              ),
        ),
      );
    });
  });

  test('malformed Dart override fails before native initialization', () async {
    final events = _InitEvents();
    final gateway = NativeSignInAuthGateway(
      cfg: const GoogleSignInCfg(clientId: 'malformed-client'),
      authEvents: events,
    );

    await expectLater(gateway.signIn(), throwsA(isA<GoogleSignInCfgError>()));
    expect(events.initCount, 0);

    gateway.dispose();
    await events.close();
  });

  test('empty Dart overrides defer client configuration to Apple', () async {
    final events = _InitEvents();
    final gateway = NativeSignInAuthGateway(
      cfg: const GoogleSignInCfg(),
      authEvents: events,
    );

    await gateway.authorizationHeaders(const []);

    expect(events.initCount, 1);
    expect(events.clientId, isNull);
    expect(events.serverClientId, isNull);

    gateway.dispose();
    await events.close();
  });

  test(
    'reflects native authentication callbacks through account state',
    () async {
      final events = _InitEvents();
      final gateway = NativeSignInAuthGateway(
        cfg: const GoogleSignInCfg(
          clientId: 'public-id.apps.googleusercontent.com',
        ),
        authEvents: events,
      );
      var notifications = 0;
      gateway.addListener(() => notifications++);

      await gateway.authorizationHeaders(const []);
      events.add(
        GoogleSignInAuthenticationEventSignIn(
          user: const _Account(email: 'athlete@example.com'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(gateway.currentAccount?.email, 'athlete@example.com');
      expect(notifications, 1);

      events.add(GoogleSignInAuthenticationEventSignOut());
      await Future<void>.delayed(Duration.zero);

      expect(gateway.currentAccount, isNull);
      expect(notifications, 2);

      gateway.dispose();
      events.add(
        GoogleSignInAuthenticationEventSignIn(
          user: const _Account(email: 'late@example.com'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(gateway.currentAccount, isNull);
      expect(notifications, 2);
      await events.close();
    },
  );

  test(
    'a cancelled authorization reports no headers instead of throwing',
    () async {
      final events = _InitEvents();
      final gateway = NativeSignInAuthGateway(
        cfg: const GoogleSignInCfg(),
        authEvents: events,
      );
      await gateway.authorizationHeaders(const []);
      events.add(
        GoogleSignInAuthenticationEventSignIn(
          user: const _Account(
            email: 'athlete@example.com',
            authorization: _CancellingAuthorizationClient(
              GoogleSignInExceptionCode.canceled,
            ),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        gateway.authorizationHeaders(const ['scope']),
        completion(isNull),
      );

      gateway.dispose();
      await events.close();
    },
  );

  test(
    'an unrecognised authorization failure still reaches the caller',
    () async {
      final events = _InitEvents();
      final gateway = NativeSignInAuthGateway(
        cfg: const GoogleSignInCfg(),
        authEvents: events,
      );
      await gateway.authorizationHeaders(const []);
      events.add(
        GoogleSignInAuthenticationEventSignIn(
          user: const _Account(
            email: 'athlete@example.com',
            authorization: _CancellingAuthorizationClient(
              GoogleSignInExceptionCode.unknownError,
            ),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        gateway.authorizationHeaders(const ['scope']),
        throwsA(isA<GoogleSignInException>()),
      );

      gateway.dispose();
      await events.close();
    },
  );
}

class _InitEvents implements AuthEvents {
  final _events = StreamController<GoogleSignInAuthenticationEvent>.broadcast();
  int initCount = 0;
  String? clientId;
  String? serverClientId;

  @override
  Future<Stream<GoogleSignInAuthenticationEvent>> initialize({
    String? clientId,
    String? serverClientId,
  }) async {
    initCount++;
    this.clientId = clientId;
    this.serverClientId = serverClientId;
    return _events.stream;
  }

  void add(GoogleSignInAuthenticationEvent event) => _events.add(event);

  Future<void> close() => _events.close();
}

class _Account implements GoogleSignInAccount {
  const _Account({required this.email, this.authorization});

  @override
  final String email;

  final GoogleSignInAuthorizationClient? authorization;

  @override
  String? get displayName => 'Athlete';

  @override
  String get id => 'account-id';

  @override
  String? get photoUrl => null;

  @override
  GoogleSignInAuthentication get authentication => throw UnsupportedError(
    'Authentication tokens are outside this test contract.',
  );

  @override
  GoogleSignInAuthorizationClient get authorizationClient =>
      authorization ??
      (throw UnsupportedError('Authorization is outside this test contract.'));
}

/// Fails every authorization request asynchronously, the way the real client
/// does: its `authorizationHeaders` is `async`, so the failure arrives as a
/// rejected future rather than a synchronous throw.
class _CancellingAuthorizationClient
    implements GoogleSignInAuthorizationClient {
  const _CancellingAuthorizationClient(this.code);

  final GoogleSignInExceptionCode code;

  Future<Never> _fail() async => throw GoogleSignInException(code: code);

  @override
  Future<Map<String, String>?> authorizationHeaders(
    List<String> scopes, {
    bool promptIfNecessary = false,
  }) => _fail();

  @override
  Future<GoogleSignInClientAuthorization?> authorizationForScopes(
    List<String> scopes,
  ) => _fail();

  @override
  Future<GoogleSignInClientAuthorization> authorizeScopes(
    List<String> scopes,
  ) => _fail();

  @override
  Future<GoogleSignInServerAuthorization?> authorizeServer(
    List<String> scopes,
  ) => _fail();

  @override
  Future<void> clearAuthorizationToken({required String accessToken}) =>
      _fail();
}
