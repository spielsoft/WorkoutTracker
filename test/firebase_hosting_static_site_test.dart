import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase Hosting static site', () {
    late String support;
    late String privacy;

    setUpAll(() {
      support = _html('public/index.html');
      privacy = _html('public/privacy.html');
    });

    test('publishes connected support and privacy destinations', () {
      expect(_hrefs(support), contains('/privacy.html'));
      expect(_hrefs(privacy), contains('/'));

      const contact = 'mailto:ian.spielman@gmail.com';
      expect(_hrefs(support), contains(contact));
      expect(_hrefs(privacy), contains(contact));

      final text = support.toLowerCase();
      expect(text, contains('help'));
      expect(text, contains('report'));
    });

    test('discloses the data boundaries and current Google access', () {
      final text = privacy.toLowerCase();

      for (final disclosure in [
        'native google sign-in',
        'custom in-app chooser',
        'google account identity',
        'local app state',
        'user-owned google sheet',
        'static support and privacy pages',
      ]) {
        expect(text, contains(disclosure), reason: 'Missing $disclosure');
      }

      expect(
        privacy,
        contains('https://www.googleapis.com/auth/drive.metadata.readonly'),
      );
      expect(privacy, contains('https://www.googleapis.com/auth/spreadsheets'));
      expect(text, contains('discover'));
      expect(text, contains('read and write'));
    });

    test('provides deletion and revocation controls', () {
      final text = privacy.toLowerCase();

      expect(text, contains('delete'));
      expect(text, contains('google account'));
      expect(text, contains('revoke'));
      expect(text, contains('local'));
    });

    test('contains no hosted auth flow or Firebase data client', () {
      final html = '$support\n$privacy'.toLowerCase();

      for (final unsafe in [
        '<script',
        '<form',
        '/callback',
        'access_token',
        'refresh_token',
        'picker callback',
        'server token',
        'app backend',
        'workout backend',
        '/__/firebase/',
        'firebase-app-compat',
      ]) {
        expect(html, isNot(contains(unsafe)), reason: 'Found $unsafe');
      }

      expect(html, contains('firebase hosting'));
      expect(html, contains('static'));
    });

    test('publishes only the static pages without SPA rewrites', () {
      final cfg =
          jsonDecode(File('firebase.json').readAsStringSync())
              as Map<String, Object?>;
      final rc =
          jsonDecode(File('.firebaserc').readAsStringSync())
              as Map<String, Object?>;

      expect(
        rc,
        containsPair(
          'projects',
          containsPair('default', 'workouttracker-16285'),
        ),
      );

      expect(
        cfg,
        containsPair(
          'hosting',
          allOf(
            containsPair('public', 'public'),
            containsPair('ignore', [
              'firebase.json',
              '.firebaserc',
              '**/node_modules/**',
            ]),
            isNot(containsPair('rewrites', anything)),
          ),
        ),
      );

      final files = Directory('public')
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path)
          .toSet();

      expect(files, {'public/index.html', 'public/privacy.html'});
    });
  });
}

String _html(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Missing $path');
  return file.readAsStringSync();
}

Set<String> _hrefs(String html) => RegExp(
  '''href=["']([^"']+)["']''',
  caseSensitive: false,
).allMatches(html).map((match) => match.group(1)!).toSet();
