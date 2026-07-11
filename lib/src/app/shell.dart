import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'state_store.dart';
import 'validation.dart';
import 'selection.dart';
import 'setup.dart';
import 'workout.dart';
import 'workout_screen.dart';
import 'ui/flow.dart';
import 'ui/sheet.dart';
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
                          actions: _SetupFlowActions(_flow),
                        ),
                        WorkoutView() => WorkoutScreen(
                          view: view,
                          actions: _WorkoutFlowActions(_flow),
                        ),
                        FeatureView() => FeatureScreens(
                          view: view,
                          run: _flow.run,
                        ),
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
}

final class _SetupFlowActions implements SetupActions {
  const _SetupFlowActions(this.flow);

  final UiFlow flow;

  @override
  Future<void> run(SetupAction action) async {
    await flow.run(switch (action) {
      BackToSheets() => const ReturnToSheet(),
      OpenExerciseLibrary() => const OpenLibrary(),
      ChooseWorkout(:final workout) => SelectWorkout(workout),
      ChooseHistory(:final block) => SelectHistory(block),
      CreateWorkout(:final name) => AddWorkout(name),
      CreateHistory(:final label) => AddHistory(label),
      OpenSelectedWorkout() => const OpenWorkout(),
      OpenSetupLog(:final primaryRow) => OpenLog(primaryRow),
      AddSetupPrimary(:final workout) => AddPrimary(workout),
      AddSetupBackup(:final slot) => AddBackup(slot),
      DeleteSetupExercise(:final primaryRow) => DeleteWorkoutExercise(
        primaryRow,
      ),
    });
  }

  @override
  Future<bool> reorder(ReorderIntent intent) async {
    return (await flow.run(ReorderWorkout(intent))).ok;
  }
}

final class _WorkoutFlowActions implements WorkoutActions {
  const _WorkoutFlowActions(this.flow);

  final UiFlow flow;

  @override
  Future<void> run(WorkoutAction action) async {
    await flow.run(switch (action) {
      BackToWorkoutSetup() => const BackToSetup(),
      AddWorkoutPrimary(:final workout) => AddPrimary(workout),
      OpenWorkoutLog(:final primaryRow) => OpenLog(primaryRow),
      AddWorkoutBackup(:final slot) => AddBackup(slot),
      DeleteWorkoutRow(:final primaryRow) => DeleteWorkoutExercise(primaryRow),
    });
  }

  @override
  Future<bool> reorder(ReorderIntent intent) async {
    return (await flow.run(ReorderWorkout(intent))).ok;
  }
}
