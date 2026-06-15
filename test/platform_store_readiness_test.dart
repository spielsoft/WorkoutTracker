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

      final issues = File('ISSUES_MVP.md').readAsStringSync();
      expect(
        issues,
        contains('- [x] Slice 17: App Store Readiness Validation'),
      );

      final blockers = File(
        'issues/slice_17_toolchain_blockers.md',
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
  });
}
