import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/migration.dart';
import 'package:workout_tracker/sheets.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final enabled =
      Platform.environment['WORKOUT_TRACKER_RUN_LEGACY_FIELD_MIGRATION'] == '1';

  testWidgets('dry-runs or explicitly applies the owner field migration', (
    _,
  ) async {
    final spreadsheetId = Platform
        .environment['WORKOUT_TRACKER_LEGACY_MIGRATION_SPREADSHEET_ID']
        ?.trim();
    if (spreadsheetId == null || spreadsheetId.isEmpty) {
      throw StateError('Set the legacy migration spreadsheet ID.');
    }

    final auth = NativeSignInAuthGateway();
    addTearDown(auth.dispose);
    await auth.restoreAccount(scopes: GoogleApisWbkClient.writeScopes);
    if (auth.currentAccount == null &&
        !await auth.signIn(scopes: GoogleApisWbkClient.writeScopes)) {
      throw const LiveLoginCancelled();
    }

    final google = ScopedApiAccess(auth: auth);
    await google.run(
      scopes: GoogleApisWbkClient.writeScopes,
      action: (resources) async {
        final migrator = LegacyFieldMigrator(
          client: GoogleApisWbkClient(resources.sheetsApi),
          allowedSpreadsheetIds: [spreadsheetId],
        );
        final dryRun = await migrator.dryRun(spreadsheetId);
        // Live-only HITL output: the owner reviews this before setting confirm.
        // ignore: avoid_print
        print(_summary(dryRun));
        if (!dryRun.canApply) {
          throw StateError(dryRun.blockers.join(' '));
        }

        final confirmation = Platform
            .environment['WORKOUT_TRACKER_CONFIRM_LEGACY_FIELD_MIGRATION'];
        if (confirmation != spreadsheetId) {
          // ignore: avoid_print
          print('Dry run only; no workbook changes were applied.');
          return;
        }

        final applied = await migrator.migrate(spreadsheetId, confirmed: true);
        expect(applied.wasApplied, isTrue);
        expect(applied.refreshedSheet?.schemaViolations, isEmpty);
        // ignore: avoid_print
        print('Migration applied and refreshed validation passed.');
      },
    );
  }, skip: !enabled);
}

String _summary(LegacyFieldMigrationReport report) => [
  'Legacy field migration dry run for ${report.spreadsheetId}:',
  ...report.changes.map((change) => '- $change'),
  '- ${report.exerciseCount} canonical exercises',
  '- ${report.activeRowCount} active exercise rows',
  if (report.blockers.isEmpty)
    '- no blockers'
  else
    ...report.blockers.map((blocker) => '- BLOCKER: $blocker'),
].join('\n');
