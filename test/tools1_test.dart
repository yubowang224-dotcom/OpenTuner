import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/audio/audio_capture.dart';
import 'package:opentune_tuner/app.dart';
import 'package:opentune_tuner/audio/guitar_page.dart';
import 'package:opentune_tuner/audio/metronome_page.dart';
import 'package:opentune_tuner/audio/metronome_player.dart';
import 'package:opentune_tuner/audio/reference_player.dart';
import 'package:opentune_tuner/model/app_state.dart';
import 'package:opentune_tuner/model/guitar_tuning.dart';
import 'package:opentune_tuner/l10n/generated/app_localizations.dart';
import 'package:opentune_tuner/widgets/tuning_gauge.dart';

import 'audio_test.dart' show FixtureBridge, packet;
import 'stage25_test.dart' show ToneFixture;

MetroConfig config({
  int bpm = 120,
  int beats = 4,
  int denominator = 4,
  int divisions = 1,
  bool accent = true,
}) => MetroConfig(
  bpm: bpm,
  beats: beats,
  denominator: denominator,
  divisions: divisions,
  accent: accent,
);
List<double> metroPacket({
  int frames = 192,
  int beat = 0,
  int division = 0,
  int beats = 4,
  int denominator = 4,
  int divisions = 1,
  int bpm = 120,
}) => [
  1,
  17,
  1,
  48000,
  frames.toDouble(),
  beat.toDouble(),
  division.toDouble(),
  1,
  bpm.toDouble(),
  beats.toDouble(),
  denominator.toDouble(),
  divisions.toDouble(),
  1,
  0,
  0,
  0,
];

class MetroFixture implements MetroBridge {
  @override
  bool supported = true;
  final starts = <int>[], stops = <int>[];
  final updates = <MetroConfig>[];
  Completer<Map<Object?, Object?>>? pendingStart, pendingPoll, pendingUpdate;
  Map<Object?, Object?> reply = {'status': 'playing', 'data': metroPacket()};
  @override
  Future<Map<Object?, Object?>> start(MetroConfig c, int r) async {
    starts.add(r);
    return pendingStart?.future ?? {'status': 'playing', 'session': 17};
  }

  @override
  Future<Map<Object?, Object?>> setPaused(bool paused, int request) async => {
    'status': 'accepted',
  };
  @override
  Future<void> stop(int r) async {
    stops.add(r);
  }

  @override
  Future<Map<Object?, Object?>> update(MetroConfig c, int r) async {
    updates.add(c);
    return pendingUpdate?.future ?? {'status': 'accepted'};
  }

  @override
  Future<Map<Object?, Object?>> snapshot(int r) async =>
      pendingPoll?.future ?? reply;
}

class DelayedStopBridge extends FixtureBridge {
  Completer<void>? hold;
  @override
  Future<void> stop() async {
    stops++;
    await hold?.future;
  }
}

Widget host(Widget page) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: page)),
);

void main() {
  testWidgets('range-valid first auto frame says confirming, never outside', (
    tester,
  ) async {
    final b = FixtureBridge()
      ..makePacket = (seq, details) => packet(sequence: seq)
        ..[6] = 110
        ..[7] = 110
        ..[8] = 45;
    final c = AudioCapture(bridge: b),
        p = ReferencePlayer(bridge: ToneFixture()),
        state = AppState();
    await tester.pumpWidget(
      host(GuitarPage(state: state, reference: p, capture: c)),
    );
    await tester.tap(find.byKey(const ValueKey('guitar-auto')));
    await tester.pump();
    await c.start();
    await tester.pump(const Duration(milliseconds: 33));
    expect(find.text('Confirming guitar target…'), findsOneWidget);
    expect(
      find.text('Outside the auto range. Select a string manually.'),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 33));
    expect(find.text('Confirming guitar target…'), findsNothing);
    expect(
      tester.widget<TuningGauge>(find.byType(TuningGauge)).reading.cents,
      closeTo(0, 1e-6),
    );
    await tester.pumpWidget(const SizedBox());
    p.dispose();
    c.dispose();
    state.dispose();
  });
  testWidgets(
    'changing guitar target cancels pending reference and stops sounding old target',
    (tester) async {
      final b = DelayedStopBridge(), tones = ToneFixture();
      final c = AudioCapture(bridge: b),
          p = ReferencePlayer(bridge: tones),
          state = AppState();
      await tester.pumpWidget(
        host(GuitarPage(state: state, reference: p, capture: c)),
      );
      Future<void> press(String key) async {
        final f = find.byKey(ValueKey(key));
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pump();
      }

      b.hold = Completer<void>();
      await press('reference-toggle');
      expect(tones.frequencies, isEmpty);
      await press('guitar-target-1');
      b.hold!.complete();
      await tester.pump();
      expect(tones.frequencies, isEmpty); // old E2 request must never start.
      b.hold = null;
      await press('reference-toggle');
      expect(tones.frequencies, [110]);
      expect(p.active, isTrue);
      await press('guitar-target-2');
      expect(p.active, isFalse);
      expect(tones.frequencies, [110]);
      b.hold = Completer<void>();
      await press('reference-toggle');
      await press('guitar-auto');
      b.hold!.complete();
      await tester.pump();
      expect(tones.frequencies, [110]);
      b.hold = null;
      await tester.pumpWidget(const SizedBox());
      p.dispose();
      c.dispose();
      state.dispose();
    },
  );
  testWidgets(
    'app minimal toggle retains guitar mic session; navigation releases it',
    (tester) async {
      var starts = 0, stops = 0, seq = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        (call) async {
          if (call.method == 'start') {
            starts++;
            return {'status': 'running', 'session': 7};
          }
          if (call.method == 'snapshot') {
            return {'status': 'running', 'data': packet(sequence: ++seq)};
          }
          if (call.method == 'stop') stops++;
          return null;
        },
      );
      final state = AppState();
      await tester.pumpWidget(OpenTuneApp(state: state));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('capture-toggle'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 66));
      expect(starts, 1);
      final before = stops;
      state.setMinimal(true);
      await tester.pump(const Duration(milliseconds: 66));
      expect(starts, 1);
      expect(stops, before);
      expect(
        tester.widget<TuningGauge>(find.byType(TuningGauge)).reading.isValid,
        isTrue,
      );
      state.selectPage(3);
      await tester.pump(const Duration(milliseconds: 150));
      expect(stops, greaterThan(before));
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        null,
      );
    },
  );
  test(
    'six targets, current A4, cents and absolute matching never fold octaves',
    () {
      expect(standardGuitar.map((s) => s.note), [
        'E2',
        'A2',
        'D3',
        'G3',
        'B3',
        'E4',
      ]);
      for (var i = 0; i < 6; i++) {
        final f = standardGuitar[i].frequency(442);
        expect(matchGuitar(f, 442).index, i);
        expect(targetCents(f * math.pow(2, 37 / 1200), f), closeTo(37, 1e-8));
      }
      expect(
        targetCents(164.813778, standardGuitar[0].frequency(440)),
        closeTo(1200, .001),
      );
      expect(
        matchGuitar(164.813778, 440).state,
        isNot(GuitarMatchState.matched),
      );
      final midpoint = math.sqrt(
        standardGuitar[0].frequency(440) * standardGuitar[1].frequency(440),
      );
      expect(matchGuitar(midpoint, 440).state, GuitarMatchState.ambiguous);
      expect(matchGuitar(30, 440).state, GuitarMatchState.outside);
      expect(matchGuitar(double.nan, 440).state, GuitarMatchState.invalid);
      expect(() => targetCents(0, 440), throwsArgumentError);
    },
  );
  testWidgets(
    'guitar manual real cents, weak reliable input, auto two fresh frames and invalidity',
    (tester) async {
      var hz = 110.0, valid = 2, now = 0;
      final b = FixtureBridge()
        ..makePacket = (seq, details) => packet(sequence: seq, validity: valid)
          ..[6] = hz
          ..[7] = hz
          ..[8] = (69 + 12 * math.log(hz / 440) / math.ln2).roundToDouble()
          ..[11] = -75;
      final c = AudioCapture(bridge: b, monotonicMs: () => now);
      final t = GuitarTuner(capture: c);
      await c.start();
      await tester.pump(const Duration(milliseconds: 33));
      expect(
        t.cents,
        closeTo(500, 1e-6),
      ); // A2 measured against E2: no nearest-note substitution.
      t.manual(1);
      expect(t.cents, closeTo(0, 1e-6));
      t.setAutomatic(true);
      now = 33;
      await tester.pump(const Duration(milliseconds: 33));
      expect(t.cents, isNull);
      expect(t.selected, isNull);
      now = 66;
      await tester.pump(const Duration(milliseconds: 33));
      expect(t.selected, 1);
      expect(t.cents, closeTo(0, 1e-6));
      hz = standardGuitar[3].frequency(440);
      now = 99;
      await tester.pump(const Duration(milliseconds: 33));
      expect(
        t.cents,
        isNull,
      ); // don't report G3 measured against old A2 as tuned.
      now = 132;
      await tester.pump(const Duration(milliseconds: 33));
      expect(t.selected, 3);
      valid = 1;
      now = 165;
      await tester.pump(const Duration(milliseconds: 33));
      expect(t.cents, isNull);
      await c.stop();
      expect(t.cents, isNull);
      t.dispose();
      c.dispose();
    },
  );
  testWidgets(
    'guitar UI separates selection/play, stops capture for reference, no automatic resume',
    (tester) async {
      final b = FixtureBridge(), tones = ToneFixture();
      final c = AudioCapture(bridge: b),
          p = ReferencePlayer(bridge: tones),
          state = AppState();
      await tester.pumpWidget(
        host(GuitarPage(state: state, reference: p, capture: c)),
      );
      await tester.pumpAndSettle();
      expect(b.starts, 0);
      final select = find.byKey(const ValueKey('guitar-target-1'));
      await tester.ensureVisible(select);
      await tester.tap(select);
      await tester.pump();
      expect(tones.frequencies, isEmpty);
      final start = find.byKey(const ValueKey('capture-toggle'));
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pump(const Duration(milliseconds: 66));
      expect(c.active, isTrue);
      final play = find.byKey(const ValueKey('reference-toggle'));
      await tester.ensureVisible(play);
      await tester.tap(play);
      await tester.pump();
      expect(c.active, isFalse);
      expect(tones.frequencies, [110]);
      await tester.ensureVisible(start);
      await tester.pump();
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      await p.stop();
      await tester.pump(const Duration(milliseconds: 251));
      expect(c.active, isFalse);
      expect(b.starts, 1);
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
      c.dispose();
      state.dispose();
    },
  );
  testWidgets(
    'guitar offscale retains measured Hz and truthful cents; invalid never tuned',
    (tester) async {
      final b = FixtureBridge()
        ..makePacket = (seq, details) => packet(sequence: seq)
          ..[6] = 164.813778
          ..[7] = 164.813778
          ..[8] = 52;
      final c = AudioCapture(bridge: b),
          p = ReferencePlayer(bridge: ToneFixture()),
          state = AppState();
      await tester.pumpWidget(
        host(GuitarPage(state: state, reference: p, capture: c)),
      );
      await c.start();
      await tester.pump(const Duration(milliseconds: 99));
      final gauge = tester.widget<TuningGauge>(find.byType(TuningGauge));
      expect(gauge.reading.cents, closeTo(1200, .001));
      expect(gauge.reading.note, 'E3');
      b.reply = {
        'status': 'running',
        'data': packet(sequence: 100, validity: 1),
      };
      await tester.pump(const Duration(milliseconds: 33));
      expect(
        tester.widget<TuningGauge>(find.byType(TuningGauge)).reading.isValid,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      p.dispose();
      c.dispose();
      state.dispose();
    },
  );
  test(
    'Tap quarter tempo handles duplicates, outlier median and clock resets',
    () {
      final t = TapTempo();
      expect(t.tap(0), isNull);
      expect(t.tap(100), isNull);
      expect(t.tap(500), 120);
      expect(t.tap(1000), 120);
      expect(t.tap(1500), 120);
      expect(t.tap(2500), 120);
      expect(t.tap(6000), isNull);
      expect(t.tap(6500), 120);
      expect(t.tap(6400), isNull);
      expect(t.tap(6600), 300);
      expect(t.tap(9600), 38); // median of 200 and 3000 ->1600ms.
    },
  );
  test(
    'native metronome snapshot is strict about ABI, owner and positions',
    () {
      expect(
        MetroSnapshot.decode(
          metroPacket(beats: 6, denominator: 8, beat: 3),
          17,
        )!.config.denominator,
        8,
      );
      expect(MetroSnapshot.decode(metroPacket(), 18), isNull);
      for (final pair in [
        (0, 2.0),
        (3, 0.0),
        (5, 4.0),
        (6, 1.0),
        (8, 301.0),
        (12, .5),
        (13, 1.0),
        (15, 999.0),
      ]) {
        final p = metroPacket()..[pair.$1] = pair.$2;
        expect(MetroSnapshot.decode(p, 17), isNull);
      }
      expect(() => config(divisions: 0), throwsArgumentError);
    },
  );
  testWidgets(
    'metro start idempotent, stale starts/polls discarded, new request owns stop',
    (tester) async {
      final b = MetroFixture()..pendingStart = Completer();
      final p = MetronomePlayer(bridge: b);
      final starting = p.start(config());
      await p.start(config());
      expect(b.starts.length, 1);
      await p.stop();
      b.pendingStart!.complete({'status': 'playing', 'session': 17});
      await starting;
      expect(p.active, isFalse);
      expect(p.current, isNull);
      b.pendingStart = null;
      await p.start(config());
      expect(b.starts.toSet().length, 2);
      b.pendingPoll = Completer();
      await tester.pump(const Duration(milliseconds: 33));
      await p.stop();
      b.pendingPoll!.complete({'status': 'playing', 'data': metroPacket()});
      await tester.pump();
      expect(p.current, isNull);
      expect(p.active, isFalse);
      expect(b.stops, b.starts);
      p.dispose();
    },
  );
  testWidgets(
    'metro config coalesces while pending, reads native position, stops on stall/background',
    (tester) async {
      var now = 0;
      final b = MetroFixture();
      final p = MetronomePlayer(bridge: b, monotonicMs: () => now);
      await p.start(config());
      b.pendingUpdate = Completer();
      p.configure(config(bpm: 121));
      p.configure(config(bpm: 122));
      p.configure(config(bpm: 123));
      expect(b.updates.map((c) => c.bpm), [121]);
      b.pendingUpdate!.complete({'status': 'accepted'});
      await tester.pump();
      expect(b.updates.map((c) => c.bpm), [121, 123]);
      await tester.pump(const Duration(milliseconds: 33));
      expect(p.current!.frames, 192);
      now = 501;
      await tester.pump(const Duration(milliseconds: 33));
      expect(p.status, 'stalled');
      expect(p.current, isNull);
      await p.start(config());
      p.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(p.active, isTrue);
      p.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(p.status, 'background');
      expect(p.active, isFalse);
      p.dispose();
    },
  );
  testWidgets('metro unsupported/failure never simulates position', (
    tester,
  ) async {
    final b = MetroFixture()..supported = false;
    final p = MetronomePlayer(bridge: b);
    await p.start(config());
    expect(b.starts, isEmpty);
    expect(p.status, 'unsupported');
    p.dispose();
    final fail = MetronomePlayer(
      bridge: MetroFixture()..reply = {'status': 'interrupted'},
    );
    await fail.start(config());
    await tester.pump(const Duration(milliseconds: 33));
    expect(fail.active, isFalse);
    expect(fail.current, isNull);
    fail.dispose();
  });
  testWidgets(
    'metro visible beat comes from native 6/8 position and page disposal stops',
    (tester) async {
      final b = MetroFixture()
        ..reply = {
          'status': 'playing',
          'data': metroPacket(
            beats: 6,
            denominator: 8,
            beat: 3,
            division: 2,
            divisions: 3,
          ),
        };
      final p = MetronomePlayer(bridge: b),
          state = AppState()
            ..setMeter('6/8')
            ..setSubdivision(2);
      await tester.pumpWidget(host(MetronomePage(state: state, player: p)));
      expect(b.starts, isEmpty);
      await tester.tap(find.byKey(const ValueKey('metro-toggle')));
      await tester.pump(const Duration(milliseconds: 66));
      expect(find.text('6/8 · 4 / 6 · 3 / 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('beat-5')), findsOneWidget);
      state.setBpm(137);
      await tester.pump();
      expect(b.updates.last.bpm, 137);
      await tester.pumpWidget(const SizedBox());
      expect(p.active, isFalse);
      expect(b.stops.length, 1);
      p.dispose();
      state.dispose();
    },
  );
  testWidgets(
    'Android metro bridge carries config and request on every operation, no mic request',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidMetroBridge.channel,
        (c) async {
          calls.add(c);
          return c.method == 'metroStop' ? null : <Object?, Object?>{};
        },
      );
      const b = AndroidMetroBridge();
      await b.start(config(beats: 6, denominator: 8), 9);
      await b.update(config(bpm: 137), 9);
      await b.snapshot(9);
      await b.stop(9);
      expect(calls.map((c) => c.method), [
        'metroStart',
        'metroUpdate',
        'metroStatus',
        'metroStop',
      ]);
      expect(calls.every((c) => (c.arguments as Map)['request'] == 9), isTrue);
      expect((calls.first.arguments as Map)['denominator'], 8);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidMetroBridge.channel,
        null,
      );
    },
  );
}
