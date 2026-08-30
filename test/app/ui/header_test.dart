import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/src/app/ui/shared/a11y.dart';
import 'package:workout_tracker/src/app/ui/shared/header.dart';

import '../../support/widget.dart';

void main() {
  testWidgets('a header announces its label once, not once per visible copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _headerApp(const A11yHeader(label: 'Squat', child: Text('Squat'))),
    );

    expect(find.text('Squat'), findsOneWidget);

    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(A11yHeader)),
      matchesSemantics(label: 'Squat', isHeader: true),
    );
    expectHeadingLevel(tester, find.byType(A11yHeader), 1);
    semantics.dispose();
  });

  testWidgets('a screen header without a subtitle announces the title once', (
    tester,
  ) async {
    await tester.pumpWidget(
      _headerApp(
        ScreenHeader(
          title: 'Squat',
          backTooltip: 'Back to exercises',
          onBack: () {},
        ),
      ),
    );

    expect(find.text('Squat'), findsOneWidget);

    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(A11yHeader)),
      matchesSemantics(label: 'Squat', isHeader: true),
    );
    expectHeadingLevel(tester, find.byType(A11yHeader), 1);
    semantics.dispose();
  });

  testWidgets(
    'a screen header names its subtitle without repeating the title',
    (tester) async {
      await tester.pumpWidget(
        _headerApp(
          ScreenHeader(
            title: 'Squat',
            subtitle: 'Edit exercises',
            backTooltip: 'Back to exercises',
            onBack: () {},
          ),
        ),
      );

      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(A11yHeader)),
        matchesSemantics(label: 'Squat, Edit exercises', isHeader: true),
      );
      expectHeadingLevel(tester, find.byType(A11yHeader), 1);
      semantics.dispose();
    },
  );
}

Widget _headerApp(Widget header) {
  return MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Align(alignment: Alignment.topCenter, child: header),
      ),
    ),
  );
}
