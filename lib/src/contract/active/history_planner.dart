part of '../active.dart';

class _BlockWritePlanner {
  _BlockWritePlanner(this.context);

  final _WritePlanningContext context;

  ActiveSheetWritePlan planNewHistoryBlock({required String label}) {
    final sheetColumnNumber = activeSheetFixedColumns.length + 1;
    return ActiveSheetWritePlan(
      columnInsertions: [
        HistoryColumnInsertion(
          sheetColumnNumber: sheetColumnNumber,
          headers: [label],
          setLabels: const ['S1'],
        ),
      ],
      expectations: [context.insertExpct(sheetColumnNumber)],
    );
  }

  ActiveSheetWritePlan planHistoryBlockGrowth({
    required String label,
    required int throughSetNumber,
  }) {
    final block = context.sheet.selectHistoryBlock(label);
    if (block == null || throughSetNumber <= block.setColumns.length) {
      return ActiveSheetWritePlan();
    }

    final nextSetNumber = block.setColumns.length + 1;
    return ActiveSheetWritePlan(
      columnInsertions: [
        HistoryColumnInsertion(
          sheetColumnNumber: block.setColumns.last.sheetColumnNumber + 1,
          headers: List.filled(throughSetNumber - block.setColumns.length, ''),
          setLabels: [
            for (
              var setNumber = nextSetNumber;
              setNumber <= throughSetNumber;
              setNumber += 1
            )
              'S$setNumber',
          ],
        ),
      ],
      expectations: [
        SetColumnExpct(
          blockLabel: label,
          setNumber: block.setColumns.length,
          sheetColumnNumber: block.setColumns.last.sheetColumnNumber,
          setLabel: block.setColumns.last.label,
        ),
        context.insertExpct(block.setColumns.last.sheetColumnNumber + 1),
      ],
    );
  }
}
