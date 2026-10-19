import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/audio/audio_capture.dart';
import 'package:opentune_tuner/audio/explore_page.dart';
import 'package:opentune_tuner/l10n/generated/app_localizations.dart';
import 'package:opentune_tuner/model/app_state.dart';
import 'package:opentune_tuner/app.dart';

// Test-only bridge fixtures. The application has no synthesized PCM entry point.
List<double> packet({
  int session = 7,
  int sequence = 1,
  int validity = 2,
  double age = 0,
  bool details = false,
}) {
  final p = List<double>.filled(details ? 290 : 30, 0);
  p[0] = 1;
  p[1] = session.toDouble();
  p[2] = sequence.toDouble();
  p[3] = .1;
  p[4] = age;
  p[5] = validity.toDouble();
  p[6] = 440.1;
  p[7] = 440;
  p[8] = 69;
  p[9] = 0;
  p[10] = .99;
  p[11] = -20;
  p[13] = 1;
  p[14] = 48000;
  p[15] = 1;
  p[16] = 2;
  p[17] = 2;
  p[18] = 192;
  p[19] = 1536;
  p[24] = .08;
  p[25] = 48000 / 4096;
  p[26] = details ? 4 : 0;
  p[28] = 9;
  p[29] = -1;
  if (details) {
    for (var i = 30; i < 286; i++) {
      p[i] = i.isEven ? -.5 : .5;
    }
    p.setAll(286, [-120, -40, -20, -60]);
  }
  return p;
}

class FixtureBridge implements AudioBridge {
  @override
  bool supported = true;
  int starts = 0, stops = 0, polls = 0, settings = 0;
  bool requestedDetails = false;
  Completer<Map<Object?, Object?>>? permission;
  Map<Object?, Object?> startReply = {'status': 'running', 'session': 7};
  Map<Object?, Object?>? reply;
  Completer<Map<Object?, Object?>>? pendingPoll;
  List<double> Function(int, bool)? makePacket;
  @override
  Future<Map<Object?, Object?>> start(double referenceHz) async {
    starts++;
    return permission?.future ?? startReply;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> openSettings() async {
    settings++;
  }

  @override
  Future<Map<Object?, Object?>> snapshot(bool details) async {
    polls++;
    requestedDetails = details;
    if (pendingPoll != null) return pendingPoll!.future;
    return reply ??
        {
          'status': 'running',
          'data':
              makePacket?.call(polls, details) ??
              packet(sequence: polls, details: details),
        };
  }
}

void main() {
  test(
    'wire ABI validates format, bounds, finite numbers and positive pitch',
    () {
      final valid = AudioSnapshot.decode(packet(details: true))!;
      expect(valid.note, 'A4');
      expect(valid.wave.length, 256);
      expect(valid.spectrum.length, 4);
      expect(valid.backend, 'AAudio');
      expect(valid.waveMs, 80);
      expect(valid.binHz, closeTo(11.71875, 1e-9));
      for (final (index, value) in [
        (0, 2.0),
        (6, 0.0),
        (7, -1.0),
        (10, 1.2),
        (14, 0.0),
        (15, 2.0),
        (16, 1.0),
        (8, 69.2),
        (26, 600.0),
        (9, double.nan),
      ]) {
        final bad = packet();
        bad[index] = value;
        expect(AudioSnapshot.decode(bad), isNull, reason: 'field $index');
      }
      expect(AudioSnapshot.decode([1, 2]), isNull);
      expect(AudioSnapshot.decode([...packet(), 0]), isNull);
      final invalid = AudioSnapshot.decode(packet(validity: 1))!;
      expect(invalid.valid, isFalse);
      expect(invalid.note, isNull);
      expect(invalid.trackedHz, isNull);
      expect(AudioSnapshot.decode(packet(age: 251))!.valid, isFalse);
      expect(frequencyCents(440, 440), 0);
      expect(frequencyCents(880, 440), closeTo(1200, 1e-9));
      expect(() => frequencyCents(0, 440), throwsArgumentError);
    },
  );
  testWidgets(
    'start/stop serialized, permission completion after stop ignored',
    (tester) async {
      final bridge = FixtureBridge()..permission = Completer();
      final c = AudioCapture(bridge: bridge);
      expect(bridge.starts, 0);
      final pending = c.start();
      await c.start();
      expect(bridge.starts, 1);
      expect(c.status, CaptureStatus.starting);
      await c.stop();
      bridge.permission!.complete({'status': 'running', 'session': 7});
      await pending;
      await tester.pump(const Duration(seconds: 1));
      expect(c.status, CaptureStatus.idle);
      expect(c.current, isNull);
      expect(bridge.polls, 0);
      c.dispose();
    },
  );
  testWidgets(
    'permission states, retries and settings do not simulate capture',
    (tester) async {
      final bridge = FixtureBridge();
      final c = AudioCapture(bridge: bridge);
      for (final (reply, status) in [
        ('permission_denied', CaptureStatus.permissionDenied),
        ('permission_settings', CaptureStatus.permissionSettings),
        ('permission_revoked', CaptureStatus.permissionRevoked),
        ('silenced', CaptureStatus.silenced),
        ('background', CaptureStatus.background),
        ('error', CaptureStatus.error),
      ]) {
        bridge.startReply = {'status': reply};
        await c.start();
        expect(c.status, status);
        expect(c.current, isNull);
      }
      await c.openSettings();
      expect(bridge.settings, 1);
      bridge.startReply = {'status': 'running', 'session': 7};
      await c.start();
      await tester.pump(const Duration(milliseconds: 33));
      expect(c.current?.note, 'A4');
      c.dispose();
    },
  );
  testWidgets('old session/sequence discarded, detail transport explicit', (
    tester,
  ) async {
    final bridge = FixtureBridge();
    final c = AudioCapture(bridge: bridge);
    await c.start();
    await tester.pump(const Duration(milliseconds: 33));
    expect(c.current?.sequence, 1);
    expect(c.current?.wave, isEmpty);
    expect(bridge.requestedDetails, isFalse);
    bridge.reply = {
      'status': 'running',
      'data': packet(session: 6, sequence: 100),
    };
    await tester.pump(const Duration(milliseconds: 33));
    expect(c.current?.sequence, 1);
    bridge.reply = {'status': 'running', 'data': packet(sequence: 0)};
    await tester.pump(const Duration(milliseconds: 33));
    expect(c.current?.sequence, 1);
    bridge.reply = null;
    c.setDetails(true);
    await tester.pump(const Duration(milliseconds: 33));
    expect(bridge.requestedDetails, isTrue);
    expect(c.current?.wave.length, 256);
    await c.stop();
    expect(c.current, isNull);
    c.dispose();
  });
  testWidgets('stale, malformed and interrupted streams stop and release', (
    tester,
  ) async {
    for (final response in [
      {'status': 'running', 'data': packet(age: 251)},
      {
        'status': 'running',
        'data': [1, 2],
      },
      {'status': 'interrupted'},
      {'status': 'device_changed'},
      {'status': 'permission_revoked'},
      {'status': 'silenced'},
    ]) {
      final bridge = FixtureBridge()..reply = response;
      final c = AudioCapture(bridge: bridge);
      await c.start();
      await tester.pump(const Duration(milliseconds: 33));
      expect(c.active, isFalse);
      expect(c.current, isNull);
      expect(bridge.stops, greaterThanOrEqualTo(1));
      c.dispose();
    }
  });
  testWidgets(
    'unsupported platform never invokes microphone or supplies results',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final c = AudioCapture();
      await c.start();
      expect(c.status, CaptureStatus.unsupported);
      expect(c.current, isNull);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: [ExplorePage(state: AppState(), capture: c)],
            ),
          ),
        ),
      );
      expect(
        find.text('Audio capture is not implemented on this platform'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('capture-toggle')))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets('channel contract: explicit intent, details and stop', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      AndroidAudioBridge.channel,
      (call) async {
        calls.add(call);
        return switch (call.method) {
          'start' => {'status': 'running', 'session': 7},
          'snapshot' => {'status': 'running', 'data': packet()},
          _ => null,
        };
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        null,
      ),
    );
    final c = AudioCapture();
    expect(calls, isEmpty);
    await c.start();
    await tester.pump(const Duration(milliseconds: 33));
    expect(c.current?.trackedHz, 440);
    expect(calls[1].arguments, {'details': false});
    await c.stop();
    expect(calls.last.method, 'stop');
    c.dispose();
  });
  testWidgets(
    'production Explore consumes snapshots, invalidates pitch and stops in background',
    (tester) async {
      final bridge = FixtureBridge();
      final c = AudioCapture(bridge: bridge);
      final state = AppState();
      tester.view.physicalSize = const Size(500, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: [ExplorePage(state: state, capture: c)],
            ),
          ),
        ),
      );
      expect(bridge.starts, 0);
      await tester.tap(find.byKey(const ValueKey('capture-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 33));
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('A4'), findsOneWidget);
      expect(find.text('440.0 Hz'), findsOneWidget);
      await tester.ensureVisible(
        find.text('Live waveform, spectrum & diagnostics'),
      );
      await tester.pump();
      await tester.tap(find.text('Live waveform, spectrum & diagnostics'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 33));
      expect(c.current?.wave, isNotEmpty);
      expect(find.byKey(const ValueKey('live-waveform')), findsOneWidget);
      bridge.reply = {
        'status': 'running',
        'data': packet(sequence: 999, validity: 1, details: true),
      };
      await tester.pump(const Duration(milliseconds: 33));
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('A4'), findsNothing);
      expect(find.text('In tune'), findsNothing);
      expect(c.current?.wave, isNotEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(c.active, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(c.current, isNull);
      expect(c.status, CaptureStatus.background);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      state.dispose();
    },
  );
  testWidgets('many restarts do not accumulate timers or stale data', (
    tester,
  ) async {
    final bridge = FixtureBridge();
    final c = AudioCapture(bridge: bridge);
    for (var i = 0; i < 20; i++) {
      await c.start();
      await tester.pump(const Duration(milliseconds: 33));
      await c.stop();
      expect(c.current, isNull);
    }
    final polls = bridge.polls;
    await tester.pump(const Duration(seconds: 1));
    expect(bridge.polls, polls);
    expect(bridge.starts, 20);
    c.dispose();
  });
  testWidgets(
    'freshness timeout clears old pitch even when only stale sessions arrive',
    (tester) async {
      var now = 0;
      final bridge = FixtureBridge();
      final c = AudioCapture(bridge: bridge, monotonicMs: () => now);
      await c.start();
      await tester.pump(const Duration(milliseconds: 33));
      expect(c.current?.valid, isTrue);
      bridge.reply = {
        'status': 'running',
        'data': packet(session: 6, sequence: 999),
      };
      now = 260;
      await tester.pump(const Duration(milliseconds: 33));
      expect(c.current, isNull);
      expect(c.active, isTrue);
      now = 520;
      await tester.pump(const Duration(milliseconds: 33));
      expect(c.status, CaptureStatus.stalled);
      expect(bridge.stops, 1);
      c.dispose();
    },
  );
  testWidgets(
    'in-flight snapshot cannot restore a stopped or disposed session',
    (tester) async {
      final bridge = FixtureBridge()..pendingPoll = Completer();
      final c = AudioCapture(bridge: bridge);
      await c.start();
      await tester.pump(const Duration(milliseconds: 33));
      await c.stop();
      bridge.pendingPoll!.complete({'status': 'running', 'data': packet()});
      await tester.pump();
      expect(c.current, isNull);
      expect(c.status, CaptureStatus.idle);
      c.dispose();
    },
  );
  testWidgets(
    'transport timeout releases resources instead of holding a valid note',
    (tester) async {
      final bridge = FixtureBridge();
      final c = AudioCapture(bridge: bridge);
      await c.start();
      await tester.pump(const Duration(milliseconds: 33));
      expect(c.current?.valid, isTrue);
      bridge.pendingPoll = Completer();
      await tester.pump(const Duration(milliseconds: 33));
      await tester.pump(const Duration(milliseconds: 251));
      expect(c.current, isNull);
      expect(c.status, CaptureStatus.error);
      expect(bridge.stops, 1);
      bridge.pendingPoll!.complete({
        'status': 'running',
        'data': packet(sequence: 100),
      });
      await tester.pump();
      c.dispose();
    },
  );
  testWidgets(
    'live minimal mode preserves capture and leaving the page stops it',
    (tester) async {
      final calls = <String>[];
      var sequence = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        (call) async {
          calls.add(call.method);
          return switch (call.method) {
            'start' => {'status': 'running', 'session': 7},
            'snapshot' => {
              'status': 'running',
              'data': packet(sequence: ++sequence),
            },
            _ => null,
          };
        },
      );
      final state = AppState()..selectPage(2);
      await tester.pumpWidget(OpenTuneApp(state: state));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('capture-toggle')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('capture-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 33));
      expect(find.text('A4'), findsOneWidget);
      state.setMinimal(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 33));
      expect(find.text('A4'), findsOneWidget);
      expect(find.text('Digital level'), findsNothing);
      expect(calls.where((c) => c == 'start').length, 1);
      expect(calls.contains('stop'), isFalse);
      state.selectPage(0);
      await tester.pumpAndSettle();
      expect(calls.contains('stop'), isTrue);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        null,
      );
    },
  );
  testWidgets(
    'live sharp notes and expanded plots fit narrow and large-text layouts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final bridge = FixtureBridge()
        ..makePacket = (seq, details) => packet(sequence: seq, details: details)
          ..[6] = 466.163762
          ..[7] = 466.163762
          ..[8] = 70;
      final c = AudioCapture(bridge: bridge, monotonicMs: () => 0);
      final state = AppState();
      await c.start();
      for (final locale in ['en', 'zh']) {
        for (final size in [const Size(320, 640), const Size(844, 390)]) {
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ListView(
                  children: [ExplorePage(state: state, capture: c)],
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 33));
          await tester.pump(const Duration(milliseconds: 40));
          expect(find.text('A♯4'), findsOneWidget);
          expect(tester.takeException(), isNull);
          final title = find.text(
            locale == 'en'
                ? 'Live waveform, spectrum & diagnostics'
                : '实时波形、频谱与诊断',
          );
          await tester.ensureVisible(title);
          await tester.pump(const Duration(milliseconds: 250));
          if (!c.details) {
            await tester.tap(title);
            await tester.pump(const Duration(milliseconds: 250));
          }
          await tester.pump(const Duration(milliseconds: 33));
          await tester.ensureVisible(
            find.byKey(const ValueKey('live-spectrum')),
          );
          await tester.pump(const Duration(milliseconds: 40));
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      state.dispose();
    },
  );
}
