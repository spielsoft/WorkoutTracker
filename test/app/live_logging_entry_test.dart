import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

import 'service_fake.dart';

void main() {
  group('live logging entry', () {
    test(
      'uses workspace selection and the public workbook logging command',
      () async {
        final svc = TestValSvc.fromRows([
          [...activeSheetFixedColumns, 'Week 1'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
          ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
        ]);
        final account = _Account();
        final workspace = WorkspaceCtrl(
          accountSession: account,
          picker: _Picker(account),
        );
        final entry = LiveLoggingEntry(workspace: workspace, svc: svc);
        addTearDown(workspace.dispose);

        final report = await entry.run(
          const LiveSet(
            blockLabel: 'Week 1',
            primaryRow: 3,
            selectedRow: 3,
            fields: {'Weight': '225', 'Reps': '5', 'RPE': '8'},
            expectedRaw: '225x5@8',
          ),
        );

        expect(svc.spreadsheetIds, ['fixture-id']);
        expect(svc.appliedPlans, hasLength(1));
        expect(
          report.activeSheet
              .buildLoggingContext(
                primaryRow: 3,
                selectedRow: 3,
                blockLabel: 'Week 1',
              )
              .selectedHistory
              .entries
              .single
              .rawValue,
          '225x5@8',
        );
      },
    );

    test('reports cancelled login distinctly', () async {
      final workspace = WorkspaceCtrl(
        accountSession: _Account(cancel: true),
        picker: _Picker(_Account()),
      );
      final entry = LiveLoggingEntry(
        workspace: workspace,
        svc: TestValSvc.fromRows(const []),
      );
      addTearDown(workspace.dispose);

      await expectLater(entry.run(_set), throwsA(isA<LiveLoginCancelled>()));
    });

    test('reports account configuration failures distinctly', () async {
      final workspace = WorkspaceCtrl(
        accountSession: _Account(cfgError: true),
        picker: _Picker(_Account()),
      );
      final entry = LiveLoggingEntry(
        workspace: workspace,
        svc: TestValSvc.fromRows(const []),
      );
      addTearDown(workspace.dispose);

      await expectLater(
        entry.run(_set),
        throwsA(isA<LiveCredentialsFailure>()),
      );
    });
  });
}

const _set = LiveSet(
  blockLabel: 'Week 1',
  primaryRow: 3,
  selectedRow: 3,
  fields: {'Weight': '225', 'Reps': '5', 'RPE': '8'},
  expectedRaw: '225x5@8',
);

class _Account extends ChangeNotifier implements GoogleAccountSession {
  _Account({this.cancel = false, this.cfgError = false});

  final bool cancel;
  final bool cfgError;
  GoogleAccountProfile? _account;

  @override
  GoogleAccountProfile? get currentAccount => _account;

  @override
  Future<void> restoreAccount({List<String> scopes = const []}) async {}

  @override
  Future<bool> signIn({List<String> scopes = const []}) async {
    if (cfgError) {
      throw const GoogleSignInCfgError(
        'Malformed WORKOUT_TRACKER_GOOGLE_CLIENT_ID.',
      );
    }
    if (cancel) return false;
    _account = const GoogleAccountProfile(email: 'maintainer@example.com');
    notifyListeners();
    return true;
  }

  @override
  Future<void> signOut() async {
    _account = null;
    notifyListeners();
  }
}

class _Picker implements SheetPicker {
  const _Picker(this.account);

  final GoogleAccountSession account;

  @override
  PickerAvail get availability => const PickerAvail.available();

  @override
  Future<SelectedSheet?> chooseSheet() async {
    return SelectedSheet(
      spreadsheetId: 'fixture-id',
      name: 'Development fixture',
      accountEmail: account.currentAccount?.email,
    );
  }

  @override
  Future<SelectedSheet?> createSheet({String? name}) async => null;
}
