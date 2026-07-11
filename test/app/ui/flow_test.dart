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
      final setup = flow.view as SetupView;
      expect(setup.setup.selectedWorkout, 'Legs');
      expect(setup.setup.selectedHistoryBlock, 'Week 1');

      await flow.loaded.setup(const OpenSelectedWorkout());
      expect(flow.view, isA<WorkoutView>());

      await flow.loaded.workout(const OpenWorkoutLog(3));
      final log = flow.view as LogView;
      expect(log.target.primaryRow, 3);
      expect(log.target.selectedRow, 3);

      await flow.loaded.close();
      expect(flow.view, isA<WorkoutView>());

      await flow.loaded.setup(const AddSetupPrimary('Legs'));
      final placement = flow.view as PlacementView;
      expect(placement.intent.kind, PlaceKind.primary);
      expect(placement.intent.workout, 'Legs');
      expect(placement.origin, PlaceOrigin.setup);
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

      await flow.loaded.setup(const OpenExerciseLibrary());
      expect(flow.view, isA<LibraryView>());

      await flow.loaded.create();
      final create = flow.view as CreateExerciseView;
      expect(create.origin, CreateOrigin.library);

      await flow.loaded.close();
      expect(flow.view, isA<LibraryView>());

      await flow.run(const ReturnToSheet());
      final sheet = flow.view as SheetView;
      expect(sheet.hasLoadedWorkout, isTrue);

      await flow.run(const ReturnToWorkout());
      expect(flow.view, isA<SetupView>());
    },
  );
}
