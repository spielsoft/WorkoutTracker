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
        containsAll({'public/index.html', 'public/privacy.html'}),
      );
    });

    test('publishes the Google Picker callback artifact contract', () {
      final callbackPage = File('public/google-picker-callback/index.html');

      expect(callbackPage.existsSync(), isTrue);

      final callbackHtml = callbackPage.readAsStringSync();

      expect(callbackHtml, contains('Google Picker callback'));
      expect(callbackHtml, contains('/google-picker-callback/'));
      expect(callbackHtml, contains('workouttracker://google-picker-callback'));
      expect(callbackHtml, contains('Open WorkoutTracker'));
      expect(callbackHtml, contains('Callback Contract'));

      for (final requiredParameter in [
        'state',
        'access_denied',
        'access_token',
        'account_email',
        'account_name',
        'account_photo',
        'error',
      ]) {
        expect(callbackHtml, contains(requiredParameter));
      }

      for (final idAlias in [
        'picked_file_ids',
        'picked_file_id',
        'picked_folder_ids',
        'picked_folder_id',
        'file_ids',
        'file_id',
        'folder_ids',
        'folder_id',
        'ids',
        'id',
      ]) {
        expect(callbackHtml, contains(idAlias));
      }

      for (final visibleStateText in [
        'Spreadsheet selected',
        'Selection cancelled',
        'Picker error',
        'Missing request state',
        'State mismatch',
        'Malformed callback',
      ]) {
        expect(callbackHtml, contains(visibleStateText));
      }

      expect(
        callbackHtml,
        contains('does not store workout data or act as an app backend'),
      );
      expect(callbackHtml, isNot(contains('/__/firebase/')));
      expect(callbackHtml, isNot(contains('firebase-app-compat')));
    });
  });
}
