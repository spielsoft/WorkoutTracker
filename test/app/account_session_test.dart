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

    test('missing client ID names the key and setup guide', () {
      const cfg = GoogleSignInCfg();

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
                'guide',
                contains('docs/google_sheets_development_auth.md'),
              ),
        ),
      );
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

  test('invalid configuration fails before native initialization', () async {
    final events = _AuthEvents();
    final gateway = NativeSignInAuthGateway(
      cfg: const GoogleSignInCfg(),
      authEvents: events,
    );

    await expectLater(gateway.signIn(), throwsA(isA<GoogleSignInCfgError>()));
    expect(events.initCount, 0);

    gateway.dispose();
    await events.close();
  });

  test(
    'repeated initialization attaches one authentication listener',
    () async {
      final events = _AuthEvents();
      final gateway = NativeSignInAuthGateway(
        cfg: const GoogleSignInCfg(
          clientId: 'public-id.apps.googleusercontent.com',
        ),
        authEvents: events,
      );

      await gateway.authorizationHeaders(const []);
      await gateway.authorizationHeaders(const []);

      expect(events.initCount, 1);
      expect(events.listenCount, 1);

      gateway.dispose();
      await events.close();
    },
  );

  test(
    'dispose cancels authentication events and ignores later events',
    () async {
      final events = _AuthEvents();
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

      gateway.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(events.cancelCount, 1);

      events.add(GoogleSignInAuthenticationEventSignOut());
      await Future<void>.delayed(Duration.zero);

      expect(gateway.currentAccount?.email, 'athlete@example.com');
      expect(notifications, 1);
      expect(events.cancelCount, 1);

      await events.close();
    },
  );
}

class _AuthEvents implements AuthEvents {
  _AuthEvents() {
    _ctrl = StreamController<GoogleSignInAuthenticationEvent>.broadcast(
      onListen: () => listenCount++,
      onCancel: () => cancelCount++,
    );
  }

  late final StreamController<GoogleSignInAuthenticationEvent> _ctrl;
  int initCount = 0;
  int listenCount = 0;
  int cancelCount = 0;

  @override
  Future<Stream<GoogleSignInAuthenticationEvent>> initialize({
    String? clientId,
    String? serverClientId,
  }) async {
    initCount++;
    return _ctrl.stream;
  }

  void add(GoogleSignInAuthenticationEvent event) => _ctrl.add(event);

  Future<void> close() => _ctrl.close();
}

class _Account implements GoogleSignInAccount {
  const _Account({required this.email});

  @override
  final String email;

  @override
  String? get displayName => 'Athlete';

  @override
  String get id => 'account-id';

  @override
  String? get photoUrl => null;

  @override
  GoogleSignInAuthentication get authentication => throw UnsupportedError(
    'Authentication tokens are not used by this test.',
  );

  @override
  GoogleSignInAuthorizationClient get authorizationClient =>
      throw UnsupportedError('Authorization is not used by this test.');
}
