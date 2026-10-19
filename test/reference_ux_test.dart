import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/audio/audio_capture.dart';
import 'package:opentune_tuner/audio/explore_page.dart';
import 'package:opentune_tuner/l10n/generated/app_localizations.dart';
import 'package:opentune_tuner/model/app_state.dart';
import 'package:opentune_tuner/model/gauge_reading.dart';
import 'package:opentune_tuner/widgets/tuning_gauge.dart';

import 'audio_test.dart' show FixtureBridge, packet;

class ReferenceScenario {
  int now = 0, validity = 2;
  double cents = 0;
  late final bridge = FixtureBridge()
    ..makePacket = (seq, details) {
      final hz = (440 * math.pow(2, cents / 1200)).toDouble();
      final midi = (69 + cents / 100).round();
      return packet(sequence: seq, validity: validity, details: details)
        ..[3] = now / 1000
        ..[6] = hz
        ..[7] = hz
        ..[8] = midi.toDouble()
        ..[9] = cents - 100 * (midi - 69);
    };
  late final capture = AudioCapture(bridge: bridge, monotonicMs: () => now);
  Future<void> sample(
    WidgetTester tester,
    double value, {
    int dt = 33,
    int valid = 2,
  }) async {
    now += dt;
    cents = value;
    validity = valid;
    await tester.pump(const Duration(milliseconds: 33));
  }

  void dispose() => capture.dispose();
}

DialPainter needle(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(find.byKey(const ValueKey('gauge-dial')))
            .painter!
        as DialPainter;
String note(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('gauge-note'))).data!;
Future<void> gauge(
  WidgetTester tester,
  String ref,
  double cents, {
  bool valid = true,
  bool reduce = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: SizedBox(
            width: 360,
            child: TuningGauge(
              key: const ValueKey('ux-gauge'),
              live: true,
              referenceId: ref,
              referenceCaption: 'Automatic reference',
              targetNote: ref,
              reading: valid
                  ? GaugeReading.tracked(note: ref, cents: cents)
                  : const GaugeReading.uncertain(),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'short boundary oscillations do not change reference; sustained crossing confirms within 66ms',
    (tester) async {
      final s = ReferenceScenario();
      await s.capture.start();
      await s.sample(tester, 49);
      expect(s.capture.referenceNote, 'A4');
      for (int i = 0; i < 40; i++) {
        await s.sample(tester, i.isEven ? 56 : 44);
        expect(s.capture.referenceNote, 'A4');
        expect(
          s.capture.current!.trackedHz,
          closeTo(440 * math.pow(2, s.cents / 1200), 1e-8),
        );
      }
      await s.sample(tester, 56);
      final start = s.now;
      expect(s.capture.referenceNote, 'A4');
      await s.sample(tester, 56);
      expect(s.capture.referenceNote, 'A4');
      await s.sample(tester, 56);
      expect(s.now - start, 66);
      expect(s.capture.referenceNote, 'A♯4');
      expect(s.capture.displayCents, closeTo(-44, 1e-6));
      for (int i = 0; i < 20; i++) {
        await s.sample(tester, i.isEven ? 44 : 56);
        expect(s.capture.referenceNote, 'A♯4');
      }
      await s.sample(tester, 200);
      expect(s.capture.referenceNote, 'B4');
      expect(s.capture.displayCents, closeTo(0, 1e-6));
      s.dispose();
    },
  );
  testWidgets('rejected frames reset pending reference confirmation', (
    tester,
  ) async {
    final s = ReferenceScenario();
    await s.capture.start();
    await s.sample(tester, 49);
    await s.sample(tester, 56);
    await s.sample(tester, 56, valid: 1);
    expect(s.capture.displayNote, isNull);
    await s.sample(tester, 56);
    expect(s.capture.referenceNote, 'A4');
    await s.sample(tester, 56);
    expect(s.capture.referenceNote, 'A4');
    await s.sample(tester, 56);
    expect(s.capture.referenceNote, 'A♯4');
    s.dispose();
  });
  testWidgets(
    'lock fixes only reference; true large pitch and invalidation still pass through',
    (tester) async {
      final s = ReferenceScenario();
      expect(s.capture.lockReference(), isFalse);
      await s.capture.start();
      await s.sample(tester, 0);
      expect(s.capture.lockReference(), isTrue);
      expect(s.capture.lockReference(), isFalse);
      await s.sample(tester, 1200);
      expect(s.capture.referenceNote, 'A4');
      expect(s.capture.current!.note, 'A5');
      expect(s.capture.current!.trackedHz, closeTo(880, 1e-9));
      expect(s.capture.displayCents, closeTo(1200, 1e-6));
      await s.sample(tester, -1200);
      expect(s.capture.referenceNote, 'A4');
      expect(s.capture.current!.note, 'A3');
      expect(s.capture.displayCents, closeTo(-1200, 1e-6));
      await s.sample(tester, 0, valid: 0);
      expect(s.capture.referenceLocked, isTrue);
      expect(s.capture.referenceNote, 'A4');
      expect(s.capture.displayNote, isNull);
      expect(s.capture.displayCents, isNull);
      expect(s.capture.displayHz, isNull);
      await s.sample(tester, 1200);
      expect(s.capture.referenceLocked, isTrue);
      expect(s.capture.displayCents, closeTo(1200, 1e-6));
      final measured = s.capture.current!.values;
      s.capture.unlockReference();
      s.capture.unlockReference();
      expect(s.capture.referenceLocked, isFalse);
      expect(s.capture.referenceNote, 'A5');
      expect(s.capture.current!.values, same(measured));
      expect(s.capture.displayCents, closeTo(0, 1e-6));
      s.dispose();
    },
  );
  testWidgets('stop, background and fresh start clear session-only lock', (
    tester,
  ) async {
    final s = ReferenceScenario();
    await s.capture.start();
    await s.sample(tester, 0);
    s.capture.lockReference();
    await s.capture.stop(CaptureStatus.background);
    expect(s.capture.referenceLocked, isFalse);
    expect(s.capture.referenceNote, isNull);
    await s.capture.start();
    await s.sample(tester, 1200);
    expect(s.capture.referenceNote, 'A5');
    expect(s.capture.referenceLocked, isFalse);
    s.capture.lockReference();
    await s.capture.stop();
    await s.capture.stop();
    expect(s.capture.lockReference(), isFalse);
    expect(s.capture.referenceNote, isNull);
    s.dispose();
  });
  testWidgets(
    'reference change fades out, changes coordinate invisibly and fades in without sweeping zero',
    (tester) async {
      await gauge(tester, 'A4', 49);
      await tester.pump();
      await gauge(tester, 'A♯4', -49);
      await tester.pump();
      expect(note(tester), 'A4');
      expect(find.text('Changing reference…'), findsOneWidget);
      final trace = <String>['time_ms,reference,needle_cents,needle_opacity'];
      int? pivotMs;
      for (int ms = 10; ms <= 170; ms += 10) {
        await tester.pump(const Duration(milliseconds: 10));
        final p = needle(tester);
        trace.add('$ms,${note(tester)},${p.cents},${p.needleOpacity}');
        if (p.needleOpacity > 1e-5) {
          expect(p.cents.abs(), greaterThanOrEqualTo(48));
        }
        if (ms < 60) {
          expect(note(tester), 'A4');
          expect(p.cents, 49);
        }
        if (ms == 60) expect(p.needleOpacity, closeTo(0, 1e-6));
        if (note(tester) == 'A♯4' && pivotMs == null) {
          pivotMs = ms;
          expect(p.needleOpacity, closeTo(0, 1e-6));
          expect(p.cents, -49);
        }
        if (note(tester) == 'A4') {
          expect(p.cents, 49);
        } else {
          expect(p.cents, -49);
        }
        expect(find.text('In tune'), findsNothing);
      }
      // Animation completion is dispatched on the first rendering tick after
      // the 60ms endpoint; at this test's 10ms sampling it is at most 70ms.
      expect(pivotMs, inInclusiveRange(60, 70));
      expect(needle(tester).needleOpacity, 1);
      expect(find.text('Changing reference…'), findsNothing);
      expect(note(tester), 'A♯4');
      final dir = Directory('artifacts/stage25-ux1')
        ..createSync(recursive: true);
      File('${dir.path}/reference-fade-trace.csv')
          .writeAsStringSync('${trace.join('\n')}\n');
    },
  );
  testWidgets(
    'same-reference data keeps 32ms motion with full needle opacity',
    (tester) async {
      await gauge(tester, 'A4', -40);
      await gauge(tester, 'A4', 40);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(needle(tester).cents, inExclusiveRange(-40, 40));
      expect(needle(tester).needleOpacity, 1);
      await tester.pump(const Duration(milliseconds: 16));
      expect(needle(tester).cents, 40);
    },
  );
  testWidgets(
    'new snapshots update pending destination without restarting long reference animations',
    (tester) async {
      await gauge(tester, 'A4', 49);
      await gauge(tester, 'A♯4', -49);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      await gauge(tester, 'B4', -20);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump(const Duration(milliseconds: 1));
      expect(note(tester), 'B4');
      expect(needle(tester).needleOpacity, closeTo(0, 1e-6));
      for (int i = 0; i < 4; i++) {
        await gauge(tester, 'B4', -20 + i.toDouble());
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump(const Duration(milliseconds: 1));
      expect(needle(tester).needleOpacity, 1);
      expect(find.text('Changing reference…'), findsNothing);
    },
  );
  testWidgets(
    'invalid input cancels a transition; reduced motion changes reference directly',
    (tester) async {
      await gauge(tester, 'A4', 49);
      await gauge(tester, 'A♯4', -49);
      await tester.pump(const Duration(milliseconds: 20));
      await gauge(tester, 'A♯4', 0, valid: false);
      expect(note(tester), '—');
      expect(needle(tester).active, isFalse);
      expect(find.text('In tune'), findsNothing);
      expect(find.text('— cents'), findsOneWidget);
      await gauge(tester, 'B4', -49, reduce: true);
      expect(note(tester), 'B4');
      expect(needle(tester).cents, -49);
      expect(needle(tester).needleOpacity, 1);
    },
  );
  testWidgets(
    'off-scale readings retain actual cents and direction; invalid center never looks tuned',
    (tester) async {
      await gauge(tester, 'A4', 1200);
      expect(needle(tester).cents, 50);
      expect(find.text('+1200.0 cents'), findsOneWidget);
      expect(find.text('Sharp · outside dial range →'), findsOneWidget);
      await gauge(tester, 'A4', -1200, reduce: true);
      expect(needle(tester).cents, -50);
      expect(find.text('-1200.0 cents'), findsOneWidget);
      expect(find.text('← Flat · outside dial range'), findsOneWidget);
      await gauge(tester, 'A4', 0, valid: false, reduce: true);
      expect(needle(tester).active, isFalse);
      expect(find.text('In tune'), findsNothing);
    },
  );
  testWidgets(
    'reference lock control, lifecycle and bilingual large-text layouts remain usable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final lang in ['en', 'zh']) {
        for (final size in [const Size(320, 640), const Size(844, 390)]) {
          tester.view.physicalSize = size;
          final s = ReferenceScenario();
          final state = AppState();
          await s.capture.start();
          await s.sample(tester, 0);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(lang),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: ListView(
                    children: [ExplorePage(state: state, capture: s.capture)],
                  ),
                ),
              ),
            ),
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('reference-lock')),
          );
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('reference-lock')));
          await tester.pump();
          expect(s.capture.referenceLocked, isTrue);
          await s.sample(tester, 1200);
          await tester.pump(const Duration(milliseconds: 40));
          expect(s.capture.displayCents, closeTo(1200, 1e-6));
          expect(tester.takeException(), isNull);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
          expect(s.capture.referenceLocked, isFalse);
          expect(s.capture.current, isNull);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpWidget(const SizedBox());
          s.dispose();
          state.dispose();
        }
      }
    },
  );
}
