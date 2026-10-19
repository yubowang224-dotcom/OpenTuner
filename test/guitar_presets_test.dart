import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/audio/audio_capture.dart';
import 'package:opentune_tuner/app.dart';
import 'package:opentune_tuner/audio/metronome_player.dart';
import 'package:opentune_tuner/audio/metronome_page.dart';
import 'package:opentune_tuner/audio/guitar_page.dart';
import 'package:opentune_tuner/audio/reference_player.dart';
import 'package:opentune_tuner/model/app_state.dart';
import 'package:opentune_tuner/model/guitar_tuning.dart';
import 'package:opentune_tuner/widgets/tuning_gauge.dart';

import 'app_test.dart' show navigate;
import 'audio_test.dart' show FixtureBridge, packet;
import 'stage25_test.dart' show ToneFixture;
import 'tools1_test.dart'
    show host, DelayedStopBridge, MetroFixture, metroPacket;

const truth = {
  'standard': [40, 45, 50, 55, 59, 64],
  'dropD': [38, 45, 50, 55, 59, 64],
  'dStandard': [38, 43, 48, 53, 57, 62],
  'halfDown': [39, 44, 49, 54, 58, 63],
  'dadgad': [38, 45, 50, 55, 57, 62],
  'openD': [38, 45, 50, 54, 57, 62],
  'openG': [38, 43, 50, 55, 59, 62],
};

Future<void> choose(WidgetTester t, String id) async {
  final dropdown = find.byKey(const ValueKey('guitar-preset'));
  await t.ensureVisible(dropdown);
  await t.pump();
  await t.tap(dropdown);
  await t.pumpAndSettle();
  final item = find.byKey(ValueKey('preset-option-$id')).last;
  await t.ensureVisible(item);
  await t.pumpAndSettle();
  final label = find.descendant(of: item, matching: find.byType(Text));
  expect(label.hitTestable(), findsOneWidget);
  await t.tap(label);
  for (var frame = 0; frame < 24; frame++) {
    await t.pump(const Duration(milliseconds: 16));
    expect(t.takeException(), isNull, reason: 'preset frame $frame');
    expect(find.byType(ErrorWidget), findsNothing);
  }
}

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  test(
    'all 42 targets have independent MIDI truth, string number and A4 scaling',
    () {
      expect(guitarPresets.length, 7);
      for (final p in guitarPresets) {
        expect(p.strings.map((s) => s.number), [6, 5, 4, 3, 2, 1]);
        for (var i = 0; i < 6; i++) {
          final hz = 440.0 * math.pow(2, (truth[p.id]![i] - 69) / 12);
          expect(p.strings[i].frequency(440), closeTo(hz, 1e-9));
          expect(p.strings[i].frequency(442), closeTo(hz * 442 / 440, 1e-9));
          expect(matchGuitar(hz, 440, p).index, i);
          expect(
            targetCents(hz * 2, p.strings[i].frequency(440)),
            closeTo(1200, 1e-9),
          );
          expect(matchGuitar(hz * math.pow(2, 12 / 1200), 440, p).index, i);
        }
        expect(
          matchGuitar(p.strings.first.frequency(440) / 2, 440, p).state,
          GuitarMatchState.outside,
        );
        expect(
          matchGuitar(p.strings.last.frequency(440) * 2, 440, p).state,
          GuitarMatchState.outside,
        );
        final mid = math.sqrt(
          p.strings[0].frequency(440) * p.strings[1].frequency(440),
        );
        expect(matchGuitar(mid, 440, p).state, GuitarMatchState.ambiguous);
        expect(matchGuitar(double.nan, 440, p).state, GuitarMatchState.invalid);
      }
    },
  );
  for (final preset in guitarPresets) {
    testWidgets(
      'manual/auto every string, invalid frames and no octave fold ${preset.id}',
      (t) async {
        var hz = preset.strings.first.frequency(440), validity = 2;
        final bridge = FixtureBridge()
          ..makePacket = (seq, details) =>
              packet(sequence: seq, validity: validity)
                ..[6] = hz
                ..[7] = hz;
        final capture = AudioCapture(bridge: bridge),
            tuner = GuitarTuner(capture: capture, preset: preset);
        await capture.start();
        for (var i = 0; i < 6; i++) {
          hz = preset.strings[i].frequency(440) * math.pow(2, 8 / 1200);
          tuner.manual(i);
          await t.pump(const Duration(milliseconds: 66));
          expect(tuner.target!.number, 6 - i);
          expect(tuner.cents, closeTo(8, 1e-6));
          tuner.setAutomatic(true);
          await t.pump(const Duration(milliseconds: 66));
          expect(tuner.selected, i);
          expect(tuner.cents, closeTo(8, 1e-6));
        }
        hz = preset.strings.last.frequency(440) * 2;
        await t.pump(const Duration(milliseconds: 66));
        expect(tuner.matchState, GuitarMatchState.outside);
        expect(tuner.cents, isNull);
        validity = 1;
        await t.pump(const Duration(milliseconds: 33));
        expect(tuner.cents, isNull);
        tuner.dispose();
        capture.dispose();
        await t.pump();
      },
    );
  }
  testWidgets(
    'preset model rejects retained frame and clears pending auto target',
    (t) async {
      final bridge = FixtureBridge()
        ..makePacket = (seq, details) => packet(sequence: seq)
          ..[6] = 146.832383959
          ..[7] = 146.832383959;
      final c = AudioCapture(bridge: bridge);
      final tuner = GuitarTuner(capture: c);
      await c.start();
      await t.pump(const Duration(milliseconds: 33));
      expect(tuner.cents, isNotNull);
      tuner.setPreset(guitarPreset('dropD'));
      expect(tuner.cents, isNull);
      tuner.setAutomatic(true);
      await t.pump(const Duration(milliseconds: 33));
      expect(tuner.matchState, GuitarMatchState.confirming);
      tuner.setPreset(guitarPreset('openG'));
      expect(tuner.selected, isNull);
      expect(tuner.cents, isNull);
      await t.pump(const Duration(milliseconds: 33));
      expect(tuner.matchState, GuitarMatchState.confirming);
      await t.pump(const Duration(milliseconds: 33));
      expect(tuner.selected, isNotNull);
      tuner.dispose();
      c.dispose();
      await t.pump();
    },
  );
  testWidgets(
    'preset change clears old readout and ignores late poll; restart is explicit',
    (t) async {
      final state = AppState(), b = FixtureBridge(), tones = ToneFixture();
      final c = AudioCapture(bridge: b), p = ReferencePlayer(bridge: tones);
      await t.pumpWidget(
        host(GuitarPage(state: state, reference: p, capture: c)),
      );
      await c.start();
      await t.pump(const Duration(milliseconds: 66));
      expect(c.current, isNotNull);
      b.pendingPoll = Completer();
      await t.pump(const Duration(milliseconds: 33));
      await choose(t, 'dropD');
      expect(c.active, isFalse);
      expect(c.current, isNull);
      expect(b.starts, 1);
      final gauge = t.widget<TuningGauge>(find.byType(TuningGauge));
      expect(gauge.targetNote, 'D2');
      expect(gauge.reading.isValid, isFalse);
      b.pendingPoll!.complete({
        'status': 'running',
        'data': packet(sequence: 999)
          ..[6] = 73.416191979
          ..[7] = 73.416191979,
      });
      await t.pump();
      expect(c.current, isNull);
      expect(
        t.widget<TuningGauge>(find.byType(TuningGauge)).reading.isValid,
        isFalse,
      );
      await t.pumpWidget(const SizedBox());
      p.dispose();
      c.dispose();
      state.dispose();
    },
  );
  testWidgets(
    'delayed stop, mode and background cannot leave preset controls disabled',
    (t) async {
      final state = AppState(), b = DelayedStopBridge(), tones = ToneFixture();
      final c = AudioCapture(bridge: b), p = ReferencePlayer(bridge: tones);
      await t.pumpWidget(
        host(GuitarPage(state: state, reference: p, capture: c)),
      );
      b.hold = Completer();
      await choose(t, 'openD');
      await t.ensureVisible(find.byKey(const ValueKey('guitar-auto')));
      await t.tap(find.byKey(const ValueKey('guitar-auto')));
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      b.hold!.complete();
      b.hold = null;
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(
        t
            .widget<FilledButton>(find.byKey(const ValueKey('capture-toggle')))
            .onPressed,
        isNotNull,
      );
      await t.pumpWidget(const SizedBox());
      p.dispose();
      c.dispose();
      state.dispose();
    },
  );
  testWidgets(
    'all preset references carry actual target, guitar voice and gain; piano default stays sine',
    (t) async {
      final state = AppState(), b = FixtureBridge(), tones = ToneFixture();
      final c = AudioCapture(bridge: b), p = ReferencePlayer(bridge: tones);
      await t.pumpWidget(
        host(GuitarPage(state: state, reference: p, capture: c)),
      );
      for (final preset in guitarPresets) {
        if (state.selectedGuitarPreset.id != preset.id) {
          await choose(t, preset.id);
        }
        for (var i = 0; i < 6; i++) {
          final target = find.byKey(ValueKey('guitar-target-$i'));
          await t.ensureVisible(target);
          await t.pump();
          await t.tap(target);
          await t.pump();
          final play = find.byKey(const ValueKey('reference-toggle'));
          await t.ensureVisible(play);
          await t.pump();
          await t.tap(play);
          await t.pump();
          expect(
            tones.frequencies.last,
            closeTo(preset.strings[i].frequency(440), 1e-9),
          );
          expect(tones.timbres.last, ReferenceTimbre.guitar);
          expect(tones.gains.last, .8);
          await p.stop();
          await t.pump();
        }
      }
      await p.play('A4', 440);
      expect(tones.timbres.last, ReferenceTimbre.sine);
      expect(tones.gains.last, 1);
      await t.pumpWidget(const SizedBox());
      p.dispose();
      c.dispose();
      state.dispose();
    },
  );
  testWidgets(
    'changing preset cancels waiting play and sounding tone; gain change stops tone',
    (t) async {
      final state = AppState(), b = DelayedStopBridge(), tones = ToneFixture();
      final c = AudioCapture(bridge: b), p = ReferencePlayer(bridge: tones);
      await t.pumpWidget(
        host(GuitarPage(state: state, reference: p, capture: c)),
      );
      Future<void> play() async {
        final f = find.byKey(const ValueKey('reference-toggle'));
        await t.ensureVisible(f);
        await t.pump();
        await t.tap(f);
        await t.pump();
      }

      b.hold = Completer();
      await play();
      expect(tones.frequencies, isEmpty);
      // One delayed stop represents both pending old play and preset stop.
      await choose(t, 'dropD');
      b.hold!.complete();
      b.hold = null;
      await t.pump();
      expect(tones.frequencies, isEmpty);
      await play();
      expect(p.active, isTrue);
      await choose(t, 'openG');
      expect(p.active, isFalse);
      await play();
      expect(tones.frequencies.last, closeTo(73.416191979, 1e-8));
      final slider = t.widget<Slider>(
        find.byKey(const ValueKey('guitar-reference-gain')),
      );
      slider.onChanged!(.5);
      await t.pump();
      expect(p.active, isFalse);
      expect(state.guitarGain, .5);
      await play();
      expect(tones.gains.last, .5);
      await t.pumpWidget(const SizedBox());
      p.dispose();
      c.dispose();
      state.dispose();
    },
  );
  testWidgets(
    'Dart reference bridge transmits voice/gain; defaults remain sine; invalid gain rejected',
    (t) async {
      final messages = <MethodCall>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidReferenceBridge.channel,
        (call) async {
          messages.add(call);
          return {'status': 'playing', 'rate': 48000};
        },
      );
      const bridge = AndroidReferenceBridge();
      await bridge.start(110, timbre: ReferenceTimbre.guitar, gain: .8);
      expect(messages.last.arguments, {'hz': 110.0, 'voice': 1, 'gain': .8});
      await bridge.start(440);
      expect(messages.last.arguments, {'hz': 440.0, 'voice': 0, 'gain': 1.0});
      final tones = ToneFixture(), p = ReferencePlayer(bridge: tones);
      await expectLater(p.play('A2', 110, gain: 1.1), throwsArgumentError);
      await expectLater(
        p.play('A2', 110, gain: double.nan),
        throwsArgumentError,
      );
      expect(tones.frequencies, isEmpty);
      p.dispose();
      await t.pump();
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidReferenceBridge.channel,
        null,
      );
    },
  );
  for (final language in ['zh', 'en']) {
    testWidgets(
      'all preset layouts $language both themes/focus small and landscape',
      (t) async {
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        for (final preset in guitarPresets) {
          for (final theme in [ThemeMode.light, ThemeMode.dark]) {
            for (final focus in [false, true]) {
              for (final size in [const Size(320, 640), const Size(844, 390)]) {
                t.view.devicePixelRatio = 1;
                t.view.physicalSize = size;
                t.platformDispatcher.textScaleFactorTestValue =
                    size.width == 320 ? 2 : 1.3;
                final state = AppState()
                  ..setLocale(Locale(language))
                  ..setThemeMode(theme)
                  ..setMinimal(focus)
                  ..selectGuitarPreset(preset.id);
                await t.pumpWidget(OpenTuneApp(state: state));
                await t.pumpAndSettle();
                expect(
                  t.takeException(),
                  isNull,
                  reason: '${preset.id}/$theme/$focus/$size',
                );
                await t.drag(
                  find.byType(ListView).first,
                  const Offset(0, -2000),
                );
                await t.pumpAndSettle();
                expect(t.takeException(), isNull);
                await t.pumpWidget(const SizedBox());
                state.dispose();
              }
            }
          }
        }
      },
    );
  }
  testWidgets(
    'metronome live gain preserves owner, carries bridge params and validates ABI2',
    (t) async {
      final state = AppState(),
          bridge = MetroFixture(),
          player = MetronomePlayer(bridge: bridge);
      await t.pumpWidget(host(MetronomePage(state: state, player: player)));
      final start = find.byKey(const ValueKey('metro-toggle'));
      await t.ensureVisible(start);
      await t.tap(start);
      await t.pump();
      final count = bridge.starts.length;
      final slider = t.widget<Slider>(find.byKey(const ValueKey('metro-gain')));
      slider.onChanged!(50);
      await t.pump(const Duration(milliseconds: 60));
      expect(state.metroGain, 50);
      expect(bridge.starts.length, count);
      expect(bridge.updates.last.gain, 50);
      expect(bridge.stops, isEmpty);
      final data = [...metroPacket(), 50.0]..[0] = 2;
      expect(MetroSnapshot.decode(data, 17)!.config.gain, 50);
      data[16] = 101;
      expect(MetroSnapshot.decode(data, 17), isNull);
      expect(MetroSnapshot.decode(metroPacket(), 17)!.config.gain, 100);
      await t.pumpWidget(const SizedBox());
      player.dispose();
      state.dispose();
      await t.pump();
    },
  );
  testWidgets(
    'metronome channel gain start/update fields and no volume-system method',
    (t) async {
      final calls = <MethodCall>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidMetroBridge.channel,
        (call) async {
          calls.add(call);
          return {'status': 'accepted'};
        },
      );
      const bridge = AndroidMetroBridge();
      MetroConfig c(int gain) => MetroConfig(
        bpm: 120,
        beats: 4,
        denominator: 4,
        divisions: 1,
        accent: true,
        gain: gain,
      );
      await bridge.start(c(100), 11);
      await bridge.update(c(25), 11);
      expect(calls.map((v) => v.method), ['metroStart', 'metroUpdate']);
      expect((calls.first.arguments as Map)['gain'], 100);
      expect((calls.last.arguments as Map)['gain'], 25);
      expect(() => c(101), throwsArgumentError);
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidMetroBridge.channel,
        null,
      );
    },
  );
  testWidgets(
    'actual App preset then locale/theme/focus/navigation every frame',
    (t) async {
      var stops = 0;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        (call) async {
          if (call.method == 'stop') stops++;
          return null;
        },
      );
      final state = AppState()..setLocale(const Locale('en'));
      await t.pumpWidget(OpenTuneApp(state: state));
      await t.pumpAndSettle();
      await choose(t, 'openD');
      for (final language in ['zh', 'en']) {
        for (final theme in [ThemeMode.dark, ThemeMode.light]) {
          final selector = find.byKey(const ValueKey('guitar-preset'));
          await t.ensureVisible(selector);
          await t.pumpAndSettle();
          expect(selector.hitTestable(), findsOneWidget);
          await t.tap(selector);
          await t.pump(const Duration(milliseconds: 16));
          state.setLocale(Locale(language));
          state.setThemeMode(theme);
          state.setMinimal(!state.minimal);
          for (var frame = 0; frame < 24; frame++) {
            await t.pump(const Duration(milliseconds: 16));
            expect(t.takeException(), isNull);
            expect(find.byType(ErrorWidget), findsNothing);
          }
          final next = state.selectedGuitarPreset.id == 'openD'
              ? 'openG'
              : 'openD';
          final tile = t.widget<ExpansionTile>(
            find.byKey(
              const PageStorageKey<String>('guitar-preset-selector-v1'),
            ),
          );
          if (!tile.controller!.isExpanded) {
            await t.ensureVisible(selector);
            await t.pumpAndSettle();
            expect(selector.hitTestable(), findsOneWidget);
            await t.tap(selector);
            await t.pumpAndSettle();
          }
          final option = find.byKey(ValueKey('preset-option-$next'));
          await t.ensureVisible(option);
          await t.pumpAndSettle();
          expect(option.hitTestable(), findsOneWidget);
          await t.tap(option);
          for (var frame = 0; frame < 24; frame++) {
            await t.pump(const Duration(milliseconds: 16));
            expect(t.takeException(), isNull);
            expect(find.byType(ErrorWidget), findsNothing);
          }
          await navigate(t, 4);
          await navigate(t, 0);
          expect(state.selectedGuitarPreset.id, next);
          expect(
            t.widget<TuningGauge>(find.byType(TuningGauge)).targetNote,
            'D2',
          );
          expect(t.takeException(), isNull);
        }
      }
      expect(stops, greaterThan(0));
      await t.pumpWidget(const SizedBox());
      state.dispose();
      await t.pump();
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        null,
      );
    },
  );
}
