import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/src/app/sheet_picker_page.dart';

void main() {
  testWidgets('sheet picker shows human labels without the opaque Drive ID', (
    tester,
  ) async {
    const opaqueId = '1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E';
    await tester.pumpWidget(
      MaterialApp(
        home: _PickerLauncher(
          req: SheetViewReq(
            accountEmail: 'athlete@example.com',
            load: (_) async => const [
              SheetEntry(id: opaqueId, name: 'Morning Log', owner: 'Athlete'),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();

    expect(find.text('Morning Log'), findsOneWidget);
    expect(find.textContaining('Athlete'), findsOneWidget);
    expect(find.textContaining(opaqueId), findsNothing);
  });
}

class _PickerLauncher extends StatelessWidget {
  const _PickerLauncher({required this.req});

  final SheetViewReq req;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => showSheetPickerPage(context, req),
          child: const Text('Choose'),
        ),
      ),
    );
  }
}
