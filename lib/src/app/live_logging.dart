import 'account_session.dart';
import 'validation_core.dart';
import 'workspace.dart';

final class LiveSet {
  const LiveSet({
    required this.blockLabel,
    required this.primaryRow,
    required this.selectedRow,
    required this.fields,
    required this.expectedRaw,
  });

  final String blockLabel;
  final int primaryRow;
  final int selectedRow;
  final Map<String, String> fields;
  final String expectedRaw;
}

/// Enters live validation through the same workspace and workbook contracts as
/// the application. Fixture reset remains an explicit test-only concern.
final class LiveLoggingEntry {
  const LiveLoggingEntry({required this.workspace, required this.svc});

  final WorkspaceLifecycle workspace;
  final WbkAccess svc;

  Future<ValReport> run(
    LiveSet set, {
    Future<void> Function()? beforeValidation,
  }) async {
    await workspace.restore();
    try {
      await workspace.signIn();
    } on GoogleSignInCfgError catch (error) {
      throw LiveCredentialsFailure(error);
    }
    if (workspace.state.accountProfile == null) {
      throw const LiveLoginCancelled();
    }

    final state = await workspace.chooseSheet();
    final selected = state.selectedSheet;
    if (selected == null) {
      throw const LiveFixtureSelectionCancelled();
    }
    if (state.accountMismatch != null) {
      throw StateError('The selected fixture is bound to another account.');
    }

    await beforeValidation?.call();
    final sess = svc.open(selected.id);
    final initial = await sess.read();
    _requireWritable(initial);
    final updated = await sess.execute(
      SaveSetCmd(
        blockLabel: set.blockLabel,
        sheetRow: set.selectedRow,
        fields: set.fields,
      ),
    );
    _requireWritable(updated);

    final reread = await sess.read();
    _requireWritable(reread);
    final context = reread.activeSheet.buildLoggingContext(
      primaryRow: set.primaryRow,
      selectedRow: set.selectedRow,
      blockLabel: set.blockLabel,
    );
    if (!context.selectedHistory.entries.any(
      (entry) => entry.rawValue == set.expectedRaw,
    )) {
      throw StateError(
        'Logged set was not found after rereading the development fixture.',
      );
    }
    return reread;
  }

  static void _requireWritable(ValReport report) {
    if (report.hasBlockingIssues) {
      throw StateError('The development fixture failed workbook validation.');
    }
    if (report.writeRejections.isNotEmpty) {
      throw StateError(
        report.writeRejections.map((issue) => issue.message).join(' '),
      );
    }
  }
}

final class LiveLoginCancelled implements Exception {
  const LiveLoginCancelled();

  @override
  String toString() => 'Google Sheets login was cancelled.';
}

final class LiveCredentialsFailure implements Exception {
  const LiveCredentialsFailure(this.cause);

  final GoogleSignInCfgError cause;

  @override
  String toString() => 'Google credentials are missing or invalid: $cause';
}

final class LiveFixtureSelectionCancelled implements Exception {
  const LiveFixtureSelectionCancelled();

  @override
  String toString() => 'Development fixture selection was cancelled.';
}
