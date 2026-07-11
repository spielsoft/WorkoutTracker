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

  testWidgets('failed search replaces stale results with retry guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _PickerLauncher(
          req: SheetViewReq(
            load: (query) async {
              if (query == 'legs') {
                throw StateError('connection lost');
              }
              return const [SheetEntry(id: 'morning-id', name: 'Morning Log')];
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(find.text('Morning Log'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'legs');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Picker unavailable'), findsOneWidget);
    expect(find.textContaining('connection lost'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Morning Log'), findsNothing);
  });

  testWidgets('picker remains usable at narrow width with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: _PickerLauncher(
          req: SheetViewReq(
            accountEmail: 'athlete.with.a.long.address@example.com',
            load: (_) async => [
              SheetEntry(
                id: 'morning-id',
                name: 'Morning strength and conditioning log',
                owner: 'Athlete With A Long Name',
                viewedAt: DateTime(2026, 7, 11),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Choose workout sheet'), findsOneWidget);
    expect(find.text('Search Google Sheets'), findsOneWidget);
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
