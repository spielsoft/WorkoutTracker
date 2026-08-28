import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/src/app/rest_timer.dart';
import 'package:workout_tracker/src/app/ui/shared/status.dart';

import '../../support/widget.dart';

void main() {
  testWidgets('rest bar draws from distinct theme roles with contrast', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0E7C66),
      brightness: Brightness.dark,
    );
    final ctrl = RestCtrl(signal: () async {});
    addTearDown(ctrl.dispose);
    ctrl.start(const Duration(seconds: 117));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: colors, useMaterial3: true),
        home: Scaffold(
          body: SafeArea(child: RestBar(ctrl: ctrl)),
        ),
      ),
    );

    final bar = tester.widget<Material>(
      find.byKey(const ValueKey('rest-timer')),
    );
    final countdown = tester.widget<Text>(find.text('117'));
    final add = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '+30 s'),
    );
    final done = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Done'),
    );

    expect(bar.color, colors.tertiaryContainer);
    expect(bar.color, isNot(colors.surface));
    expect(bar.color, isNot(stateStyle(colors, VisualSt.warning).background));
    expect(countdown.style?.color, colors.onTertiaryContainer);
    expect(
      add.style?.foregroundColor?.resolve(const <WidgetState>{}),
      colors.onTertiaryContainer,
    );
    expect(
      add.style?.side?.resolve(const <WidgetState>{})?.color,
      colors.tertiary,
    );
    expect(
      done.style?.backgroundColor?.resolve(const <WidgetState>{}),
      colors.tertiary,
    );
    expect(
      done.style?.foregroundColor?.resolve(const <WidgetState>{}),
      colors.onTertiary,
    );
    await expectFlutterAccessibilityGuidelines(tester);
    ctrl.done();
    await tester.pump();
  });
}
