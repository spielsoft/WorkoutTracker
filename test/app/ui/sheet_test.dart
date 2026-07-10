import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';

void main() {
  testWidgets('emits typed selection and pasted-sheet commands', (
    tester,
  ) async {
    final cmds = <SheetCmd>[];
    await tester.pumpWidget(
      _app(_view(), (cmd) async {
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

  testWidgets('authorizes creation before emitting the entered sheet name', (
    tester,
  ) async {
    final cmds = <SheetCmd>[];
    await tester.pumpWidget(
      _app(_view(showTextFallback: false), (cmd) async {
        cmds.add(cmd);
        return const CmdResult.done();
      }),
    );

    await tester.tap(find.text('Create sheet'));
    await tester.pumpAndSettle();
    expect(cmds.single, isA<AuthorizeCreate>());

    final field = find.byKey(const ValueKey('create-spreadsheet-name'));
    await tester.enterText(field, 'Training Log');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect((cmds.last as CreateSheet).name, 'Training Log');
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
}

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

SheetView _view({bool showTextFallback = true, GoogleAccountProfile? account}) {
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
  );
}
