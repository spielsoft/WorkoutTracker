import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

class TestValSvc implements WbkAccess {
  TestValSvc(ParsedActiveSheet activeSheet)
    : _io = _MemoryWbkIo(activeSheet: activeSheet);

  TestValSvc.fromRows(
    List<List<String>> rows, {
    List<List<String>> exercisesRows = const [],
    List<CellFormula> cellFormulas = const [],
  }) : _io = _MemoryWbkIo(
         activeSheet: parseActiveSheet(
           ActiveSheetInput(
             rows: _fieldRows(rows),
             exercisesRows: exercisesRows,
             cellFormulas: cellFormulas,
           ),
         ),
         rows: _fieldRows(rows),
         exercisesRows: exercisesRows,
         cellFormulas: cellFormulas,
       );

  final _MemoryWbkIo _io;
  final spreadsheetIds = <String>[];

  ParsedActiveSheet get activeSheet => _io.activeSheet;

  List<ActiveSheetWritePlan> get appliedPlans => _io.appliedPlans;

  @override
  WbkSess open(String sheetId) {
    spreadsheetIds.add(sheetId);
    return ValSess(sheetId: sheetId, io: _io);
  }
}

List<List<String>> _fieldRows(List<List<String>> rows) {
  return [
    for (var index = 0; index < rows.length; index += 1)
      if (index < 2 || rows[index].length > 9 && rows[index][9] == 'x')
        [...rows[index]]
      else
        _fieldRow(rows[index]),
  ];
}

List<String> _fieldRow(List<String> source) {
  final row = [
    ...source,
    ...List.filled(source.length < 10 ? 10 - source.length : 0, ''),
  ];
  final formatText = row[7].trim().isEmpty ? defaultExerciseLogFormat : row[7];
  final format = parseLogFormat(formatText);
  final targets = format is ParsedLogFormat
      ? format.renderValues({
          for (final label in format.fieldLabels)
            label: switch (label) {
              'Reps' || 'Seconds' => row[2],
              'RPE' => row[3],
              'Weight' || 'Pain' => '',
              _ => row[2],
            },
        })
      : '';
  return [
    row[0],
    row[1],
    row[4],
    row[5],
    targets,
    row[6],
    row[7],
    row[8],
    row[9],
    row[0].trim().isEmpty ? '' : 'x',
    ...source.skip(10),
  ];
}

class _MemoryWbkIo implements WbkIo {
  _MemoryWbkIo({
    required this.activeSheet,
    List<List<String>>? rows,
    this.exercisesRows = const [],
    this.cellFormulas = const [],
  }) : _rows = rows?.map((row) => row.toList()).toList();

  ParsedActiveSheet activeSheet;
  List<List<String>>? _rows;
  final List<List<String>> exercisesRows;
  final List<CellFormula> cellFormulas;
  final appliedPlans = <ActiveSheetWritePlan>[];

  @override
  Future<ParsedActiveSheet> read() async => activeSheet;

  @override
  Future<void> writeActive(ActiveSheetWritePlan plan) async {
    appliedPlans.add(plan);
    final rows = _rows;
    if (rows == null) {
      return;
    }
    _rows = plan
        .previewRowsAfterApplying(rows)
        .map((row) => row.toList())
        .toList();
    activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: _rows!,
        exercisesRows: exercisesRows,
        cellFormulas: cellFormulas,
      ),
    );
  }

  @override
  Future<void> writeExercises(ExercisesWritePlan plan) async {
    throw StateError('This in-memory workbook has no Exercises write fixture.');
  }

  @override
  Future<void> writeExeUpdate(ExeUpdatePlan plan) async {
    throw StateError('This in-memory workbook has no combined write fixture.');
  }
}
