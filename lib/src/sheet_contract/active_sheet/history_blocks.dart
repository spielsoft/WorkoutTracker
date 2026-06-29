part of '../active_sheet.dart';

class HistoryBlock {
  HistoryBlock({
    required this.label,
    Iterable<HistorySetColumn> setColumns = const [],
  }) : setColumns = List<HistorySetColumn>.unmodifiable(setColumns);

  final String label;
  final List<HistorySetColumn> setColumns;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HistoryBlock &&
            label == other.label &&
            _listEquals(setColumns, other.setColumns);
  }

  @override
  int get hashCode => Object.hash(label, Object.hashAll(setColumns));

  @override
  String toString() {
    return 'HistoryBlock(label: $label, setColumns: $setColumns)';
  }
}

class HistorySetColumn {
  const HistorySetColumn({
    required this.label,
    required this.sheetColumnNumber,
  });

  final String label;
  final int sheetColumnNumber;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HistorySetColumn &&
            label == other.label &&
            sheetColumnNumber == other.sheetColumnNumber;
  }

  @override
  int get hashCode => Object.hash(label, sheetColumnNumber);

  @override
  String toString() {
    return 'HistorySetColumn('
        'label: $label, '
        'sheetColumnNumber: $sheetColumnNumber'
        ')';
  }
}

List<HistoryBlock> _discoverHistoryBlocks({
  required List<String> header,
  required List<String> setHeader,
  required int firstHistoryColumn,
}) {
  final builders = <_HistoryBlockBuilder>[];
  final historyWidth = _historyHeaderWidth(
    header: header,
    setHeader: setHeader,
  );
  for (
    var columnIndex = firstHistoryColumn;
    columnIndex < historyWidth;
    columnIndex += 1
  ) {
    final label = _cell(header, columnIndex).trim();
    if (label.isNotEmpty) {
      builders.add(_HistoryBlockBuilder(label));
    }

    if (builders.isEmpty) {
      continue;
    }

    final setLabel = _cell(setHeader, columnIndex).trim();
    if (setLabel.isNotEmpty) {
      builders.last.setColumns.add(
        HistorySetColumn(label: setLabel, sheetColumnNumber: columnIndex + 1),
      );
    }
  }
  return builders.map((builder) => builder.toBlock()).toList();
}

int _historyHeaderWidth({
  required List<String> header,
  required List<String> setHeader,
}) {
  return header.length > setHeader.length ? header.length : setHeader.length;
}

class _HistoryBlockBuilder {
  _HistoryBlockBuilder(this.label);

  final String label;
  final List<HistorySetColumn> setColumns = [];

  HistoryBlock toBlock() {
    return HistoryBlock(label: label, setColumns: setColumns);
  }
}
