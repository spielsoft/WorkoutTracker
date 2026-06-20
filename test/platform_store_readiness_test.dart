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

    test('documents future store submission needs before GUI work starts', () {
      final readiness = File(
        'docs/slice_17_app_store_readiness_validation.md',
      ).readAsStringSync();

      for (final requiredTopic in [
        'iOS App Store',
        'macOS App Store',
        'Android Play Store',
        'bundle identifiers',
        'signing',
        'entitlements',
        'OAuth consent',
        'privacy disclosures',
        'store metadata',
        'No blocking dependencies',
      ]) {
        expect(readiness, contains(requiredTopic));
      }

      final blockers = File(
        'docs/slice_17_toolchain_blockers.md',
      ).readAsStringSync();
      expect(blockers, contains('Xcode CoreSimulator Framework Missing'));
      expect(blockers, contains('Android SDK Not Configured'));
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
      'macOS release app keeps Google network access without a local server',
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
          isNot(contains('<key>com.apple.security.network.server</key>')),
        );
      },
    );

    test('documents disabled sheet selection while auth remains wired', () {
      final readme = File('README.md').readAsStringSync();

      expect(readme, contains('Native Google Sign-In remains wired'));
      expect(readme, contains('temporarily disabled'));
      expect(readme, contains('selection controls'));
    });
  });
}
