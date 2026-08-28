// Local app preview. Runs the real application against an in-memory workbook
// so screens can be judged without a Google account. Not part of the shipped
// app, and not a validation tier: it proves nothing about Google, the schema
// contract, or any real workbook.
//
//   flutter run -t dev/gym_preview.dart -d <device-id>
//
// See docs/testing.md for the fixture shape and the simulator keyboard note.
import 'package:flutter/material.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

const _bench = '{Weight}x{Reps}@{RPE}';
const _stepUp = '({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}';
const _plank = '{Seconds}@{RPE}';

const _longWorkout = 'Functional Athleticism & Upper Body Power';

// Exercise | Sets | Rest | Tempo | Targets | Notes | Log Format | Workout |
// is_backup | is_exercise | <history...>
List<List<String>> _activeRows() {
  return [
    [
      ...activeSheetFixedColumns,
      'Week 1',
      '',
      '',
      'Week 2',
      '',
      '',
      'Week 3',
      '',
      '',
    ],
    [
      ...List.filled(activeSheetFixedColumns.length, ''),
      'S1',
      'S2',
      'S3',
      'S1',
      'S2',
      'S3',
      'S1',
      'S2',
      'S3',
    ],
    [
      'Barbell Bench Press',
      '3',
      '3 min',
      '2-1-1',
      '185x5@8',
      'Pause one second on the chest. Elbows tucked to 45 degrees.',
      _bench,
      'Push',
      '',
      'x',
      '175x5@7',
      '175x5@8',
      '175x4@9',
      '180x5@7',
      '180x5@8',
      '180x5@9',
      '185x5@8',
      '',
      '',
    ],
    [
      'Dumbbell Bench Press',
      '3',
      '2 min',
      '',
      '70x8@8',
      '',
      _bench,
      'Push',
      'TRUE',
      'x',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
    ],
    [
      'Overhead Press',
      '3',
      '2 min',
      '',
      '115x5@8',
      '',
      _bench,
      'Push',
      '',
      'x',
      '110x5@8',
      '110x5@8',
      '110x4@9',
      '115x5@8',
      '115x4@9',
      '',
      '',
      '',
      '',
    ],
    [
      'Cable Fly',
      '3',
      '90 s',
      '',
      '35x12@8',
      '',
      _bench,
      'Push',
      '',
      'x',
      '30x12@7',
      '30x12@8',
      '30x10@9',
      '35x12@8',
      '',
      '',
      '',
      '',
      '',
    ],
    [
      'Weighted Pull Up',
      '4',
      '3 min',
      '',
      '45x6@8',
      'Dead hang at the bottom of every rep.',
      _bench,
      _longWorkout,
      '',
      'x',
      '35x6@8',
      '35x6@8',
      '35x5@9',
      '',
      '45x6@8',
      '45x5@9',
      '',
      '',
      '',
    ],
    [
      'Barbell Row',
      '3',
      '2 min',
      '',
      '155x8@8',
      '',
      _bench,
      _longWorkout,
      '',
      'x',
      '145x8@7',
      '145x8@8',
      '145x8@9',
      '155x8@8',
      '',
      '',
      '',
      '',
      '',
    ],
    [
      'Back Squat',
      '5',
      '4 min',
      '3-1-1',
      '245x5@8',
      'Belt on from set three.',
      _bench,
      'Legs',
      '',
      'x',
      '235x5@7',
      '235x5@8',
      '235x5@8',
      '245x5@8',
      '245x5@9',
      '',
      '',
      '',
      '',
    ],
    [
      'DB Step-Up',
      '3',
      '2 min',
      '',
      '(12, 15)x8@8,0',
      'Box height in inches. Log knee pain zero to ten.',
      _stepUp,
      'Legs',
      '',
      'x',
      '(12, 15)x8@8,0',
      '(12, 15)x8@8,1',
      '',
      '(12, 20)x8@8,0',
      '',
      '',
      '',
      '',
      '',
    ],
    [
      'Romanian Deadlift',
      '3',
      '2 min',
      '',
      '185x10@8',
      '',
      _bench,
      'Legs',
      '',
      'x',
      '175x10@7',
      '175x10@8',
      '',
      '185x10@8',
      '',
      '',
      '',
      '',
      '',
    ],
    [
      'Front Plank',
      '3',
      '60 s',
      '',
      '45@7',
      'Hold until form breaks.',
      _plank,
      'Legs',
      '',
      'x',
      '45@7',
      '45@8',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
    ],
  ];
}

// Exercise | Description | Default Sets | Default Rest | Default Tempo |
// Notes | Log Format | Default Values
List<List<String>> _exercisesRows() {
  return [
    exercisesSheetColumns,
    [
      'Barbell Bench Press',
      'Flat barbell press.',
      '3',
      '3 min',
      '2-1-1',
      '',
      _bench,
      'x5@8',
    ],
    [
      'Dumbbell Bench Press',
      'Flat dumbbell press.',
      '3',
      '2 min',
      '',
      '',
      _bench,
      'x8@8',
    ],
    [
      'Overhead Press',
      'Standing strict press.',
      '3',
      '2 min',
      '',
      '',
      _bench,
      'x5@8',
    ],
    [
      'Cable Fly',
      'High-to-low cable fly.',
      '3',
      '90 s',
      '',
      '',
      _bench,
      'x12@8',
    ],
    [
      'Weighted Pull Up',
      'Pronated grip.',
      '4',
      '3 min',
      '',
      '',
      _bench,
      'x6@8',
    ],
    ['Barbell Row', 'Pendlay style.', '3', '2 min', '', '', _bench, 'x8@8'],
    ['Back Squat', 'High bar.', '5', '4 min', '3-1-1', '', _bench, 'x5@8'],
    [
      'DB Step-Up',
      'Dumbbells at sides.',
      '3',
      '2 min',
      '',
      '',
      _stepUp,
      '(12, )x8@8,0',
    ],
    ['Romanian Deadlift', 'Hip hinge.', '3', '2 min', '', '', _bench, 'x10@8'],
    ['Front Plank', 'Forearm plank.', '3', '60 s', '', '', _plank, '@7'],
  ];
}

// Active row N (3-based) references Exercises row N - 1.
List<CellFormula> _formulas(int activeRowCount) {
  return [
    for (var row = 3; row < 3 + activeRowCount; row += 1) ...[
      CellFormula(
        sheetRowNumber: row,
        sheetColumnNumber: 1,
        formula: '=Exercises!A${row - 1}',
      ),
      CellFormula(
        sheetRowNumber: row,
        sheetColumnNumber: 7,
        formula: '=Exercises!G${row - 1}',
      ),
    ],
  ];
}

ParsedActiveSheet _parse(List<List<String>> active, List<List<String>> exes) {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: active,
      exercisesRows: exes,
      cellFormulas: _formulas(active.length - 2),
    ),
  );
}

class _MemoryIo implements WbkIo {
  _MemoryIo() : _active = _activeRows(), _exes = _exercisesRows();

  List<List<String>> _active;
  List<List<String>> _exes;

  @override
  Future<ParsedActiveSheet> read() async => _parse(_active, _exes);

  @override
  Future<void> writeActive(ActiveSheetWritePlan plan) async {
    _active = plan
        .previewRowsAfterApplying(_active)
        .map((r) => r.toList())
        .toList();
  }

  @override
  Future<void> writeExercises(ExercisesWritePlan plan) async {
    _exes = plan
        .previewRowsAfterApplying(_exes)
        .map((r) => r.toList())
        .toList();
    _active = plan.formulaUpdates.isEmpty
        ? _active
        : ActiveSheetWritePlan(
            cellUpdates: plan.formulaUpdates,
          ).previewRowsAfterApplying(_active).map((r) => r.toList()).toList();
  }

  @override
  Future<void> writeExeUpdate(ExeUpdatePlan plan) async {
    await writeExercises(plan.exercises);
    await writeActive(plan.active);
  }
}

class _MemoryAccess implements WbkAccess {
  final _io = _MemoryIo();

  @override
  WbkSess open(String sheetId) => ValSess(sheetId: sheetId, io: _io);
}

const _sheet = SelectedSheet(
  spreadsheetId: 'gym-preview-sheet',
  name: '2026 Workouts',
  accountEmail: 'athlete@example.com',
);

class _MemoryStStore implements AppStStore {
  WorkspaceAccessSt _st = const WorkspaceAccessSt(
    sheetText: null,
    selectedSheet: _sheet,
    workoutSelection: WorkoutSelectionSt(
      spreadsheetId: 'gym-preview-sheet',
      workout: 'Push',
      historyBlock: 'Week 3',
    ),
  );

  @override
  Future<WorkspaceAccessSt> readWorkspaceSt() async => _st;

  @override
  Future<void> writeWorkspaceSt(WorkspaceAccessSt value) async => _st = value;

  @override
  Future<void> clearWorkspaceSt() async {
    _st = const WorkspaceAccessSt(
      sheetText: null,
      selectedSheet: null,
      workoutSelection: null,
    );
  }
}

void main() {
  runApp(
    WorkoutTrackerApp(
      svc: _MemoryAccess(),
      appStStore: _MemoryStStore(),
      initialSelection: _sheet,
    ),
  );
}
