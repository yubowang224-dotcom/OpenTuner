import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/app.dart';
import 'package:opentune_tuner/model/app_state.dart';
import 'package:opentune_tuner/model/ui_preferences.dart';
import 'package:opentune_tuner/theme.dart';
import 'package:opentune_tuner/audio/audio_capture.dart';
import 'package:opentune_tuner/audio/explore_page.dart';
import 'package:opentune_tuner/audio/guitar_page.dart';
import 'package:opentune_tuner/audio/reference_player.dart';
import 'package:opentune_tuner/l10n/generated/app_localizations.dart';
import 'package:opentune_tuner/widgets/tuning_gauge.dart';
import 'package:opentune_tuner/audio/metronome_page.dart';
import 'package:opentune_tuner/audio/metronome_player.dart';

import 'audio_test.dart' show FixtureBridge;
import 'stage25_test.dart' show ToneFixture;
import 'tools1_test.dart' show MetroFixture, config;
import 'app_test.dart' show navigate;

class PreferenceFixture implements UiPreferences {
  @override
  bool supported = true;
  Map<Object?, Object?> data = {
    'version': 1,
    'theme': 'system',
    'minimal': false,
  };
  Completer<Map<Object?, Object?>>? readPending;
  Completer<void>? writePending;
  bool readFails = false, writeFails = false;
  final writes = <Map<String, Object>>[];
  @override
  Future<Map<Object?, Object?>> read() async {
    if (readFails) throw StateError('read');
    return readPending?.future ?? Map.of(data);
  }

  @override
  Future<void> write(Map<String, Object> values) async {
    writes.add(Map.of(values));
    if (writeFails) throw StateError('write');
    await writePending?.future;
    data = Map.of(values);
  }
}

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

Widget host(AppState state, Widget Function() child) => ListenableBuilder(
  listenable: state,
  builder: (context, _) => MaterialApp(
    theme: buildTheme(),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: state.themeMode,
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child())),
  ),
);

void main() {
  testWidgets('focus switch returns from diagnostics scroll to main readout', (
    t,
  ) async {
    addTearDown(t.view.reset);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(393, 852);
    final a = AppState();
    await t.pumpWidget(OpenTuneApp(state: a));
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView).first, const Offset(0, -1000));
    await t.pumpAndSettle();
    expect(
      t.widget<ListView>(find.byType(ListView).first).controller!.offset,
      greaterThan(0),
    );
    a.setMinimal(true);
    await t.pumpAndSettle();
    expect(
      t.widget<ListView>(find.byType(ListView).first).controller!.offset,
      0,
    );
    expect(
      find.byKey(const ValueKey('gauge-note')).hitTestable(),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
    a.dispose();
  });
  testWidgets(
    'metronome theme and focus preference updates retain native session',
    (t) async {
      final a = AppState(), bridge = MetroFixture();
      final p = MetronomePlayer(bridge: bridge);
      await t.pumpWidget(host(a, () => MetronomePage(state: a, player: p)));
      await p.start(config());
      a.setThemeMode(ThemeMode.dark);
      a.setMinimal(true);
      await t.pump(const Duration(milliseconds: 66));
      expect(bridge.starts.length, 1);
      expect(bridge.stops, isEmpty);
      expect(p.active, isTrue);
      await t.pumpWidget(const SizedBox());
      p.dispose();
      a.dispose();
    },
  );
  testWidgets(
    'theme menu, language and focus changes preserve route back every frame',
    (t) async {
      final a = AppState()..selectPage(4);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await t.pumpWidget(OpenTuneApp(state: a));
      await t.pumpAndSettle();
      final menu = find.byKey(const ValueKey('theme-system'));
      await t.ensureVisible(menu);
      await t.pumpAndSettle();
      await t.tap(menu);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Dark').last);
      await t.pump(const Duration(milliseconds: 1));
      a.setLocale(const Locale('zh'));
      a.setMinimal(true);
      t.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      for (var i = 0; i < 32; i++) {
        await t.pump(const Duration(milliseconds: 16));
        expect(t.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
      }
      expect(a.themeMode, ThemeMode.dark);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await navigate(t, 0);
      expect(find.text('OpenTuner'), findsOneWidget);
      expect(find.byKey(const ValueKey('focus-tools')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('minimal-toggle')));
      await t.pumpAndSettle();
      expect(a.minimal, isFalse);
      await t.pumpWidget(const SizedBox());
      a.dispose();
    },
  );
  for (final locale in ['en', 'zh']) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      for (final minimal in [false, true]) {
        testWidgets('appearance layout $locale ${theme.name} focus $minimal', (
          t,
        ) async {
          addTearDown(t.view.reset);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          final a = AppState()
            ..setLocale(Locale(locale))
            ..setThemeMode(theme)
            ..setMinimal(minimal);
          for (final (size, scale) in [
            (const Size(320, 640), 2.0),
            (const Size(844, 390), 1.0),
          ]) {
            t.view.devicePixelRatio = 1;
            t.view.physicalSize = size;
            t.platformDispatcher.textScaleFactorTestValue = scale;
            await t.pumpWidget(OpenTuneApp(state: a));
            await t.pumpAndSettle();
            for (var page = 0; page < 5; page++) {
              await navigate(t, page);
              expect(t.takeException(), isNull, reason: 'page $page');
              await t.drag(find.byType(ListView).first, const Offset(0, -1800));
              await t.pumpAndSettle();
              expect(t.takeException(), isNull);
            }
          }
          await t.pumpWidget(const SizedBox());
          a.dispose();
        });
      }
    }
  }
  test(
    'appearance reload, late reads and coalesced final-write preference state',
    () async {
      final store = PreferenceFixture();
      final a = AppState(preferences: store);
      await a.restorePreferences();
      expect(a.preferencesSaving, isFalse);
      expect(a.preferencesError, isFalse);
      store.writePending = Completer();
      a.setThemeMode(ThemeMode.dark);
      expect(a.preferencesSaving, isTrue);
      await Future<void>.delayed(Duration.zero);
      a.setMinimal(true);
      a.setThemeMode(ThemeMode.light);
      a.setThemeMode(ThemeMode.dark);
      expect(store.writes.length, 1);
      store.writePending!.complete();
      await a.preferencesSettled;
      expect(store.writes.length, 2);
      expect(store.data, {
        'version': 2,
        'theme': 'dark',
        'minimal': true,
        'referenceHz': 440.0,
      });
      expect(a.preferencesSaving, isFalse);
      final b = AppState(preferences: store);
      await b.restorePreferences();
      expect(b.themeMode, ThemeMode.dark);
      expect(b.minimal, isTrue);
      expect(b.preferencesSaving, isFalse);
      store.readPending = Completer();
      final loading = b.restorePreferences();
      b.setThemeMode(ThemeMode.light);
      store.readPending!.complete({
        'version': 1,
        'theme': 'dark',
        'minimal': false,
      });
      await loading;
      await b.preferencesSettled;
      expect(b.themeMode, ThemeMode.light);
      expect(b.minimal, isTrue);
      a.dispose();
      b.dispose();
    },
  );
  test(
    'malformed read / failed write are visible and retry can succeed',
    () async {
      for (final data in [
        <Object?, Object?>{'version': 99, 'theme': 'dark', 'minimal': true},
        {'version': 1, 'theme': 'dark', 'minimal': .5},
      ]) {
        final a = AppState(preferences: PreferenceFixture()..data = data);
        await a.restorePreferences();
        expect(a.preferencesError, isTrue);
        expect(a.preferencesSaving, isFalse);
        expect(a.themeMode, ThemeMode.system);
        a.dispose();
      }
      final store = PreferenceFixture()
        ..readFails = true
        ..writeFails = true;
      final a = AppState(preferences: store);
      await a.restorePreferences();
      expect(a.preferencesError, isTrue);
      expect(a.preferencesSaving, isFalse);
      a.setMinimal(true);
      await a.preferencesSettled;
      expect(a.preferencesError, isTrue);
      expect(a.preferencesSaving, isFalse);
      store.writeFails = false;
      a.setThemeMode(ThemeMode.dark);
      await a.preferencesSettled;
      expect(a.preferencesError, isFalse);
      expect(a.preferencesSaving, isFalse);
      a.dispose();
    },
  );
  testWidgets(
    'unfinished read times out honestly; late result cannot alter user choice or active write',
    (t) async {
      final store = PreferenceFixture()..readPending = Completer();
      final a = AppState(preferences: store);
      final reading = a.restorePreferences();
      await t.pump(const Duration(milliseconds: 2001));
      await reading;
      expect(a.preferencesError, isTrue);
      expect(a.preferencesSaving, isFalse);
      expect(a.themeMode, ThemeMode.system);
      store.readPending!.complete({
        'version': 1,
        'theme': 'dark',
        'minimal': true,
      });
      await t.pump();
      expect(a.themeMode, ThemeMode.system);
      store.readPending = Completer();
      store.writePending = Completer();
      final second = a.restorePreferences();
      a.setThemeMode(ThemeMode.light);
      await t.pump();
      expect(a.preferencesSaving, isTrue);
      store.readPending!.complete({
        'version': 1,
        'theme': 'dark',
        'minimal': true,
      });
      await second;
      expect(a.preferencesSaving, isTrue);
      expect(a.themeMode, ThemeMode.light);
      store.writePending!.complete();
      await a.preferencesSettled;
      expect(a.preferencesSaving, isFalse);
      a.dispose();
    },
  );
  testWidgets(
    'native preference transport contains only settings scalars and reloads new state',
    (t) async {
      var values = <Object?, Object?>{
        'version': 1,
        'theme': 'system',
        'minimal': false,
      };
      final calls = <MethodCall>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidUiPreferences.channel,
        (c) async {
          calls.add(c);
          if (c.method == 'read') return Map.of(values);
          values = Map<Object?, Object?>.from(c.arguments as Map);
          return null;
        },
      );
      final a = AppState(preferences: const AndroidUiPreferences());
      await a.restorePreferences();
      a.setThemeMode(ThemeMode.dark);
      a.setMinimal(true);
      await a.preferencesSettled;
      a.dispose();
      final b = AppState(preferences: const AndroidUiPreferences());
      await b.restorePreferences();
      expect(b.themeMode, ThemeMode.dark);
      expect(b.minimal, isTrue);
      expect(values.keys.toSet(), {
        'version',
        'theme',
        'minimal',
        'referenceHz',
      });
      expect(calls.where((c) => c.method == 'read').length, 2);
      b.dispose();
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidUiPreferences.channel,
        null,
      );
    },
  );
  test('light/dark text and active scientific graphics contrast', () {
    for (final brightness in Brightness.values) {
      final theme = buildTheme(brightness), c = theme.colorScheme;
      for (final background in [c.surface, theme.scaffoldBackgroundColor]) {
        expect(contrast(c.onSurface, background), greaterThanOrEqualTo(4.5));
        expect(
          contrast(c.onSurfaceVariant, background),
          greaterThanOrEqualTo(4.5),
        );
        expect(contrast(c.primary, background), greaterThanOrEqualTo(3));
        expect(contrast(c.outline, background), greaterThanOrEqualTo(3));
      }
      expect(contrast(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5));
      expect(
        contrast(c.onPrimaryContainer, c.primaryContainer),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
  testWidgets(
    'system theme follows platform brightness; explicit light/dark override',
    (t) async {
      addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
      final a = AppState();
      await t.pumpWidget(OpenTuneApp(state: a));
      await t.pumpAndSettle();
      t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.byType(TuningGauge))).brightness,
        Brightness.dark,
      );
      a.setThemeMode(ThemeMode.light);
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.byType(TuningGauge))).brightness,
        Brightness.light,
      );
      a.setThemeMode(ThemeMode.dark);
      t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.byType(TuningGauge))).brightness,
        Brightness.dark,
      );
      await t.pumpWidget(const SizedBox());
      a.dispose();
    },
  );
  testWidgets(
    'guitar capture survives theme/focus; layout changes to target dropdown, true readings retained',
    (t) async {
      final state = AppState(), bridge = FixtureBridge(), tones = ToneFixture();
      final c = AudioCapture(bridge: bridge),
          p = ReferencePlayer(bridge: tones);
      await t.pumpWidget(
        host(state, () => GuitarPage(state: state, reference: p, capture: c)),
      );
      await c.start();
      await t.pump(const Duration(milliseconds: 66));
      final stops = bridge.stops;
      state.setMinimal(true);
      state.setThemeMode(ThemeMode.dark);
      await t.pump(const Duration(milliseconds: 250));
      expect(c.active, isTrue);
      expect(bridge.starts, 1);
      expect(bridge.stops, stops);
      expect(find.byKey(const ValueKey('guitar-focus-target')), findsOneWidget);
      expect(find.byKey(const ValueKey('guitar-target-0')), findsNothing);
      expect(find.byKey(const ValueKey('reference-toggle')), findsNothing);
      expect(t.widget<TuningGauge>(find.byType(TuningGauge)).minimal, isTrue);
      expect(
        t.widget<TuningGauge>(find.byType(TuningGauge)).reading.isValid,
        isTrue,
      );
      await c.stop();
      await p.play('E2', 82.406889);
      state.setMinimal(false);
      state.setThemeMode(ThemeMode.light);
      await t.pump(const Duration(milliseconds: 50));
      expect(p.active, isTrue);
      expect(find.byKey(const ValueKey('reference-toggle')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      c.dispose();
      p.dispose();
      state.dispose();
    },
  );
  testWidgets(
    'Explore focus retains lock, cancels visuals; theme retains current session',
    (t) async {
      final a = AppState(), b = FixtureBridge();
      final capture = AudioCapture(bridge: b);
      await t.pumpWidget(
        host(a, () => ExplorePage(state: a, capture: capture)),
      );
      await capture.start();
      await t.pump(const Duration(milliseconds: 66));
      capture.lockReference();
      capture.setDetails(true);
      a.setMinimal(true);
      a.setThemeMode(ThemeMode.dark);
      await t.pump(const Duration(milliseconds: 50));
      expect(capture.active, isTrue);
      expect(capture.referenceLocked, isTrue);
      expect(capture.details, isFalse);
      expect(b.starts, 1);
      expect(find.byKey(const ValueKey('live-waveform')), findsNothing);
      await t.pumpWidget(const SizedBox());
      capture.dispose();
      a.dispose();
    },
  );
}
