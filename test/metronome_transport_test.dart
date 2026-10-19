import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/app.dart';
import 'package:opentune_tuner/audio/metronome_player.dart';
import 'package:opentune_tuner/audio/metronome_page.dart';
import 'package:opentune_tuner/model/app_state.dart';

import 'tools1_test.dart' show MetroFixture, config, host;

List<double> nativePausePacket() => (jsonDecode(
  File('test/fixtures/metronome-transport.json').readAsStringSync(),
) as List).cast<num>().map((v) => v.toDouble()).toList();

class TransportBridge extends MetroFixture {
  bool paused = false, heartbeat = true;
  int output = 50000, music = 341;
  Completer<Map<Object?, Object?>>? pendingTransport;
  final commands = <bool>[];
  @override
  Future<Map<Object?, Object?>> setPaused(bool value, int request) async {
    commands.add(value);
    if (pendingTransport != null) return pendingTransport!.future;
    paused = value;
    return {'status': 'accepted'};
  }

  @override
  Future<Map<Object?, Object?>> snapshot(int request) async {
    if (heartbeat) output += 192;
    if (!paused) music += 192;
    final p = nativePausePacket()
      ..[4] = music.toDouble()
      ..[17] = paused ? 2 : 0
      ..[18] = output.toDouble();
    return {'status': 'playing', 'data': p};
  }
}

void main() {
  test('same production C++ ABI3 pause snapshot parsed in Dart; malformed metadata rejected', () {
    final p = nativePausePacket(),
        s = MetroSnapshot.decode(nativePausePacket(), 17)!;
    expect(s.transport, 2);
    expect(s.frames, 341);
    expect(s.outputFrames, 48580);
    for (final (index, value) in [
      (17, 4.0),
      (17, -1.0),
      (18, 340.0),
      (4, -1.0),
      (7, -1.0),
      (0, 2.0),
      (18, 1e17),
    ]) {
      final bad = List<double>.from(p)..[index] = value;
      expect(MetroSnapshot.decode(bad, 17), isNull);
    }
  });
  testWidgets(
    'pause retains position with live heartbeat, resume does not create session, stop clears then restart',
    (t) async {
      var now = 0;
      final b = TransportBridge();
      final player = MetronomePlayer(bridge: b, monotonicMs: () => now);
      await player.start(config());
      await t.pump(const Duration(milliseconds: 33));
      await player.pause();
      await player.pause();
      await t.pump(const Duration(milliseconds: 33));
      expect(player.status, 'paused');
      expect(player.active, isTrue);
      final held = player.current!;
      now = 2000;
      await t.pump(const Duration(milliseconds: 33));
      expect(player.status, 'paused');
      expect(player.current!.frames, held.frames);
      expect(player.current!.outputFrames, greaterThan(held.outputFrames));
      player.configure(config(bpm: 137));
      await t.pump();
      expect(b.updates.last.bpm, 137);
      await player.resume();
      await t.pump(const Duration(milliseconds: 33));
      expect(player.status, 'playing');
      expect(player.current!.frames, greaterThan(held.frames));
      expect(b.starts.length, 1);
      expect(b.commands, [true, false]);
      await player.stop();
      expect(player.current, isNull);
      expect(player.status, 'idle');
      expect(b.stops.length, 1);
      await player.start(config());
      expect(b.starts.length, 2);
      expect(player.current, isNull);
      player.dispose();
      await t.pump();
    },
  );
  testWidgets(
    'paused transport still detects callback stall and never silently resumes',
    (t) async {
      var now = 0;
      final b = TransportBridge();
      final player = MetronomePlayer(bridge: b, monotonicMs: () => now);
      await player.start(config());
      await player.pause();
      await t.pump(const Duration(milliseconds: 33));
      b.heartbeat = false;
      now = 501;
      await t.pump(const Duration(milliseconds: 33));
      expect(player.status, 'stalled');
      expect(player.current, isNull);
      expect(b.stops.length, 1);
      player.dispose();
      await t.pump();
    },
  );
  testWidgets(
    'stop/background discard late pause and resume replies, no old result revives output',
    (t) async {
      final b = TransportBridge();
      final player = MetronomePlayer(bridge: b);
      await player.start(config());
      b.pendingTransport = Completer();
      final pending = player.pause();
      player.didChangeAppLifecycleState(AppLifecycleState.paused);
      await t.pump();
      b.pendingTransport!.complete({'status': 'accepted'});
      await pending;
      expect(player.active, isFalse);
      expect(player.current, isNull);
      expect(player.status, 'background');
      b.pendingTransport = null;
      await player.start(config());
      await player.pause();
      await t.pump(const Duration(milliseconds: 33));
      expect(player.status, 'paused');
      b.pendingTransport = Completer();
      final resume = player.resume();
      await player.stop();
      b.pendingTransport!.complete({'status': 'accepted'});
      await resume;
      expect(player.active, isFalse);
      expect(player.current, isNull);
      expect(b.stops.length, 2);
      player.dispose();
      await t.pump();
    },
  );
  testWidgets(
    'pause rejection and accepted request without native transition fail visibly',
    (t) async {
      var now = 0;
      final b = TransportBridge();
      final player = MetronomePlayer(bridge: b, monotonicMs: () => now);
      await player.start(config());
      b.pendingTransport = Completer();
      final pending = player.pause();
      b.pendingTransport!.complete({'status': 'replaced'});
      await pending;
      expect(player.status, 'interrupted');
      b.pendingTransport = Completer();
      await player.start(config());
      final second = player.pause();
      b.pendingTransport!.complete({'status': 'accepted'});
      await second;
      now = 1001;
      await t.pump(const Duration(milliseconds: 33));
      expect(player.status, 'stalled');
      expect(player.active, isFalse);
      player.dispose();
      await t.pump();
    },
  );
  testWidgets(
    'actual controls distinguish start/pause/resume/stop; route disposal releases paused output',
    (t) async {
      final b = TransportBridge(),
          p = MetronomePlayer(bridge: b),
          state = AppState();
      await t.pumpWidget(host(MetronomePage(state: state, player: p)));
      await t.pumpAndSettle();
      Future<void> press(String key) async {
        final f = find.byKey(ValueKey(key));
        await t.ensureVisible(f);
        await t.pumpAndSettle();
        await t.tap(f);
        await t.pump(const Duration(milliseconds: 66));
      }

      await press('metro-toggle');
      expect(find.text('Pause metronome'), findsOneWidget);
      await press('metro-toggle');
      expect(find.text('Resume metronome'), findsOneWidget);
      expect(find.text('Paused · position retained'), findsOneWidget);
      expect(find.text('Stop metronome'), findsOneWidget);
      await press('metro-toggle');
      expect(b.starts.length, 1);
      await press('metro-stop');
      expect(p.current, isNull);
      expect(find.text('Start metronome'), findsOneWidget);
      await press('metro-toggle');
      await press('metro-toggle');
      await t.pumpWidget(const SizedBox());
      await t.pump();
      expect(p.active, isFalse);
      expect(b.stops.length, 2);
      p.dispose();
      state.dispose();
    },
  );
  testWidgets(
    'Android pause bridge passes bool owner, actual App stops paused owner before reference/capture on navigation',
    (t) async {
      final calls = <MethodCall>[];
      bool paused = false;
      int session = 100, output = 0, music = 0;
      int request = 0;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidMetroBridge.channel,
        (c) async {
          calls.add(c);
          final args = c.arguments as Map? ?? {};
          if (c.method == 'metroStart') {
            request = args['request'];
            paused = false;
            output = 0;
            music = 0;
            return {'status': 'playing', 'session': ++session};
          }
          if (c.method == 'metroPause') {
            if (args['request'] != request) return {'status': 'replaced'};
            paused = args['paused'] as bool;
            return {'status': 'accepted'};
          }
          if (c.method == 'metroStatus') {
            output += 192;
            if (!paused) music += 192;
            return {
              'status': 'playing',
              'data': nativePausePacket()
                ..[1] = session.toDouble()
                ..[4] = music.toDouble()
                ..[17] = paused ? 2 : 0
                ..[18] = output.toDouble(),
            };
          }
          if (c.method == 'start') return {'status': 'permission_denied'};
          if (c.method == 'toneStart') {
            return {'status': 'playing', 'rate': 48000};
          }
          return null;
        },
      );
      final state = AppState()..selectPage(3);
      await t.pumpWidget(OpenTuneApp(state: state));
      await t.pumpAndSettle();
      Future<void> press(String key) async {
        final f = find.byKey(ValueKey(key));
        await t.ensureVisible(f);
        await t.pumpAndSettle();
        await t.tap(f);
        await t.pump(const Duration(milliseconds: 66));
      }

      await press('metro-toggle');
      await press('metro-toggle');
      expect(paused, isTrue);
      expect(calls.lastWhere((c) => c.method == 'metroPause').arguments, {
        'request': request,
        'paused': true,
      });
      state.selectPage(1);
      await t.pumpAndSettle();
      await press('reference-toggle');
      expect(
        calls.indexWhere((c) => c.method == 'metroStop'),
        lessThan(calls.indexWhere((c) => c.method == 'toneStart')),
      );
      state.selectPage(3);
      await t.pumpAndSettle();
      await press('metro-toggle');
      await press('metro-toggle');
      state.selectPage(2);
      await t.pumpAndSettle();
      await press('capture-toggle');
      expect(
        calls.lastIndexWhere((c) => c.method == 'metroStop'),
        lessThan(calls.lastIndexWhere((c) => c.method == 'start')),
      );
      await t.pumpWidget(const SizedBox());
      state.dispose();
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidMetroBridge.channel,
        null,
      );
      await t.pump();
    },
  );
}
