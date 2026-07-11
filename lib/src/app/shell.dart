import 'dart:ui';

import 'package:flutter/material.dart';
import 'state_store.dart';
import 'validation.dart';
import 'selection.dart';
import 'exercise_library.dart';
import 'exercise_create_screen.dart';
import 'exercise_edit_screen.dart';
import 'placement_screen.dart';
import 'logging.dart';
import 'repair.dart';
import 'setup.dart';
import 'workout_screen.dart';
import 'ui/flow.dart';
import 'ui/sheet.dart';
import 'ui/view.dart';
import 'ui/shared/a11y.dart';

class WorkoutTrackerApp extends StatelessWidget {
  const WorkoutTrackerApp({
    required this.svc,
    this.navigatorKey,
    this.accountSession,
    this.appStStore,
    this.initialText = '',
    this.initialSelection,
    this.picker,
    this.sheetOpener = const UrlSheetOpener(),
    super.key,
  });

  final WbkAccess svc;
  final GlobalKey<NavigatorState>? navigatorKey;
  final GoogleAccountSession? accountSession;
  final AppStStore? appStStore;
  final String initialText;
  final SelectedSheet? initialSelection;
  final SheetPicker? picker;
  final SheetOpener sheetOpener;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkoutTracker',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C66)),
        splashFactory: InkRipple.splashFactory,
        useMaterial3: true,
      ),
      scrollBehavior: const AppScrollBehavior(),
      home: AppShell(
        svc: svc,
        accountSession: accountSession,
        appStStore: appStStore,
        initialText: initialText,
        initialSelection: initialSelection,
        picker: picker,
        sheetOpener: sheetOpener,
      ),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices {
    return {
      PointerDeviceKind.touch,
      PointerDeviceKind.mouse,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
      PointerDeviceKind.trackpad,
    };
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.svc,
    this.accountSession,
    this.appStStore,
    required this.initialText,
    this.initialSelection,
    this.picker,
    required this.sheetOpener,
    super.key,
  });

  final WbkAccess svc;
  final GoogleAccountSession? accountSession;
  final AppStStore? appStStore;
  final String initialText;
  final SelectedSheet? initialSelection;
  final SheetPicker? picker;
  final SheetOpener sheetOpener;

  @override
  State<AppShell> createState() {
    return _AppShellSt();
  }
}

class _AppShellSt extends State<AppShell> {
  late final AppFlow _flow;
  late final Future<void> _init;

  @override
  void initState() {
    super.initState();
    _flow = AppFlow(
      svc: widget.svc,
      accountSession: widget.accountSession,
      appStStore: widget.appStStore,
      picker: widget.picker,
      sheetOpener: widget.sheetOpener,
      initialText: widget.initialText,
      initialSelection: widget.initialSelection,
    );
    _init = _flow.restore();
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: A11yScreen(
        label: 'WorkoutTracker',
        child: SafeArea(
          child: FutureBuilder<void>(
            future: _init,
            builder: (context, _) => ListenableBuilder(
              listenable: _flow,
              builder: (context, _) {
                final view = _flow.view;
                if (view case LibraryView()) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 840),
                        child: _feature(
                          view,
                          ExerciseLibraryScreen(
                            view: view,
                            actions: _flow.loaded,
                          ),
                          fill: true,
                        ),
                      ),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 840),
                      child: switch (view) {
                        SheetView() => SheetScreen(
                          view: view,
                          run: (cmd) => _flow.run(cmd),
                        ),
                        SetupView() => SetupScreen(
                          view: view,
                          actions: _flow.loaded,
                        ),
                        WorkoutView() => WorkoutScreen(
                          view: view,
                          actions: _flow.loaded,
                        ),
                        CreateExerciseView() => _feature(
                          view,
                          CreateExerciseScreen(
                            view: view,
                            actions: _flow.loaded,
                          ),
                        ),
                        EditExerciseView() => _feature(
                          view,
                          EditExerciseScreen(view: view, actions: _flow.loaded),
                        ),
                        PlacementView() => _feature(
                          view,
                          PlacementScreen(view: view, actions: _flow.loaded),
                        ),
                        LogView() => _feature(
                          view,
                          LogScreen(view: view, actions: _flow.loaded),
                        ),
                        LibraryView() => throw StateError(
                          'Library view must use its scrolling layout.',
                        ),
                        _ => throw StateError('Unsupported app view $view'),
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _feature(AppView view, Widget screen, {bool fill = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (view.error case final error?) ...[
          IssuePanel(
            icon: Icons.error_outline,
            title: 'Connection or validation failed',
            lines: [error],
            tone: IssueTone.error,
          ),
          const SizedBox(height: 16),
        ],
        if (fill) Expanded(child: screen) else screen,
      ],
    );
  }
}
