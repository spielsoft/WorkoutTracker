import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/sheets.dart';

import 'auth_client.dart';
import 'validation_core.dart';
import 'validation_service.dart';

typedef WbkClientFact = SheetsWorkbookClient Function(sheets.SheetsApi api);

class SheetAccess implements WbkAccess {
  SheetAccess(this._google, {WbkClientFact? clientFactory})
    : _clientFactory = clientFactory ?? ((api) => GoogleApisWbkClient(api));

  final ApiAccess _google;
  final WbkClientFact _clientFactory;

  @override
  WbkSess open(String sheetId) {
    return ValSess(
      sheetId: sheetId,
      io: _ScopedWbkIo(
        sheetId: sheetId,
        google: _google,
        clientFactory: _clientFactory,
      ),
    );
  }
}

class _ScopedWbkIo implements WbkIo {
  const _ScopedWbkIo({
    required this.sheetId,
    required this.google,
    required this.clientFactory,
  });

  final String sheetId;
  final ApiAccess google;
  final WbkClientFact clientFactory;

  @override
  Future<ParsedActiveSheet> read() {
    return _run((read, _) => read.readParsedActiveSheet(sheetId));
  }

  @override
  Future<void> writeActive(ActiveSheetWritePlan plan) {
    return _run(
      (_, write) => write.applyWritePlan(spreadsheetId: sheetId, plan: plan),
    );
  }

  @override
  Future<void> writeExercises(ExercisesWritePlan plan) {
    return _run(
      (_, write) =>
          write.applyExercisesPlan(spreadsheetId: sheetId, plan: plan),
    );
  }

  @override
  Future<void> writeExeUpdate(ExeUpdatePlan plan) {
    return _run(
      (_, write) => write.applyExeUpdate(spreadsheetId: sheetId, plan: plan),
    );
  }

  Future<T> _run<T>(
    Future<T> Function(SheetsReadAdapter read, SheetsWriteAdapter write) action,
  ) {
    return google.run(
      scopes: GoogleApisWbkClient.writeScopes,
      action: (resources) {
        final client = clientFactory(resources.sheetsApi);
        return action(
          SheetsReadAdapter(client: client),
          SheetsWriteAdapter(client: client),
        );
      },
    );
  }
}
