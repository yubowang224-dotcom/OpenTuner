import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/app.dart';
import 'package:opentune_tuner/audio/audio_capture.dart';
import 'package:opentune_tuner/audio/reference_player.dart';
import 'package:opentune_tuner/model/app_state.dart';

import 'audio_test.dart' show FixtureBridge, packet;

class ToneFixture implements ReferenceBridge {
  @override
  bool supported = true;
  int stops = 0;
  final frequencies = <double>[];
  final timbres = <ReferenceTimbre>[];
  final gains = <double>[];
  Completer<Map<Object?, Object?>>? pending;
  Map<Object?, Object?> response = {'status': 'playing', 'rate': 48000};
  @override
  Future<Map<Object?, Object?>> start(
    double hz, {
    ReferenceTimbre timbre = ReferenceTimbre.sine,
    double gain = 1,
  }) async {
    frequencies.add(hz);
    timbres.add(timbre);
    gains.add(gain);
    return pending?.future ?? response;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<Map<Object?, Object?>> status() async => response;
}

List<double> version2({bool details = false}) {
  final old = packet(details: details);
  final p = [...old.take(30), ...List<double>.filled(12, 0), ...old.skip(30)];
  p[0] = 2;
  p[30] = -65;
  p[31] = 1;
  p[32] = 45;
  p[33] = 442;
  p[34] = .98;
  p[35] = .01;
  p[36] = 2;
  p[39] = 2;
  p[40] = 1;
  p[41] = .99;
  return p;
}

void main() {
  test(
    'ABI2 preserves units and visual offsets; rejects malformed diagnostics',
    () {
      final p = version2(details: true);
      final r = AudioSnapshot.decode(p)!;
      expect(r.wave.length, 256);
      expect(r.spectrum, [-120, -40, -20, -60]);
      expect(r.noiseFloorDb, -65);
      expect(r.candidateCount, 2);
      expect(r.trackerState, 'tracking');
      expect(AudioSnapshot.decode(p.sublist(0, 41)), isNull);
      expect(AudioSnapshot.decode([...p]..[39] = 2.5), isNull);
      expect(AudioSnapshot.decode([...p]..[34] = 1.1), isNull);
      expect(AudioSnapshot.decode(packet()), isNotNull);
    },
  );
  test(
    'reference mapping follows current A4 and rejects malformed targets',
    () {
      expect(noteFrequency('A4', 442), 442);
      expect(noteFrequency('E2', 440), closeTo(82.406889, .000001));
      expect(noteFrequency('C5', 440), closeTo(523.251131, .000001));
      expect(
        noteFrequency('A♯4', 440),
        closeTo(noteFrequency('Bb4', 440), 1e-10),
      );
      expect(() => noteFrequency('?', 440), throwsArgumentError);
    },
  );
  testWidgets(
    'display rate and note boundary hysteresis do not alter snapshots',
    (tester) async {
      var now = 0;
      var cents = 49.0;
      final b = FixtureBridge()
        ..makePacket = (seq, details) {
          final hz = (440 * math.pow(2, cents / 1200)).toDouble();
          return packet(sequence: seq)
            ..[6] = hz
            ..[7] = hz
            ..[8] = (69 + cents / 100).roundToDouble()
            ..[9] = cents - 100 * ((69 + cents / 100).round() - 69);
        };
      final c = AudioCapture(bridge: b, monotonicMs: () => now);
      await c.start();
      await tester.pump(const Duration(milliseconds: 33));
      expect(c.displayNote, 'A4');
      final first = c.displayHz;
      cents = 52;
      now = 40;
      await tester.pump(const Duration(milliseconds: 33));
      expect(c.current!.note, 'A♯4');
      expect(c.displayNote, 'A4');
      expect(c.displayCents, closeTo(52, 1e-6));
      expect(c.displayHz, first);
      expect(c.current!.trackedHz, isNot(first));
      cents = 56;
      now = 80;
      await tester.pump(const Duration(milliseconds: 33));
      // New UX requires sustained boundary evidence; the measurement is fresh
      // immediately while only its display reference waits for confirmation.
      expect(c.current!.note, 'A♯4');
      expect(c.displayNote, 'A4');
      now = 146;
      await tester.pump(const Duration(milliseconds: 66));
      expect(c.displayNote, 'A♯4');
      expect(c.displayCents, closeTo(-44, 1e-6));
      b.reply = {
        'status': 'running',
        'data': packet(sequence: 100, validity: 1),
      };
      now = 166;
      await tester.pump(const Duration(milliseconds: 33));
      expect(c.displayHz, isNull);
      expect(c.displayNote, isNull);
      expect(c.visualCents, isNotNull);
      now = 400;
      await tester.pump(const Duration(milliseconds: 33));
      expect(c.visualCents, isNull);
      c.dispose();
    },
  );
  testWidgets('reference stale start cannot restore stopped playback', (
    tester,
  ) async {
    final b = ToneFixture()..pending = Completer();
    final p = ReferencePlayer(bridge: b);
    final start = p.play('A4', 440);
    expect(p.active, isTrue);
    await p.stop();
    b.pending!.complete({'status': 'playing', 'rate': 48000});
    await start;
    expect(p.active, isFalse);
    expect(b.stops, 1);
    p.dispose();
  });
  testWidgets('reference repeated click, auto-finish and background release', (
    tester,
  ) async {
    final b = ToneFixture();
    final p = ReferencePlayer(bridge: b);
    await p.play('A4', 440);
    await p.play('A4', 440);
    expect(b.frequencies, [440, 440]);
    b.response = {'status': 'idle'};
    await tester.pump(const Duration(milliseconds: 100));
    expect(p.active, isFalse);
    b.response = {'status': 'playing', 'rate': 44100};
    await p.play('C5', 523.25113);
    expect(p.sampleRate, 44100);
    p.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(p.active, isFalse);
    expect(b.stops, 2);
    p.dispose();
  });
  testWidgets(
    'unsupported and failed references never fall back to demonstration',
    (tester) async {
      final b = ToneFixture()..supported = false;
      final p = ReferencePlayer(bridge: b);
      await p.play('A4', 440);
      expect(p.state, ReferenceStatus.unsupported);
      expect(b.frequencies, isEmpty);
      p.dispose();
      final failed = ReferencePlayer(
        bridge: ToneFixture()..response = {'status': 'error'},
      );
      await failed.play('A4', 440);
      expect(failed.state, ReferenceStatus.error);
      failed.dispose();
    },
  );
  testWidgets(
    'guitar selects silently then explicitly plays; piano key plays; navigation releases',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        (call) async => call.method == 'stop' ? null : {'status': 'idle'},
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          AndroidAudioBridge.channel,
          null,
        ),
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final b = ToneFixture();
      final p = ReferencePlayer(bridge: b);
      final state = AppState();
      await tester.pumpWidget(OpenTuneApp(state: state, referencePlayer: p));
      await tester.pumpAndSettle();
      final target = find.byKey(const ValueKey('guitar-target-0'));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pump();
      expect(b.frequencies, isEmpty);
      final play = find.byKey(const ValueKey('reference-toggle'));
      await tester.ensureVisible(play);
      await tester.pumpAndSettle();
      await tester.tap(play);
      await tester.pump();
      expect(b.frequencies.single, closeTo(82.406889, .000001));
      expect(state.demo, isFalse);
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pump();
      expect(
        b.frequencies.length,
        1,
      ); // selecting never starts or restarts sound.
      state.selectPage(1);
      await tester.pumpAndSettle();
      expect(p.active, isFalse);
      final key = find.byKey(const ValueKey('piano-target-A4'));
      await tester.ensureVisible(key);
      await tester.pumpAndSettle();
      await tester.tap(key);
      await tester.pump();
      expect(
        b.frequencies.length,
        1,
      ); // selecting a real measurement target is silent.
      await tester.ensureVisible(
        find.byKey(const ValueKey('reference-toggle')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reference-toggle')));
      await tester.pump();
      expect(b.frequencies.last, 440);
      state.setMinimal(true);
      state.setLocale(const Locale('zh'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reference-toggle')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
      state.dispose();
    },
  );
  testWidgets(
    'Android reference bridge sends frequency, no microphone permission method',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidReferenceBridge.channel,
        (call) async {
          calls.add(call);
          return call.method == 'toneStart'
              ? {'status': 'playing', 'rate': 48000}
              : call.method == 'toneStatus'
              ? {'status': 'idle'}
              : null;
        },
      );
      const b = AndroidReferenceBridge();
      await b.start(442);
      await b.status();
      await b.stop();
      expect(calls.map((c) => c.method), [
        'toneStart',
        'toneStatus',
        'toneStop',
      ]);
      expect(calls.first.arguments, {'hz': 442, 'voice': 0, 'gain': 1.0});
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidReferenceBridge.channel,
        null,
      );
    },
  );
}
