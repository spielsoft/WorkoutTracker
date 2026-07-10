import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase Hosting static site artifacts', () {
    test(
      'publish product support and privacy pages without Firebase placeholder content',
      () {
        final supportPage = File('public/index.html');
        final privacyPage = File('public/privacy.html');

        expect(supportPage.existsSync(), isTrue);
        expect(privacyPage.existsSync(), isTrue);

        final supportHtml = supportPage.readAsStringSync();
        final privacyHtml = privacyPage.readAsStringSync();
        final combinedHtml = '$supportHtml\n$privacyHtml';

        expect(supportHtml, contains('WorkoutTracker'));
        expect(supportHtml, contains('user-owned Google Sheet'));
        expect(supportHtml, contains('support'));

        expect(privacyHtml, contains('Privacy Policy'));
        expect(privacyHtml, contains('user-owned Google Sheet'));
        expect(privacyHtml, contains('WorkoutTracker server'));
        expect(privacyHtml, contains('Google authorization'));

        for (final placeholderText in [
          'Welcome to Firebase Hosting',
          'Firebase Hosting Setup Complete',
          'Firebase SDK Loading',
          "Now it's time to go build something extraordinary",
        ]) {
          expect(combinedHtml, isNot(contains(placeholderText)));
        }

        expect(combinedHtml, isNot(contains('/__/firebase/')));
        expect(combinedHtml, isNot(contains('firebase-app-compat')));
      },
    );

    test('describes the hosted static pages without SPA fallback behavior', () {
      final firebaseConfig =
          jsonDecode(File('firebase.json').readAsStringSync())
              as Map<String, Object?>;
      final firebaseRc =
          jsonDecode(File('.firebaserc').readAsStringSync())
              as Map<String, Object?>;

      expect(
        firebaseRc,
        containsPair(
          'projects',
          containsPair('default', 'workouttracker-16285'),
        ),
      );

      expect(
        firebaseConfig,
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

      final publishedFiles = Directory('public')
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path)
          .toSet();

      expect(
        publishedFiles,
        {'public/index.html', 'public/privacy.html'},
      );
    });
  });
}
