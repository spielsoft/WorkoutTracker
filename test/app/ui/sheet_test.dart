import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';

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

  testWidgets('disables sheet actions until login', (tester) async {
    await tester.pumpWidget(
      _app(_view(showTextFallback: false), (_) async => const CmdResult.done()),
    );

    final choose = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Choose workout sheet'),
    );
    final create = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Create sheet'),
    );

    expect(choose.onPressed, isNull);
    expect(create.onPressed, isNull);
    expect(
      find.text(
        'Log in from the account menu to choose or create a workout sheet.',
      ),
      findsOneWidget,
    );
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
}) {
  return SheetView(
    isBusy: false,
    sheetText: '',
    selectedSheet: null,
    availability: const PickerAvail.available(),
    showAvailability: false,
    showTextFallback: showTextFallback,
    hasLoadedWorkout: false,
    report: null,
    account: account,
    hasPicker: true,
    showAccount: true,
    accountMismatch: accountMismatch,
  );
}
