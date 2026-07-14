import 'package:workout_tracker/sheets.dart';

import '../app/auth_client.dart';
import 'format_version.dart';
import 'legacy_fields.dart';
import 'model.dart';

class RoutedFieldMigrator implements FieldMigrator {
  RoutedFieldMigrator({
    required SheetsWorkbookClient client,
    required Iterable<String> allowedSpreadsheetIds,
  }) : _format = VersionFormatMigrator(
         client: client,
         allowedSpreadsheetIds: allowedSpreadsheetIds,
       ),
       _original = LegacyFieldMigrator(
         client: client,
         allowedSpreadsheetIds: allowedSpreadsheetIds,
       );

  final VersionFormatMigrator _format;
  final LegacyFieldMigrator _original;

  @override
  Future<WbkMigrationReport> dryRun(String spreadsheetId) async {
    final format = await _format.dryRun(spreadsheetId);
    if (format.sourceVersion != null) return format;
    return _original.dryRun(spreadsheetId);
  }

  @override
  Future<WbkMigrationReport> migrate(
    String spreadsheetId, {
    required bool confirmed,
    WbkMigrationReport? expected,
  }) async {
    final preview = expected ?? await dryRun(spreadsheetId);
    final kind = preview.kind;
    return switch (kind) {
      WbkMigrationKind.format09 => _format.migrate(
        spreadsheetId,
        confirmed: confirmed,
        expected: preview,
      ),
      WbkMigrationKind.originalFields => _original.migrate(
        spreadsheetId,
        confirmed: confirmed,
        expected: preview,
      ),
    };
  }
}

class GoogleFieldMigrator implements FieldMigrator {
  const GoogleFieldMigrator(this._google);

  final ApiAccess _google;

  @override
  Future<WbkMigrationReport> dryRun(String spreadsheetId) {
    return _run(spreadsheetId, (migrator) => migrator.dryRun(spreadsheetId));
  }

  @override
  Future<WbkMigrationReport> migrate(
    String spreadsheetId, {
    required bool confirmed,
    WbkMigrationReport? expected,
  }) {
    return _run(
      spreadsheetId,
      (migrator) => migrator.migrate(
        spreadsheetId,
        confirmed: confirmed,
        expected: expected,
      ),
    );
  }

  Future<T> _run<T>(
    String spreadsheetId,
    Future<T> Function(RoutedFieldMigrator migrator) action,
  ) {
    return _google.run(
      scopes: GoogleApisWbkClient.writeScopes,
      action: (resources) => action(
        RoutedFieldMigrator(
          client: GoogleApisWbkClient(resources.sheetsApi),
          allowedSpreadsheetIds: [spreadsheetId],
        ),
      ),
    );
  }
}
