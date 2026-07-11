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
import 'workout_home.dart';
import 'ui/flow.dart';
import 'ui/sheet.dart';
import 'ui/view.dart';
import 'ui/shared/a11y.dart';

const _seed = Color(0xFF0E7C66);

ThemeData _theme(Brightness brightness) {
  return ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
    splashFactory: InkRipple.splashFactory,
    useMaterial3: true,
  );
}

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
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.dark,
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
  final _navKey = GlobalKey<NavigatorState>();

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
                final pages = _flow.pages;
                return PopScope<Object?>(
                  canPop: pages.length == 1,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop) _navKey.currentState?.maybePop();
                  },
                  child: Navigator(
                    key: _navKey,
                    pages: [
                      for (final page in pages)
                        if (page.view is SheetView ||
                            page.view is WorkoutHomeView)
                          _RootPage(
                            key: ValueKey(page.id),
                            child: _page(page.view),
                          )
                        else
                          MaterialPage<Object?>(
                            key: ValueKey(page.id),
                            child: _page(page.view),
                          ),
                    ],
                    onDidRemovePage: (page) {
                      final key = page.key;
                      if (key is ValueKey<Object>) _flow.didPop(key.value);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _page(AppView view) {
    final fullScreen = switch (view) {
      WorkoutHomeView() => WorkoutHomeScreen(view: view, actions: _flow.loaded),
      LibraryView() => _feature(
        view,
        ExerciseLibraryScreen(view: view, actions: _flow.loaded),
        fill: true,
      ),
      _ => null,
    };
    if (fullScreen != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: fullScreen,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: switch (view) {
              SheetView() => SheetScreen(
                view: view,
                run: (cmd) => _flow.run(cmd),
              ),
              CreateExerciseView() => _feature(
                view,
                CreateExerciseScreen(view: view, actions: _flow.loaded),
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
                showError: false,
              ),
              WorkoutHomeView() || LibraryView() => throw StateError(
                'This view must use its full-screen layout.',
              ),
              _ => throw StateError('Unsupported app view $view'),
            },
          ),
        ),
      ],
    );
  }

  Widget _feature(
    AppView view,
    Widget screen, {
    bool fill = false,
    bool showError = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showError)
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

final class _RootPage extends Page<Object?> {
  const _RootPage({required this.child, super.key});

  final Widget child;

  @override
  Route<Object?> createRoute(BuildContext context) {
    return _RootRoute(this);
  }
}

final class _RootRoute extends PageRoute<Object?> {
  _RootRoute(_RootPage page) : super(settings: page);

  _RootPage get _page => settings as _RootPage;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _page.child;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
