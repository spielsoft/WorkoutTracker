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

    test('iOS Runner configs keep signing and bundle basics ready', () {
      final settingsByConfig = _iosRunnerBuildSettingsByConfig(
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(),
      );

      expect(
        settingsByConfig.keys,
        containsAll(['Debug', 'Release', 'Profile']),
      );

      for (final configName in ['Debug', 'Release', 'Profile']) {
        final settings = settingsByConfig[configName]!;

        expect(
          settings,
          _containsBuildSetting(
            'PRODUCT_BUNDLE_IDENTIFIER',
            'com.spielman.workouttracker',
          ),
          reason: '$configName must use the release-facing bundle id.',
        );
        expect(
          settings,
          _containsBuildSetting('INFOPLIST_FILE', 'Runner/Info.plist'),
          reason: '$configName must use the Runner Info.plist.',
        );
        expect(
          settings,
          _containsBuildSetting(
            'CURRENT_PROJECT_VERSION',
            r'"$(FLUTTER_BUILD_NUMBER)"',
          ),
          reason: '$configName must keep Flutter build-number substitution.',
        );
        expect(
          settings,
          _containsBuildSetting('CODE_SIGN_STYLE', 'Automatic'),
          reason: '$configName must be configured for automatic iOS signing.',
        );
        expect(
          settings,
          _containsBuildSetting('DEVELOPMENT_TEAM', 'K77H93FM2M'),
          reason: '$configName must match the existing Apple team.',
        );
      }
    });

    test('iOS Info.plist keeps Google client and version placeholders', () {
      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(
        infoPlist,
        contains(r'<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>'),
      );
      expect(
        infoPlist,
        contains(
          r'<string>$(WORKOUT_TRACKER_GOOGLE_REVERSED_CLIENT_ID)</string>',
        ),
      );
      expect(
        infoPlist,
        contains(r'<string>$(WORKOUT_TRACKER_GOOGLE_CLIENT_ID)</string>'),
      );
      expect(infoPlist, contains(r'<string>$(FLUTTER_BUILD_NAME)</string>'));
      expect(infoPlist, contains(r'<string>$(FLUTTER_BUILD_NUMBER)</string>'));
    });

    test('documents future App Store submission needs', () {
      final readiness = File('APP_STORE.md').readAsStringSync();

      for (final requiredTopic in [
        'iOS/iPadOS App Store release',
        'bundle identifier',
        'signing',
        'TestFlight',
        'OAuth consent',
        'privacy policy',
        'App metadata',
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

    test('macOS main window is visible at launch', () {
      final mainMenu = File(
        'macos/Runner/Base.lproj/MainMenu.xib',
      ).readAsStringSync();
      final appDelegate = File(
        'macos/Runner/AppDelegate.swift',
      ).readAsStringSync();

      expect(
        mainMenu,
        contains(RegExp(r'<window\b[^>]*visibleAtLaunch="YES"')),
        reason:
            'The release app must open a visible window for GUI validation.',
      );
      expect(
        appDelegate,
        contains('mainFlutterWindow?.makeKeyAndOrderFront(nil)'),
        reason:
            'The app delegate must explicitly order the Flutter window front.',
      );
    });

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

Map<String, String> _iosRunnerBuildSettingsByConfig(String project) {
  final runnerTarget = RegExp(
    r'[A-F0-9]{24} /\* Runner \*/ = \{.*?buildConfigurationList = '
    r'([A-F0-9]{24}) /\* Build configuration list for PBXNativeTarget "Runner" \*/;',
    dotAll: true,
  ).firstMatch(project);
  expect(runnerTarget, isNotNull);

  final configurationListId = runnerTarget!.group(1)!;
  final configurationList = RegExp(
    '${RegExp.escape(configurationListId)} '
    r'/\* Build configuration list for PBXNativeTarget "Runner" \*/ = \{'
    r'.*?buildConfigurations = \((.*?)\);',
    dotAll: true,
  ).firstMatch(project);
  expect(configurationList, isNotNull);

  final settingsByConfig = <String, String>{};
  for (final configRef in RegExp(
    r'([A-F0-9]{24}) /\* (Debug|Release|Profile) \*/',
  ).allMatches(configurationList!.group(1)!)) {
    final configId = configRef.group(1)!;
    final configName = configRef.group(2)!;
    final configBlock = RegExp(
      '${RegExp.escape(configId)} /\\* $configName \\*/ = \\{'
      r'.*?buildSettings = \{(.*?)\};'
      r'\s*name = ',
      dotAll: true,
    ).firstMatch(project);
    expect(configBlock, isNotNull);
    settingsByConfig[configName] = configBlock!.group(1)!;
  }

  return settingsByConfig;
}

Matcher _containsBuildSetting(String key, String value) {
  return contains(RegExp('${RegExp.escape(key)} = ${RegExp.escape(value)};'));
}
