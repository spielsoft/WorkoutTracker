import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/src/app/ui/shared/status.dart';

import '../../support/widget.dart';

void main() {
  testWidgets('status treatments adapt with contrast and non-color cues', (
    tester,
  ) async {
    final light = await _styles(tester, Brightness.light);
    final dark = await _styles(tester, Brightness.dark);

    for (final state in VisualSt.values) {
      expect(dark[state]!.background, isNot(light[state]!.background));
      expect(_contrast(light[state]!), greaterThanOrEqualTo(4.5));
      expect(_contrast(dark[state]!), greaterThanOrEqualTo(4.5));
    }
  });
}

Future<Map<VisualSt, _Style>> _styles(
  WidgetTester tester,
  Brightness brightness,
) async {
  final theme = ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0E7C66),
      brightness: brightness,
    ),
    useMaterial3: true,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      darkTheme: theme,
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: Scaffold(
        body: ListView(
          children: [
            for (final state in VisualSt.values)
              StChip(key: ValueKey(state), state: state, label: _label(state)),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await expectFlutterAccessibilityGuidelines(tester);
  final styles = <VisualSt, _Style>{};
  for (final state in VisualSt.values) {
    final chip = find.byKey(ValueKey(state));
    final label = find.descendant(of: chip, matching: find.text(_label(state)));
    expect(label, findsOne);
    expect(find.descendant(of: chip, matching: find.byType(Icon)), findsOne);
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: chip, matching: find.byType(DecoratedBox)),
    );
    final decoration = box.decoration as BoxDecoration;
    final text = tester.widget<Text>(label);
    styles[state] = _Style(decoration.color!, text.style!.color!);
  }
  return styles;
}

String _label(VisualSt state) => switch (state) {
  VisualSt.logged => 'Logged',
  VisualSt.current => 'Current',
  VisualSt.warning => 'Warning',
  VisualSt.error => 'Error',
};

double _contrast(_Style style) {
  final lighter =
      style.background.computeLuminance() > style.foreground.computeLuminance()
      ? style.background
      : style.foreground;
  final darker = identical(lighter, style.background)
      ? style.foreground
      : style.background;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

class _Style {
  const _Style(this.background, this.foreground);

  final Color background;
  final Color foreground;
}
