import 'package:workout_tracker/contract.dart';

enum WbkMigrationKind { originalFields, format09 }

abstract interface class WbkStaleExpectation {}

abstract interface class WbkMigrationReport {
  String get spreadsheetId;

  List<String> get changes;

  List<String> get blockers;

  bool get recognized;

  bool get wasApplied;

  bool get alreadyCurrent;

  ParsedActiveSheet? get refreshedSheet;

  WbkMigrationKind get kind;

  bool get canApply;

  WbkStaleExpectation? get staleExpectation;
}

abstract interface class FieldMigrator {
  Future<WbkMigrationReport> dryRun(String spreadsheetId);

  Future<WbkMigrationReport> migrate(
    String spreadsheetId, {
    required bool confirmed,
    WbkMigrationReport? expected,
  });
}
