part of '../active.dart';

class _SetWritePlanner {
  _SetWritePlanner({required this.context, required this.historyBlocks});

  final _WritePlanningContext context;
  final _BlockWritePlanner historyBlocks;

  ActiveSheetWritePlan planSetLoggingWrite({
    required String blockLabel,
    required int sheetRowNumber,
    required Map<String, String> fieldValues,
  }) {
    final slot = context.slotForRow(sheetRowNumber);
    final renderedSet = context.renderSetForRow(
      sheetRowNumber: sheetRowNumber,
      fieldValues: fieldValues,
    );
    if (renderedSet == null) {
      return ActiveSheetWritePlan();
    }

    final block = context.sheet.selectHistoryBlock(blockLabel);
    if (block == null) {
      return ActiveSheetWritePlan();
    }

    final row = context.sheet._sheetRow(sheetRowNumber);
    for (var index = 0; index < block.setColumns.length; index += 1) {
      final column = block.setColumns[index];
      if (_cell(row, column.sheetColumnNumber - 1).trim().isEmpty) {
        final setNumber = index + 1;
        return ActiveSheetWritePlan(
          cellUpdates: [
            CellUpdate(
              sheetRowNumber: sheetRowNumber,
              sheetColumnNumber: column.sheetColumnNumber,
              value: renderedSet,
            ),
          ],
          expectations: context.setCellExpcts(
            blockLabel: blockLabel,
            setNumber: setNumber,
            sheetRowNumber: sheetRowNumber,
            column: column,
          ),
          nextSetPosition: context.nextSetPosition(
            block: block,
            sheetRowNumber: sheetRowNumber,
            currentSetNumber: setNumber,
          ),
        );
      }
    }

    final newSetNumber = block.setColumns.length + 1;
    final growthPlan = historyBlocks.planHistoryBlockGrowth(
      label: blockLabel,
      throughSetNumber: newSetNumber,
    );
    final newSheetColumnNumber = block.setColumns.isEmpty
        ? activeSheetFixedColumns.length + 1
        : block.setColumns.last.sheetColumnNumber + 1;
    return ActiveSheetWritePlan(
      columnInsertions: growthPlan.columnInsertions,
      cellUpdates: [
        CellUpdate(
          sheetRowNumber: sheetRowNumber,
          sheetColumnNumber: newSheetColumnNumber,
          value: renderedSet,
        ),
      ],
      expectations: [
        ...context.exerciseRowExpcts(slot),
        ...growthPlan.expectations,
      ],
      nextSetPosition: SetPosition(
        sheetRowNumber: sheetRowNumber,
        setNumber: newSetNumber + 1,
        sheetColumnNumber: null,
      ),
    );
  }

  ActiveSheetWritePlan planSetEdit({
    required String blockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required Map<String, String> fieldValues,
  }) {
    final renderedSet = context.renderSetForRow(
      sheetRowNumber: sheetRowNumber,
      fieldValues: fieldValues,
    );
    if (renderedSet == null) {
      return ActiveSheetWritePlan();
    }

    return _planSetWrite(
      blockLabel: blockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
      value: renderedSet,
    );
  }

  ActiveSheetWritePlan planRawSetEdit({
    required String blockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required String rawText,
  }) {
    if (!context.isParsedExerciseRow(sheetRowNumber)) {
      return ActiveSheetWritePlan();
    }

    return _planSetWrite(
      blockLabel: blockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
      value: rawText,
    );
  }

  ActiveSheetWritePlan planSetClear({
    required String blockLabel,
    required int sheetRowNumber,
    required int setNumber,
  }) {
    if (!context.isParsedExerciseRow(sheetRowNumber)) {
      return ActiveSheetWritePlan();
    }

    return _planSetWrite(
      blockLabel: blockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
      value: '',
    );
  }

  ActiveSheetWritePlan _planSetWrite({
    required String blockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required String value,
  }) {
    final column = context.setColumn(
      blockLabel: blockLabel,
      setNumber: setNumber,
    );
    if (column == null) {
      return ActiveSheetWritePlan();
    }
    return ActiveSheetWritePlan(
      cellUpdates: [
        CellUpdate(
          sheetRowNumber: sheetRowNumber,
          sheetColumnNumber: column.sheetColumnNumber,
          value: value,
        ),
      ],
      expectations: context.setCellExpcts(
        blockLabel: blockLabel,
        setNumber: setNumber,
        sheetRowNumber: sheetRowNumber,
        column: column,
      ),
    );
  }
}
