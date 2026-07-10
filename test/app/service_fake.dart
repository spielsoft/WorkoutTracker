import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

class TestValSvc implements WbkAccess {
  TestValSvc(ParsedActiveSheet activeSheet)
    : _io = _MemoryWbkIo(activeSheet: activeSheet);

  TestValSvc.fromRows(List<List<String>> rows)
    : _io = _MemoryWbkIo(
        activeSheet: parseActiveSheet(ActiveSheetInput(rows: rows)),
        rows: rows,
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

class _MemoryWbkIo implements WbkIo {
  _MemoryWbkIo({required this.activeSheet, List<List<String>>? rows})
    : _rows = rows?.map((row) => row.toList()).toList();

  ParsedActiveSheet activeSheet;
  List<List<String>>? _rows;
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
    activeSheet = parseActiveSheet(ActiveSheetInput(rows: _rows!));
  }

  @override
  Future<void> writeExercises(ExercisesWritePlan plan) async {
    throw StateError('This in-memory workbook has no Exercises write fixture.');
  }
}
