import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

import 'service_fake.dart';

void main() {
  testWidgets('typing replaces the generated sheet name', (tester) async {
    final picker = _RecordingSheetPicker();
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
    ]);

    await tester.pumpWidget(WorkoutTrackerApp(svc: service, picker: picker));
    await tester.pump();
    await tester.tap(find.text('Create sheet'));
    await tester.pumpAndSettle();

    final state = TextEditingValue.fromJSON(tester.testTextInput.editingState!);
    const typed = 'Custom Training Log';
    final updated = state.text.replaceRange(
      state.selection.start,
      state.selection.end,
      typed,
    );
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(
          offset: state.selection.start + typed.length,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pump();

    expect(picker.createNames, [typed]);
  });
}

class _RecordingSheetPicker implements SheetPicker {
  final createNames = <String?>[];

  @override
  PickerAvail get availability => const PickerAvail.available();

  @override
  Future<SelectedSheet?> chooseSheet() async => null;

  @override
  Future<SelectedSheet?> createSheet({String? name}) async {
    createNames.add(name);
    return null;
  }
}
