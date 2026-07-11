import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

import 'service_fake.dart';

void main() {
  testWidgets('create sheet name starts selected so typing replaces default', (
    tester,
  ) async {
    final picker = _RecordingSheetPicker();
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(WorkoutTrackerApp(svc: service, picker: picker));
    await tester.pump();

    await tester.tap(find.text('Create sheet'));
    await tester.pump();

    final nameField = find.byKey(const ValueKey('create-spreadsheet-name'));
    expect(nameField, findsOneWidget);

    final editable = tester.widget<EditableText>(
      find.descendant(of: nameField, matching: find.byType(EditableText)),
    );
    final defaultName = editable.controller.text;
    expect(defaultName, isNotEmpty);
    editable.controller.selection = TextSelection.collapsed(
      offset: defaultName.length,
    );

    await tester.pumpAndSettle();

    final settledEditable = tester.widget<EditableText>(
      find.descendant(of: nameField, matching: find.byType(EditableText)),
    );
    expect(
      settledEditable.controller.selection,
      TextSelection(baseOffset: 0, extentOffset: defaultName.length),
    );

    _replaceSelectionWithText(tester, settledEditable, 'Custom Training Log');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pump();

    expect(picker.createNames, ['Custom Training Log']);
  });
}

void _replaceSelectionWithText(
  WidgetTester tester,
  EditableText editable,
  String text,
) {
  final value = editable.controller.value;
  final selection = value.selection;
  final replacement = value.text.replaceRange(
    selection.start,
    selection.end,
    text,
  );
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: replacement,
      selection: TextSelection.collapsed(offset: selection.start + text.length),
    ),
  );
}

class _RecordingSheetPicker implements SheetPicker {
  final createNames = <String?>[];

  @override
  PickerAvail get availability {
    return const PickerAvail.available();
  }

  @override
  Future<SelectedSheet?> chooseSheet() async {
    return null;
  }

  @override
  Future<SelectedSheet?> createSheet({String? name}) async {
    createNames.add(name);
    return null;
  }
}
