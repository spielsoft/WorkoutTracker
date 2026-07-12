import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase Hosting static site safety', () {
    late String support;
    late String privacy;
    late String terms;

    setUpAll(() {
      support = File('public/index.html').readAsStringSync();
      privacy = File('public/privacy.html').readAsStringSync();
      terms = File('public/terms.html').readAsStringSync();
    });

    test('connects every public page and the approved contact', () {
      const contact = 'mailto:ian.spielman@gmail.com';
      const repo = 'https://github.com/ispielman/WorkoutTracker';
      const oldRepo = 'https://github.com/ispielma/WorkoutTracker';

      expect(
        _hrefs(support),
        containsAll(['/privacy.html', '/terms.html', contact]),
      );
      expect(_hrefs(privacy), containsAll(['/', '/terms.html', contact]));
      expect(_hrefs(terms), containsAll(['/', '/privacy.html', contact]));
      expect(_hrefs(support), contains(repo));
      expect('$support\n$terms', isNot(contains(oldRepo)));
    });

    test('has no hosted sign-in or token-handling surface', () {
      final html = '$support\n$privacy\n$terms'.toLowerCase();

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

    test('matches the current product and data boundaries', () {
      expect(support, contains('native Google Sign-In'));
      expect(support, contains('user-owned Google Sheet'));
      expect(support, contains('No account database'));
      expect(privacy, contains('drive.metadata.readonly'));
      expect(privacy, contains('spreadsheets'));
      expect(privacy, contains('App Store'));
      expect(privacy, contains('Firebase Hosting'));
    });

    test('keeps the homepage hero focused on the product', () {
      for (final removed in [
        'See how it works',
        'Contact support',
        'iOS + macOS',
        'Open source',
        'No workout-data backend',
      ]) {
        expect(support, isNot(contains(removed)), reason: 'Found $removed');
      }

      expect(support, contains('Email support'));
      expect(_hrefs(support), contains('mailto:ian.spielman@gmail.com'));
    });

    test('shows the real workout screen instead of a fabricated preview', () {
      expect(support, contains('src="/workout-screen.png"'));
      expect(
        support,
        contains(
          'alt="WorkoutTracker workout screen showing a Lower Dominant and '
          'Upper Push exercise list"',
        ),
      );
      expect(File('public/workout-screen.png').existsSync(), isTrue);

      for (final fabricated in [
        'class="workout-card"',
        'DB Step-Up',
        'Save set',
      ]) {
        expect(support, isNot(contains(fabricated)), reason: 'Found $fabricated');
      }
    });

    test('publishes the approved store terms as effective', () {
      expect(privacy, contains('WorkoutTracker Terms'));
      expect(privacy, isNot(contains('proposed WorkoutTracker Terms')));
      expect(terms, contains('Effective date: July 11, 2026'));
      expect(terms, isNot(contains('Draft for owner review')));
      expect(terms, isNot(contains('Not in effect')));
      expect(terms, isNot(contains('proposed')));
      expect(terms, contains('Apple Standard EULA'));
      expect(terms, contains('source and object forms'));
      expect(terms, contains('Apache License 2.0'));
      expect(terms, contains('AS IS'));
      expect(terms, contains('not medical advice'));
      expect(
        terms,
        isNot(contains('Those open-source permissions are separate')),
      );
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
