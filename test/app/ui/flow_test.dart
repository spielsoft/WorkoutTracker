import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

import '../service_fake.dart';

void main() {
  test(
    'routes typed views through workout, logging, and placement commands',
    () async {
      final flow = AppFlow(
        svc: TestValSvc.fromRows([
          [...activeSheetFixedColumns, 'Week 1'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
          ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '225x5@8'],
        ]),
        initialText: 'spreadsheet-id',
      );
      addTearDown(flow.dispose);
      await flow.restore();

      expect(flow.view, isA<SheetView>());

      expect((await flow.run(const ValidateSheet())).ok, isTrue);
      final setup = flow.view as WorkoutHomeView;
      expect(setup.sheetLabel, 'Workout sheet');
      expect(setup.setup.selectedWorkout, 'Legs');
      expect(setup.setup.selectedHistoryBlock, 'Week 1');

      await flow.loaded.home(const OpenWorkoutLog(3));
      final log = flow.view as LogView;
      expect(log.target.primaryRow, 3);
      expect(log.target.selectedRow, 3);

      await flow.loaded.close();
      expect(flow.view, isA<WorkoutHomeView>());

      await flow.loaded.home(const AddWorkoutPrimary('Legs'));
      final workoutPlacement = flow.view as PlacementView;
      expect(workoutPlacement.intent.workout, 'Legs');

      await flow.loaded.close();
      expect(flow.view, isA<WorkoutHomeView>());
    },
  );

  test(
    'keeps application navigation and workbook selection behind the flow',
    () async {
      final flow = AppFlow(
        svc: TestValSvc.fromRows([
          [...activeSheetFixedColumns, 'Week 1'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
          ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
        ]),
      );
      addTearDown(flow.dispose);
      await flow.restore();

      await flow.run(const SetSheetText(' spreadsheet-id '));
      expect((flow.view as SheetView).sheetText, ' spreadsheet-id ');
      await flow.run(const ValidateSheet());

      await flow.loaded.home(const OpenExerciseLibrary());
      expect(flow.view, isA<LibraryView>());

      await flow.loaded.create();
      expect(flow.view, isA<CreateExerciseView>());

      await flow.loaded.close();
      expect(flow.view, isA<LibraryView>());

      await flow.run(const ReturnToSheet());
      final sheet = flow.view as SheetView;
      expect(sheet.hasLoadedWorkout, isTrue);

      await flow.run(const ReturnToWorkout());
      expect(flow.view, isA<WorkoutHomeView>());
    },
  );

  test(
    'serializes loaded mutations across routes while read-only navigation remains available',
    () async {
      final access = _CmdAccess(_activeReport());
      final flow = AppFlow(svc: access, initialText: 'spreadsheet-id');
      addTearDown(flow.dispose);
      await flow.run(const ValidateSheet());

      final firstWrite = access.blockNext();
      final first = flow.loaded.execute(const RepairAllCmd());

      expect(flow.view, isA<WorkoutHomeView>());
      expect(flow.view.isBusy, isTrue);

      await flow.loaded.home(const OpenExerciseLibrary());
      expect(flow.view, isA<LibraryView>());
      expect(flow.view.isBusy, isTrue);

      final second = await flow.loaded.reorder(
        const ReorderIntent(fromIndex: 0, toIndex: 1),
      );

      expect(second, isFalse);
      expect(access.commands, hasLength(1));

      firstWrite.complete(access.report);
      expect(await first, isTrue);
      expect(flow.view.isBusy, isFalse);
    },
  );

  test('releases loaded mutation state after failure and success', () async {
    final access = _CmdAccess(_activeReport());
    final flow = AppFlow(svc: access, initialText: 'spreadsheet-id');
    addTearDown(flow.dispose);
    await flow.run(const ValidateSheet());

    final failedWrite = access.blockNext();
    final failed = flow.loaded.execute(const RepairAllCmd());

    expect(flow.view.isBusy, isTrue);
    failedWrite.completeError(StateError('write failed'));
    expect(await failed, isFalse);
    expect(flow.view.isBusy, isFalse);
    expect(flow.view.error, contains('write failed'));

    final successfulWrite = access.blockNext();
    final successful = flow.loaded.execute(const RepairAllCmd());

    expect(flow.view.isBusy, isTrue);
    successfulWrite.complete(access.report);
    expect(await successful, isTrue);
    expect(flow.view.isBusy, isFalse);
    expect(flow.view.error, isNull);
    expect(access.commands, hasLength(2));
  });
}

ValReport _activeReport() {
  return ValReport(
    spreadsheetId: 'spreadsheet-id',
    activeSheet: parseActiveSheet(
      ActiveSheetInput(
        rows: [
          [...activeSheetFixedColumns, 'Week 1'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
          ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
        ],
      ),
    ),
  );
}

final class _CmdAccess implements WbkAccess {
  _CmdAccess(this.report);

  final ValReport report;
  final commands = <WbkCmd>[];
  Completer<ValReport>? _next;

  Completer<ValReport> blockNext() {
    return _next = Completer<ValReport>();
  }

  @override
  WbkSess open(String sheetId) => _CmdSess(this, sheetId);

  Future<ValReport> execute(WbkCmd cmd) {
    commands.add(cmd);
    final next = _next;
    _next = null;
    return next?.future ?? Future.value(report);
  }
}

final class _CmdSess implements WbkSess {
  const _CmdSess(this._access, this.sheetId);

  final _CmdAccess _access;

  @override
  final String sheetId;

  @override
  Future<ValReport> execute(WbkCmd cmd) => _access.execute(cmd);

  @override
  Future<ValReport> read() async => _access.report;
}
