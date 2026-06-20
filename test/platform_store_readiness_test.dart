import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('store readiness validation', () {
    test('keeps iOS, macOS, and Android packaging scaffolds present', () {
      expect(File('ios/Runner.xcodeproj/project.pbxproj').existsSync(), isTrue);
      expect(File('ios/Runner/Info.plist').existsSync(), isTrue);
      expect(
        File('macos/Runner.xcodeproj/project.pbxproj').existsSync(),
        isTrue,
      );
      expect(File('macos/Runner/Info.plist').existsSync(), isTrue);
      expect(File('android/app/build.gradle.kts').existsSync(), isTrue);
      expect(
        File('android/app/src/main/AndroidManifest.xml').existsSync(),
        isTrue,
      );
    });

    test('documents future App Store submission needs', () {
      final readiness = File('APP_STORE.md').readAsStringSync();

      for (final requiredTopic in [
        'iOS App Store',
        'bundle identifiers',
        'signing',
        'TestFlight',
        'OAuth consent',
        'privacy policy',
        'App Store Metadata',
        'Google Sheet',
      ]) {
        expect(readiness, contains(requiredTopic));
      }
    });

    test('documents iOS simulator validation alongside macOS validation', () {
      final authDocs = File(
        'docs/google_sheets_development_auth.md',
      ).readAsStringSync();

      expect(authDocs, contains('macOS GUI validation'));
      expect(authDocs, contains('iOS simulator validation'));
      expect(authDocs, contains('flutter build ios --simulator'));
      expect(authDocs, contains('native Google Sign-In'));
      expect(authDocs, contains('account-picker'));
    });

    test(
      'macOS release app keeps Google network and Picker callback access',
      () {
        final releaseEntitlements = File(
          'macos/Runner/Release.entitlements',
        ).readAsStringSync();

        expect(
          releaseEntitlements,
          contains('<key>com.apple.security.network.client</key>'),
        );
        expect(
          releaseEntitlements,
          contains('<key>com.apple.security.network.server</key>'),
        );
      },
    );

    test(
      'documents Google-backed sheet selection while auth remains wired',
      () {
        final readme = File('README.md').readAsStringSync();

        expect(readme, contains('Native Google Sign-In remains wired'));
        expect(readme, contains('Google Drive Picker is used'));
        expect(readme, contains('Google-backed sheet creation'));
      },
    );
  });
}
