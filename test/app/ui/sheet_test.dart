import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';

import '../../support/widget.dart';

void main() {
  testWidgets('offers login from the disconnected account menu', (
    tester,
  ) async {
    final cmds = <SheetCmd>[];
    await tester.pumpWidget(
      _app(_view(showTextFallback: false), (cmd) async {
        cmds.add(cmd);
        return const CmdResult.done();
      }),
    );

    await tester.tap(find.byTooltip('Connect Google Sheets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(cmds.single, isA<SignIn>());
  });

  testWidgets('emits typed selection and pasted-sheet commands', (
    tester,
  ) async {
    final cmds = <SheetCmd>[];
    await tester.pumpWidget(
      _app(_view(account: _account), (cmd) async {
        cmds.add(cmd);
        return const CmdResult.done();
      }),
    );

    await tester.tap(find.text('Choose workout sheet'));
    expect(cmds.removeLast(), isA<ChooseSheet>());

    await tester.enterText(
      find.byKey(const ValueKey('spreadsheet-selection-input')),
      'spreadsheet-id',
    );
    expect((cmds.last as SetSheetText).text, 'spreadsheet-id');

    await tester.tap(find.text('Select'));
    expect(cmds.last, isA<ValidateSheet>());
  });

  testWidgets('shows logged-out guidance without sheet actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_view(showTextFallback: false), (_) async => const CmdResult.done()),
    );

    expect(find.text('Not logged in'), findsOneWidget);
    expect(find.text('Log in from the account menu.'), findsOneWidget);
    expect(find.byTooltip('Connect Google Sheets'), findsOneWidget);
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(
      find.byKey(const ValueKey('choose-google-spreadsheet')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('create-google-spreadsheet')),
      findsNothing,
    );
  });

  testWidgets('shows a neutral restoring state without sheet actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _view(showTextFallback: false, isRestoring: true),
        (_) async => const CmdResult.done(),
      ),
    );

    expect(find.text('Connecting to Google Sheets…'), findsOneWidget);
    expect(find.text('Not logged in'), findsNothing);
    expect(find.text('Log in from the account menu.'), findsNothing);
    expect(find.byTooltip('Connect Google Sheets'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-restore-progress')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('choose-google-spreadsheet')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('create-google-spreadsheet')),
      findsNothing,
    );
  });

  testWidgets('shows the active account before sheet selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _view(showTextFallback: false, account: _account),
        (_) async => const CmdResult.done(),
      ),
    );

    expect(find.text('No workout sheet selected'), findsOneWidget);
    expect(find.text('athlete@example.com'), findsNothing);
    expect(
      find.byTooltip('Google Sheets account: athlete@example.com'),
      findsOneWidget,
    );
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(
      find.byKey(const ValueKey('choose-google-spreadsheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('create-google-spreadsheet')),
      findsOneWidget,
    );
  });

  testWidgets('uses the compact shared sheet title without a leading icon', (
    tester,
  ) async {
    const name = '2026_Summer_Workout_Program_With_A_Long_Name';
    await tester.pumpWidget(
      _app(
        _view(
          showTextFallback: false,
          account: _account,
          selectedSheet: const SelectedSheet(
            spreadsheetId: 'sheet-id',
            name: name,
            accountEmail: 'athlete@example.com',
          ),
        ),
        (_) async => const CmdResult.done(),
      ),
    );

    final title = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('selected-spreadsheet-label')),
        matching: find.byType(Text),
      ),
    );
    expect(title.data, name);
    expect(title.maxLines, 1);
    expect(title.softWrap, isFalse);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(find.byIcon(Icons.table_chart_outlined), findsNothing);
    expect(find.text('athlete@example.com'), findsNothing);
    expect(
      find.byTooltip('Google Sheets account: athlete@example.com'),
      findsOneWidget,
    );
  });

  testWidgets('emits a dismiss command when an error banner is tapped', (
    tester,
  ) async {
    final cmds = <SheetCmd>[];
    await tester.pumpWidget(
      _app(_view(error: 'Unable to open sheet: denied'), (cmd) async {
        cmds.add(cmd);
        return const CmdResult.done();
      }),
    );

    expect(find.text('Unable to open sheet'), findsOneWidget);
    expect(find.text('denied'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Dismiss error'));

    expect(cmds.single, isA<DismissSheetError>());
  });

  testWidgets('startup states remain accessible on a narrow large-text phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    for (final view in [
      _view(showTextFallback: false),
      _view(showTextFallback: false, isRestoring: true),
      _view(showTextFallback: false, account: _account),
    ]) {
      await tester.pumpWidget(_app(view, (_) async => const CmdResult.done()));
      expect(tester.takeException(), isNull);
      await expectFlutterAccessibilityGuidelines(tester);
    }
  });

  testWidgets('collects a name before creating a sheet', (tester) async {
    final cmds = <SheetCmd>[];
    await tester.pumpWidget(
      _app(_view(showTextFallback: false, account: _account), (cmd) async {
        cmds.add(cmd);
        return const CmdResult.done();
      }),
    );

    await tester.tap(find.text('Create sheet'));
    await tester.pumpAndSettle();
    expect(cmds, isEmpty);

    final field = find.byKey(const ValueKey('create-spreadsheet-name'));
    await tester.enterText(field, 'Training Log');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect((cmds.single as CreateSheet).name, 'Training Log');
  });

  testWidgets(
    'shows account state and emits sign out through the same contract',
    (tester) async {
      final cmds = <SheetCmd>[];
      await tester.pumpWidget(
        _app(
          _view(
            showTextFallback: false,
            account: const GoogleAccountProfile(
              email: 'athlete@example.com',
              displayName: 'Athlete',
            ),
          ),
          (cmd) async {
            cmds.add(cmd);
            return const CmdResult.done();
          },
        ),
      );

      await tester.tap(
        find.byTooltip('Google Sheets account: athlete@example.com'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(cmds.single, isA<SignOut>());
    },
  );

  testWidgets('requires explicit account rebinding confirmation', (
    tester,
  ) async {
    final cmds = <SheetCmd>[];
    await tester.pumpWidget(
      _app(
        _view(
          account: const GoogleAccountProfile(email: 'current@example.com'),
          accountMismatch: const AcctMismatch(
            sheet: SelectedSheet(
              spreadsheetId: 'saved-id',
              name: 'Saved',
              accountEmail: 'saved@example.com',
            ),
            savedEmail: 'saved@example.com',
            currentEmail: 'current@example.com',
          ),
        ),
        (cmd) async {
          cmds.add(cmd);
          return const CmdResult.done();
        },
      ),
    );

    expect(find.text('Saved sheet uses another account'), findsOneWidget);
    await tester.tap(find.text('Use current account'));
    expect(cmds.single, isA<ConfirmAccount>());
  });
}

const _account = GoogleAccountProfile(email: 'athlete@example.com');

Widget _app(SheetView view, Future<CmdResult> Function(SheetCmd cmd) run) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [SheetScreen(view: view, run: run)],
      ),
    ),
  );
}

SheetView _view({
  bool showTextFallback = true,
  GoogleAccountProfile? account,
  AcctMismatch? accountMismatch,
  SelectedSheet? selectedSheet,
  bool hasLoadedWorkout = false,
  bool isRestoring = false,
  String? error,
}) {
  return SheetView(
    isBusy: isRestoring,
    isRestoring: isRestoring,
    sheetText: '',
    selectedSheet: selectedSheet,
    availability: const PickerAvail.available(),
    showAvailability: false,
    showTextFallback: showTextFallback,
    hasLoadedWorkout: hasLoadedWorkout,
    report: null,
    account: account,
    hasPicker: true,
    showAccount: true,
    accountMismatch: accountMismatch,
    error: error,
  );
}
