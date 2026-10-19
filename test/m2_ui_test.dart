import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/app.dart';
import 'package:opentune_tuner/audio/audio_capture.dart';
import 'package:opentune_tuner/audio/piano_page.dart';
import 'package:opentune_tuner/audio/reference_player.dart';
import 'package:opentune_tuner/model/app_state.dart';
import 'package:opentune_tuner/model/piano_model.dart';
import 'package:opentune_tuner/model/profile_store.dart';
import 'package:opentune_tuner/widgets/tuning_gauge.dart';

import 'audio_test.dart' show FixtureBridge, packet;
import 'stage25_test.dart' show ToneFixture;
import 'tools1_test.dart' show host;

Future<void> press(WidgetTester t, String key) async {
  final byValue = find.byKey(ValueKey(key));
  final item = byValue.evaluate().isEmpty
      ? find.byKey(PageStorageKey<String>(key))
      : byValue;
  await t.ensureVisible(item);
  await t.pumpAndSettle();
  expect(item.hitTestable(), findsOneWidget);
  await t.tap(item);
  await t.pumpAndSettle();
}

class MemoryProfiles implements ProfileStore {
  ProfileArchive value = ProfileArchive.empty();
  @override
  bool get supported => true;
  @override
  Future<ProfileArchive> load() async => value;
  @override
  Future<ProfileArchive> save(ProfileArchive next, int revision) async {
    if (value.revision != revision) {
      throw const ProfileException(ProfileIssue.conflict);
    }
    return value = next;
  }

  @override
  Future<ProfileArchive> recover() async => value;
}

void pianoWidgets(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await body(t);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          AndroidAudioBridge.channel,
          (_) async => null,
        );
  });
  tearDown(() {
    WidgetController.hitTestWarningShouldBeFatal = false;
  });

  pianoWidgets(
    'production reference bridge carries all 88 targets and sine at both A4 extrema',
    (t) async {
      final seen = <Map>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidReferenceBridge.channel,
        (call) async {
          if (call.method == 'toneStart') {
            seen.add(Map.of(call.arguments as Map));
          }
          return {'status': 'playing', 'rate': 48000};
        },
      );
      const bridge = AndroidReferenceBridge();
      for (final a4 in [400.0, 480.0]) {
        for (final key in pianoKeys) {
          await bridge.start(key.frequency(a4));
          expect(seen.last, {'hz': key.frequency(a4), 'voice': 0, 'gain': 1.0});
        }
      }
      expect(seen.length, 176);
    },
  );

  pianoWidgets(
    'piano manual target, measured pitch and invalidity are separate',
    (t) async {
      final state = AppState()..selectPianoNote('A0');
      final bridge = FixtureBridge();
      var hz = 55.0, valid = 2;
      bridge.makePacket = (seq, _) => packet(sequence: seq, validity: valid)
        ..[6] = hz
        ..[7] = hz
        ..[8] = (69 + 12 * math.log(hz / 440) / math.ln2).roundToDouble();
      final capture = AudioCapture(bridge: bridge),
          tone = ReferencePlayer(bridge: ToneFixture());
      await t.pumpWidget(
        host(PianoPage(state: state, reference: tone, capture: capture)),
      );
      await capture.start();
      await t.pump(const Duration(milliseconds: 66));
      var gauge = t.widget<TuningGauge>(find.byType(TuningGauge));
      expect(gauge.targetNote, 'A0');
      expect(gauge.reading.note, 'A1');
      expect(gauge.reading.cents, closeTo(1200, 1e-8));
      hz = 27.5 * math.pow(2, -7 / 1200);
      await t.pump(const Duration(milliseconds: 66));
      gauge = t.widget<TuningGauge>(find.byType(TuningGauge));
      expect(gauge.reading.cents, closeTo(-7, 1e-8));
      valid = 1;
      await t.pump(const Duration(milliseconds: 66));
      expect(
        t.widget<TuningGauge>(find.byType(TuningGauge)).reading.isValid,
        isFalse,
      );
      await t.pumpWidget(const SizedBox());
      capture.dispose();
      tone.dispose();
      state.dispose();
      await t.pump();
    },
  );

  pianoWidgets(
    'all 88 actual targets reachable inline; selection is silent; sine reference follows A4',
    (t) async {
      final state = AppState()
        ..selectPage(1)
        ..setReferenceHz(442);
      final tones = ToneFixture();
      final player = ReferencePlayer(bridge: tones);
      await t.pumpWidget(OpenTuneApp(state: state, referencePlayer: player));
      await t.pumpAndSettle();
      for (int octave = 0; octave <= 8; octave++) {
        await press(t, 'piano-octave-$octave');
        for (final key in pianoKeys.where((n) => n.midi ~/ 12 - 1 == octave)) {
          await press(t, 'piano-target-${key.note}');
          expect(state.pianoNote, key.note);
          expect(
            t.widget<TuningGauge>(find.byType(TuningGauge)).targetNote,
            key.note,
          );
        }
      }
      expect(tones.frequencies, isEmpty);
      await press(t, 'reference-toggle');
      expect(
        tones.frequencies.single,
        closeTo(pianoKeys.last.frequency(442), 1e-9),
      );
      expect(tones.timbres.single, ReferenceTimbre.sine);
      await press(t, 'piano-kind-grand');
      expect(player.active, isFalse);
      expect(find.textContaining('not individualized tuning'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      player.dispose();
      state.dispose();
      await t.pump();
    },
  );

  for (final page in [0, 1, 2]) {
    for (final delayed in [false, true]) {
      pianoWidgets(
        'global A4 invalidates page $page ${delayed ? 'pending permission' : 'running snapshot'} and reference',
        (t) async {
          final state = AppState()..selectPage(page);
          var session = 10, seq = 0, stops = 0;
          final calls = <Map>[];
          final pending = Completer<Map<String, Object>>();
          t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            AndroidAudioBridge.channel,
            (call) async {
              if (call.method == 'start') {
                calls.add(Map.of(call.arguments as Map));
                if (delayed && calls.length == 1) return pending.future;
                return {'status': 'running', 'session': ++session};
              }
              if (call.method == 'snapshot') {
                return {
                  'status': 'running',
                  'data': packet(session: session, sequence: ++seq),
                };
              }
              if (call.method == 'stop') stops++;
              return null;
            },
          );
          final tone = ToneFixture();
          final ref = ReferencePlayer(bridge: tone);
          await t.pumpWidget(OpenTuneApp(state: state, referencePlayer: ref));
          await t.pumpAndSettle();
          final toggle = page == 1 ? 'piano-capture-toggle' : 'capture-toggle';
          await press(t, toggle);
          await t.pump(const Duration(milliseconds: 100));
          expect(calls.single['referenceHz'], 440);
          expect(calls.single['mode'], page == 1 ? 'piano' : null);
          state.setReferenceHz(443);
          await t.pumpAndSettle();
          if (delayed) {
            pending.complete({'status': 'running', 'session': 10});
            await t.pump();
          }
          expect(stops, greaterThan(0));
          expect(
            t.widget<TuningGauge>(find.byType(TuningGauge)).reading.isValid,
            isFalse,
          );
          await press(t, toggle);
          await t.pump(const Duration(milliseconds: 66));
          expect(calls.last['referenceHz'], 443);
          if (page != 2) {
            await press(t, 'reference-toggle');
            expect(ref.active, isTrue);
            state.setReferenceHz(444);
            await t.pumpAndSettle();
            expect(ref.active, isFalse);
          }
          await t.pumpWidget(const SizedBox());
          ref.dispose();
          state.dispose();
          await t.pump();
          t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            AndroidAudioBridge.channel,
            null,
          );
        },
      );
    }
  }

  pianoWidgets(
    'profile confirmation is invalidated by selecting another profile or reload',
    (t) async {
      final manager = ProfileManager(MemoryProfiles());
      await manager.load();
      await manager.create('First', PianoKind.digital, 442, 21);
      final first = manager.selected!.id;
      await manager.create('Second', PianoKind.grand, 443, 108);
      final second = manager.selected!.id;
      final state = AppState(profiles: manager)..selectPage(1);
      await t.pumpWidget(OpenTuneApp(state: state));
      await t.pumpAndSettle();
      await press(t, 'piano-profile-list-v1');
      await press(t, 'profile-confirm-update');
      expect(
        t
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('profile-update')),
            )
            .onPressed,
        isNotNull,
      );
      await press(t, 'profile-$first');
      expect(state.referenceHz, 442);
      expect(state.pianoNote, 'A0');
      // A changed target creates a fresh capture subtree, so reopen if collapsed.
      if (find.byKey(ValueKey('profile-$second')).evaluate().isEmpty) {
        await press(t, 'piano-profile-list-v1');
      }
      await press(t, 'profile-$second');
      expect(state.referenceHz, 443);
      expect(state.pianoKind, PianoKind.grand);
      if (find
          .byKey(const ValueKey('profile-confirm-update'))
          .evaluate()
          .isEmpty) {
        await press(t, 'piano-profile-list-v1');
      }
      expect(
        t
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('profile-confirm-update')),
            )
            .value,
        isFalse,
      );
      await press(t, 'profile-confirm-update');
      await press(t, 'profile-reload');
      expect(
        t
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('profile-update')),
            )
            .onPressed,
        isNull,
      );
      await t.pumpWidget(const SizedBox());
      state.dispose();
      await t.pump();
    },
  );

  for (final change in ['key', 'a4', 'page', 'background']) {
    pianoWidgets('piano pending reference stop cannot play after $change', (
      t,
    ) async {
      final waiting = Completer<void>();
      var hold = true;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        (call) async {
          if (call.method == 'stop' && hold) await waiting.future;
          return null;
        },
      );
      final state = AppState()..selectPage(1);
      final tones = ToneFixture();
      final reference = ReferencePlayer(bridge: tones);
      await t.pumpWidget(OpenTuneApp(state: state, referencePlayer: reference));
      await t.pumpAndSettle();
      await press(t, 'reference-toggle');
      expect(tones.frequencies, isEmpty);
      switch (change) {
        case 'key':
          state.selectPianoNote('C8');
        case 'a4':
          state.setReferenceHz(442);
        case 'page':
          state.selectPage(2);
        case 'background':
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      }
      await t.pumpAndSettle();
      hold = false;
      waiting.complete();
      await t.pumpAndSettle();
      expect(tones.frequencies, isEmpty);
      if (change == 'background') {
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
      state.selectPage(1);
      await t.pumpAndSettle();
      await press(t, 'reference-toggle');
      expect(
        tones.frequencies.single,
        pianoKey(state.pianoNote).frequency(state.referenceHz),
      );
      await t.pumpWidget(const SizedBox());
      reference.dispose();
      state.dispose();
      await t.pump();
    });
  }

  pianoWidgets(
    'profile form create persists through manager reload and rejects duplicate name',
    (t) async {
      final store = MemoryProfiles();
      final manager = ProfileManager(store);
      await manager.load();
      final state = AppState(profiles: manager)
        ..selectPage(1)
        ..setReferenceHz(442)
        ..selectPianoNote('C8');
      await t.pumpWidget(OpenTuneApp(state: state));
      await t.pumpAndSettle();
      await press(t, 'piano-profile-list-v1');
      final name = find.byKey(const PageStorageKey<String>('profile-name'));
      await t.ensureVisible(name);
      await t.pumpAndSettle();
      await t.enterText(name, 'My piano');
      await press(t, 'profile-create');
      expect(store.value.profiles.single.name, 'My piano');
      expect(store.value.profiles.single.midi, 108);
      expect(store.value.profiles.single.a4, 442);
      await t.enterText(name, 'my PIANO');
      await press(t, 'profile-create');
      expect(store.value.profiles.length, 1);
      expect(manager.issue, ProfileIssue.invalid);
      await press(t, 'profile-reload');
      expect(manager.selected!.name, 'My piano');
      final tile = find.byKey(
        const PageStorageKey<String>('piano-profile-list-v1'),
      );
      await t.ensureVisible(tile);
      await t.pumpAndSettle();
      await t.tap(tile);
      await t.pumpAndSettle();
      await t.tap(tile);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      await t.pumpWidget(const SizedBox());
      state.dispose();
      await t.pump();
    },
  );

  pianoWidgets(
    'piano output failure remains visible, never starts capture or demo',
    (t) async {
      final state = AppState()..selectPianoNote('C8');
      final bridge = FixtureBridge(),
          tones = ToneFixture()..response = {'status': 'error', 'rate': 8000};
      final capture = AudioCapture(bridge: bridge),
          reference = ReferencePlayer(bridge: tones);
      await t.pumpWidget(
        host(PianoPage(state: state, reference: reference, capture: capture)),
      );
      await press(t, 'reference-toggle');
      expect(
        tones.frequencies.single,
        closeTo(pianoKeys.last.frequency(440), 1e-9),
      );
      expect(reference.state, ReferenceStatus.error);
      expect(
        find.text('Playback unavailable. Check audio output / competing apps.'),
        findsOneWidget,
      );
      expect(bridge.starts, 0);
      expect(capture.current, isNull);
      expect(state.demo, isFalse);
      await t.pumpWidget(const SizedBox());
      capture.dispose();
      reference.dispose();
      state.dispose();
      await t.pump();
    },
  );

  for (final language in ['zh', 'en']) {
    pianoWidgets(
      'piano/settings narrow large text $language no overflow, focus/theme/navigation',
      (t) async {
        t.view.physicalSize = const Size(320, 640);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() {
          t.view.reset();
          t.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final state = AppState()
          ..selectPage(1)
          ..setLocale(Locale(language));
        await t.pumpWidget(OpenTuneApp(state: state));
        await t.pumpAndSettle();
        for (final mode in [ThemeMode.dark, ThemeMode.light]) {
          state.setThemeMode(mode);
          await t.pumpAndSettle();
          await press(t, 'piano-highest');
          state.setMinimal(!state.minimal);
          await t.pumpAndSettle();
          expect(find.byKey(const ValueKey('reference-toggle')), findsNothing);
          state.setMinimal(!state.minimal);
          await t.pumpAndSettle();
          state.selectPage(4);
          await t.pumpAndSettle();
          final input = find.byKey(const ValueKey('reference-a4'));
          await t.ensureVisible(input);
          await t.pumpAndSettle();
          await t.enterText(input, 'NaN');
          await press(t, 'reference-apply');
          expect(state.referenceHz, 440);
          await t.enterText(input, '480');
          await press(t, 'reference-apply');
          expect(state.referenceHz, 480);
          state.setReferenceHz(440);
          state.selectPage(1);
          await t.pumpAndSettle();
          expect(find.byType(ErrorWidget), findsNothing);
        }
        await t.pumpWidget(const SizedBox());
        state.dispose();
        await t.pump();
      },
    );
  }
}
