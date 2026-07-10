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

      expect(flow.view, isA<SheetView>());

      expect((await flow.run(const ValidateSheet())).ok, isTrue);
      final setup = flow.view as SetupView;
      expect(setup.setup.selectedWorkout, 'Legs');
      expect(setup.setup.selectedHistoryBlock, 'Week 1');

      await flow.run(const OpenWorkout());
      expect(flow.view, isA<WorkoutView>());

      await flow.run(const OpenLog(3));
      final log = flow.view as LogView;
      expect(log.target.primaryRow, 3);
      expect(log.target.selectedRow, 3);

      await flow.run(const CloseLog());
      expect(flow.view, isA<WorkoutView>());

      await flow.run(const AddPrimary('Legs'));
      final placement = flow.view as PlacementView;
      expect(placement.intent.kind, PlaceKind.primary);
      expect(placement.intent.workout, 'Legs');
      expect(placement.returnRoute, AppRoute.setup);
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

      await flow.run(const SetSheetText(' spreadsheet-id '));
      expect((flow.view as SheetView).sheetText, ' spreadsheet-id ');
      await flow.run(const ValidateSheet());

      await flow.run(const OpenLibrary());
      expect(flow.view, isA<LibraryView>());

      await flow.run(const OpenExerciseCreate());
      final create = flow.view as CreateExerciseView;
      expect(create.returnRoute, AppRoute.library);

      await flow.run(const CloseExerciseCreate());
      expect(flow.view, isA<LibraryView>());

      await flow.run(const ReturnToSheet());
      final sheet = flow.view as SheetView;
      expect(sheet.hasLoadedWorkout, isTrue);

      await flow.run(const ReturnToWorkout());
      expect(flow.view, isA<SetupView>());
    },
  );
}
