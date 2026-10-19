import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/app.dart';
import 'package:opentune_tuner/main.dart' as entry;
import 'package:opentune_tuner/model/app_state.dart';
import 'package:opentune_tuner/theme.dart';
import 'package:opentune_tuner/model/ui_preferences.dart';

Future<void> frames(WidgetTester t, [int count = 24]) async {
  for (var i = 0; i < count; i++) {
    await t.pump(Duration(milliseconds: i == 0 ? 1 : 16));
    expect(t.takeException(), isNull, reason: 'frame $i');
    expect(
      find.byType(ErrorWidget),
      findsNothing,
      reason: 'ErrorWidget frame $i',
    );
  }
}

void main() {
  testWidgets(
    'system locale changes during open and reversing language popup cancel',
    (t) async {
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearLocalesTestValue);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(393, 852);
      t.platformDispatcher.localesTestValue = [const Locale('zh')];
      final state = AppState()..selectPage(4);
      await t.pumpWidget(OpenTuneApp(state: state));
      await frames(t, 24);
      for (var i = 0; i < 3; i++) {
        final menu = find.byKey(const ValueKey('language-system'));
        await t.ensureVisible(menu);
        await frames(t, 2);
        await t.tap(menu);
        await frames(t, 6);
        t.platformDispatcher.localesTestValue = [const Locale('en')];
        t.platformDispatcher.textScaleFactorTestValue = 1.3;
        t.view.physicalSize = const Size(390, 820);
        await frames(t, 4);
        await t.binding.handlePopRoute();
        await frames(t, 1);
        // Change the inherited inputs again during the reverse animation.
        t.platformDispatcher.localesTestValue = [const Locale('zh')];
        t.platformDispatcher.textScaleFactorTestValue = 1;
        t.view.physicalSize = const Size(393, 852);
        await frames(t, 24);
        expect(state.locale, isNull); // Cancel must preserve Follow system.
        expect(find.text('简单一点，刚刚好。'), findsOneWidget);
      }
      await t.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  test(
    'route guard preserves default transition delegation and theme equality',
    () {
      expect(buildTheme(), buildTheme());
      final actual =
          buildTheme().pageTransitionsTheme.builders[TargetPlatform.android]!;
      final original =
          const PageTransitionsTheme().builders[TargetPlatform.android]!;
      expect(actual.delegatedTransition, original.delegatedTransition);
    },
  );
  testWidgets(
    'license own tooltip covered by detail route then resize and back',
    (t) async {
      addTearDown(t.view.reset);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(393, 852);
      final state = AppState()
        ..selectPage(4)
        ..setLocale(const Locale('en'));
      await t.pumpWidget(OpenTuneApp(state: state));
      await frames(t, 24);
      await t.ensureVisible(find.byIcon(Icons.article_outlined));
      await frames(t, 2);
      await t.tap(find.byIcon(Icons.article_outlined));
      await frames(t, 30);
      t.state<TooltipState>(find.byType(Tooltip).first).ensureTooltipVisible();
      await frames(t, 20);
      Navigator.of(t.element(find.byType(BackButton).first)).push(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, a, b) =>
              const Scaffold(body: Text('Controlled package detail')),
        ),
      );
      await frames(t, 2);
      t.view.physicalSize = const Size(393, 820);
      await frames(t, 2);
      await t.binding.handlePopRoute();
      await frames(t, 24);
      await t.binding.handlePopRoute();
      await frames(t, 24);
      await t.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets(
    'visible-route hints survive dialog back without hidden portals',
    (t) async {
      addTearDown(t.view.reset);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(393, 852);
      final state = AppState()..selectPage(4);
      await t.pumpWidget(OpenTuneApp(state: state));
      await frames(t, 24);
      Finder rootHints() => find.descendant(
        of: find.byType(AppShell, skipOffstage: false),
        matching: find.byType(RawTooltip, skipOffstage: false),
        skipOffstage: false,
      );
      expect(rootHints(), findsWidgets);
      showDialog<void>(
        context: t.element(find.byIcon(Icons.article_outlined)),
        builder: (_) => const AlertDialog(title: Text('Route regression')),
      );
      await frames(t, 24);
      expect(rootHints(), findsNothing);
      await t.binding.handlePopRoute();
      await frames(t, 24);
      expect(rootHints(), findsWidgets);
      final tooltip = find.byType(Tooltip).first;
      expect(t.state<TooltipState>(tooltip).ensureTooltipVisible(), isTrue);
      await frames(t, 20);
      await t.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets(
    'real package license detail then Android back to list and settings',
    (t) async {
      addTearDown(t.view.reset);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(393, 852);
      LicenseRegistry.addLicense(
        () => Stream.value(
          const LicenseEntryWithLineBreaks([
            'OpenTuner regression package',
          ], 'Test-only license paragraph.'),
        ),
      );
      final state = AppState()
        ..selectPage(4)
        ..setLocale(const Locale('en'));
      await t.pumpWidget(OpenTuneApp(state: state));
      await frames(t, 20);
      await t.ensureVisible(find.byIcon(Icons.article_outlined));
      await frames(t, 2);
      await t.tap(find.byIcon(Icons.article_outlined));
      await frames(t, 30);
      final package = find.text('OpenTuner regression package');
      await t.ensureVisible(package);
      await frames(t, 2);
      await t.tap(package);
      await frames(t, 30);
      expect(find.text('Test-only license paragraph.'), findsOneWidget);
      await t.binding.handlePopRoute();
      await frames(t, 30);
      expect(find.text('OpenTuner regression package'), findsOneWidget);
      await t.binding.handlePopRoute();
      await frames(t, 30);
      expect(find.byIcon(Icons.article_outlined), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets('opaque license over live app tooltip resize system back', (
    t,
  ) async {
    addTearDown(t.view.reset);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(393, 852);
    final state = AppState()
      ..selectPage(4)
      ..setLocale(const Locale('zh'));
    await t.pumpWidget(OpenTuneApp(state: state));
    await frames(t, 20);
    final tooltip = find.byType(Tooltip).first;
    t.state<TooltipState>(tooltip).ensureTooltipVisible();
    await frames(t, 20);
    Navigator.of(t.element(find.byIcon(Icons.article_outlined))).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, a, b) =>
            const LicensePage(applicationName: 'OpenTuner'),
      ),
    );
    await frames(t, 2);
    t.view.physicalSize = const Size(393, 820);
    await frames(t, 2);
    await t.binding.handlePopRoute();
    await frames(t, 20);
    await t.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets('covered live guitar inherited changes and system return', (
    t,
  ) async {
    addTearDown(t.view.reset);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(393, 852);
    final state = AppState()..setLocale(const Locale('zh'));
    await t.pumpWidget(OpenTuneApp(state: state));
    await frames(t, 4);
    final context = t.element(find.byKey(const ValueKey('guitar-live-gauge')));
    showLicensePage(context: context, applicationName: 'OpenTuner');
    await frames(t, 30);
    for (var i = 0; i < 8; i++) {
      state.selectString(i % 6);
      state.setLocale(i.isEven ? const Locale('en') : const Locale('zh'));
      t.platformDispatcher.textScaleFactorTestValue = i.isEven ? 1.3 : 1;
      t.view.physicalSize = Size(i.isEven ? 390 : 393, i.isEven ? 820 : 852);
      await frames(t, 2);
    }
    await t.binding.handlePopRoute();
    await frames(t, 30);
    t.platformDispatcher.clearTextScaleFactorTestValue();
    await t.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets('actual dropdown selections during reverse route animation', (
    t,
  ) async {
    addTearDown(t.view.reset);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(393, 852);
    final state = AppState()
      ..selectPage(4)
      ..setLocale(const Locale('zh'));
    await t.pumpWidget(OpenTuneApp(state: state));
    await frames(t, 2);
    for (var i = 0; i < 10; i++) {
      final key = ValueKey(
        'language-${state.locale?.languageCode ?? 'system'}',
      );
      await t.ensureVisible(find.byKey(key));
      await frames(t, 1);
      await t.tap(find.byKey(key));
      await frames(t, 15);
      await t.tap(find.text(i.isEven ? 'English' : '简体中文').last);
      await frames(t, 1);
      // The popup is still reversing while inherited locale and page update.
      state.selectPage(0);
      await frames(t, 1);
      await t.binding.handlePopRoute();
      await frames(t, 2);
      state.selectPage(4);
      await frames(t, 24);
    }
    await t.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets(
    'actual startup license loading and predictive Android back commit/cancel',
    (t) async {
      addTearDown(t.view.reset);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(393, 852);
      t.platformDispatcher.localesTestValue = [const Locale('zh')];
      addTearDown(t.platformDispatcher.clearLocalesTestValue);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidUiPreferences.channel,
        (call) async => call.method == 'read'
            ? {'version': 1, 'theme': 'system', 'minimal': false}
            : null,
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          AndroidUiPreferences.channel,
          null,
        ),
      );
      await t.runAsync(() => Future<void>.sync(entry.main));
      await t.pump();
      await frames(t, 2);
      await t.tap(find.byKey(const ValueKey('nav-4')));
      await frames(t, 12);
      Future<void> gesture(String method, [double progress = 0]) async {
        await t.binding.defaultBinaryMessenger.handlePlatformMessage(
          SystemChannels.backGesture.name,
          SystemChannels.backGesture.codec.encodeMethodCall(
            MethodCall(method, {
              'touchOffset': <double>[progress * 393, 400],
              'progress': progress,
              'swipeEdge': 0,
            }),
          ),
          (_) {},
        );
      }

      for (final early in [1, 16, 100, 400]) {
        t.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: early.isEven);
        await t.ensureVisible(find.byIcon(Icons.article_outlined));
        await frames(t, 2);
        await t.tap(find.byIcon(Icons.article_outlined));
        await t.pump(Duration(milliseconds: early));
        expect(t.takeException(), isNull);
        await gesture('startBackGesture');
        await frames(t, 1);
        await gesture('updateBackGestureProgress', .6);
        await frames(t, 2);
        await gesture('cancelBackGesture');
        await frames(t, 30);
        await gesture('startBackGesture');
        await gesture('updateBackGestureProgress', .8);
        t.platformDispatcher.textScaleFactorTestValue = early.isEven ? 1.2 : 1;
        t.view.physicalSize = Size(393, early.isEven ? 820 : 852);
        await frames(t, 1);
        await gesture('commitBackGesture');
        await frames(t, 40);
        expect(find.byType(LicensePage), findsNothing);
      }
      await t.pumpWidget(const SizedBox());
      t.platformDispatcher.clearTextScaleFactorTestValue();
    },
  );
  testWidgets('tooltip alive under license route metrics then system back', (
    t,
  ) async {
    addTearDown(t.view.reset);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(393, 852);
    final state = AppState()
      ..selectPage(4)
      ..setLocale(const Locale('en'));
    await t.pumpWidget(OpenTuneApp(state: state));
    await frames(t, 30);
    await t.ensureVisible(find.byIcon(Icons.article_outlined));
    await frames(t, 2);
    final tooltip = find.byType(Tooltip).first;
    t.state<TooltipState>(tooltip).ensureTooltipVisible();
    await frames(t, 20);
    await t.tap(find.byIcon(Icons.article_outlined));
    await frames(t, 3);
    t.view.physicalSize = const Size(393, 820);
    await frames(t, 5);
    await t.binding.handlePopRoute();
    await frames(t, 30);
    await t.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets('license route then Android system back repeated every frame', (
    t,
  ) async {
    addTearDown(t.view.reset);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(393, 852);
    final state = AppState()
      ..selectPage(4)
      ..setLocale(const Locale('en'));
    await t.pumpWidget(OpenTuneApp(state: state));
    await frames(t, 30);
    for (var i = 0; i < 5; i++) {
      await t.ensureVisible(find.byIcon(Icons.article_outlined));
      await frames(t, 5);
      await t.tap(find.byIcon(Icons.article_outlined));
      await frames(t, 30);
      expect(find.byType(LicensePage), findsOneWidget);
      await t.binding.handlePopRoute();
      await frames(t, 30);
      expect(find.byType(LicensePage), findsNothing);
      expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    }
    await t.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets('cold startup metrics and language dropdown every frame', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    addTearDown(t.view.reset);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(393, 852);
    final state = AppState();
    await t.pumpWidget(OpenTuneApp(state: state));
    expect(t.takeException(), isNull);
    for (final size in [
      const Size(393, 820),
      const Size(393, 852),
      const Size(320, 640),
    ]) {
      t.view.physicalSize = size;
      await frames(t, 4);
    }
    for (var round = 0; round < 8; round++) {
      state.selectPage(4);
      await frames(t, 24);
      final key = 'language-${state.locale?.languageCode ?? 'system'}';
      await t.ensureVisible(find.byKey(ValueKey(key)));
      await frames(t, 2);
      await t.tap(find.byKey(ValueKey(key)));
      await frames(t, 2);
      // Change inherited locale while the popup route is entering/alive.
      state.setLocale(round.isEven ? const Locale('zh') : const Locale('en'));
      await frames(t, 4);
      await t.binding.handlePopRoute();
      await frames(t, 24);
      state.selectPage(round % 3);
      await frames(t, 2);
      state.selectPage(4);
      await frames(t, 10);
    }
    await t.pumpWidget(const SizedBox());
    state.dispose();
    await frames(t, 2);
    semantics.dispose();
  });
}
