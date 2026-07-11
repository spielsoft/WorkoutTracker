import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase Hosting static site safety', () {
    late String support;
    late String privacy;

    setUpAll(() {
      support = File('public/index.html').readAsStringSync();
      privacy = File('public/privacy.html').readAsStringSync();
    });

    test('connects support, privacy, and the approved contact', () {
      const contact = 'mailto:ian.spielman@gmail.com';

      expect(_hrefs(support), containsAll(['/privacy.html', contact]));
      expect(_hrefs(privacy), containsAll(['/', contact]));
    });

    test('has no hosted sign-in or token-handling surface', () {
      final html = '$support\n$privacy'.toLowerCase();

      for (final unsafe in [
        '<script',
        '<form',
        '/callback',
        'access_token',
        'refresh_token',
        '/__/firebase/',
        'firebase-app-compat',
      ]) {
        expect(html, isNot(contains(unsafe)), reason: 'Found $unsafe');
      }
    });

    test('deploys only the public directory without rewrites', () {
      final cfg =
          jsonDecode(File('firebase.json').readAsStringSync())
              as Map<String, Object?>;

      expect(
        cfg,
        containsPair(
          'hosting',
          allOf(
            containsPair('public', 'public'),
            isNot(containsPair('rewrites', anything)),
          ),
        ),
      );
    });
  });
}

Set<String> _hrefs(String html) => RegExp(
  '''href=["']([^"']+)["']''',
  caseSensitive: false,
).allMatches(html).map((match) => match.group(1)!).toSet();
