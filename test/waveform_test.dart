import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/audio/audio_capture.dart';
import 'package:opentune_tuner/audio/explore_page.dart';
import 'package:opentune_tuner/l10n/generated/app_localizations.dart';
import 'package:opentune_tuner/model/app_state.dart';
import 'package:opentune_tuner/theme.dart';

import 'stage25_test.dart' show version2;
import 'audio_test.dart' show FixtureBridge;

// Test-only producer; production has no file/synthesized PCM input endpoint.
List<double> wavePacket({String name = 'sine440', bool details = true}) {
  final f = jsonDecode(
    File('test/fixtures/waveform/$name.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final samples = (f['samples'] as List)
      .cast<num>()
      .map((v) => v.toDouble())
      .toList();
  final p = [...version2(), ...List<double>.filled(6, 0)];
  p[0] = 3;
  p[3] = .08;
  if (!details) {
    p[24] = 0;
    p[26] = 0;
    return p;
  }
  p[24] = (f['duration_seconds'] as num).toDouble();
  p[25] = (f['bin_hz'] as num).toDouble();
  p[26] = (f['spectrum'] as List).length.toDouble();
  p[42] = samples.length.toDouble();
  p[43] = (f['step_seconds'] as num).toDouble();
  p[44] = (f['start_seconds'] as num).toDouble();
  p[45] = f['triggered'] == true ? 1 : 0;
  p[46] = (p[43] * p[14]).roundToDouble();
  p[47] = .1;
  return [
    ...p,
    ...samples,
    ...(f['spectrum'] as List).cast<num>().map((v) => v.toDouble()),
  ];
}

void main() {
  test('ABI3 PCM sample time/count and old envelope remain distinct', () {
    final r = AudioSnapshot.decode(wavePacket())!;
    expect(r.sampledWave, isTrue);
    expect(r.wave.length, 481);
    expect(r.waveMs, closeTo(20, 1e-9));
    expect(r.waveStepMs, closeTo(1000 / 24000, 1e-9));
    expect(r.spectrum.length, 512);
    final peak = r.spectrum.reduce((a, b) => a > b ? a : b);
    expect(r.spectrum.indexOf(peak) * r.binHz, closeTo(440, r.binHz));
    expect(r.waveTriggered, isTrue);
    expect(AudioSnapshot.decode(wavePacket(details: false))!.wave, isEmpty);
    expect(AudioSnapshot.decode(version2(details: true))!.sampledWave, isFalse);
    expect(AudioSnapshot.decode(wavePacket().sublist(0, 60)), isNull);
    expect(AudioSnapshot.decode(wavePacket().sublist(0, 48)), isNull);
    for (final (field, value) in [
      (42, 513.0),
      (43, 0.0),
      (44, -1.0),
      (45, .5),
      (46, 9.0),
      (47, -.1),
      (24, .5),
    ]) {
      final p = wavePacket()..[field] = value;
      expect(AudioSnapshot.decode(p), isNull, reason: 'field $field');
    }
  });
  test('production waveform fixtures retain sine periods, dual complexity and silence', () {
    final sine = AudioSnapshot.decode(wavePacket())!;
    var rising = 0;
    for (var i = 1; i < sine.wave.length; i++) {
      if (sine.wave[i - 1] <= 0 && sine.wave[i] > 0) rising++;
    }
    expect((rising - 440 * sine.waveMs / 1000).abs(), lessThan(1.1));
    final dual = AudioSnapshot.decode(wavePacket(name: 'dual'))!,
        silence = AudioSnapshot.decode(wavePacket(name: 'silence'))!,
        noise = AudioSnapshot.decode(wavePacket(name: 'noise'))!;
    expect(dual.wave, isNot(sine.wave));
    expect(silence.wave.every((v) => v == 0), isTrue);
    expect(silence.waveTriggered, isFalse);
    expect(noise.wave, isNot(sine.wave));
    expect(noise.waveTriggered, isFalse);
  });
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('ABI3 real PCM page integration and palette ${mode.name}', (
      t,
    ) async {
      final state = AppState()..setThemeMode(mode);
      final bridge = FixtureBridge()
        ..makePacket = (seq, details) =>
            wavePacket(details: details)..[2] = seq.toDouble();
      final c = AudioCapture(bridge: bridge);
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: mode,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExplorePage(state: state, capture: c),
            ),
          ),
        ),
      );
      await c.start();
      final details = find.byType(ExpansionTile);
      await t.ensureVisible(details);
      await t.pumpAndSettle();
      await t.tap(details);
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 66));
      await t.ensureVisible(find.byKey(const ValueKey('live-waveform')));
      await t.pump();
      final paint =
          t
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('live-waveform')),
                  )
                  .painter!
              as SignalPainter;
      expect(
        t.getSize(find.byKey(const ValueKey('live-waveform'))).width,
        greaterThan(200),
        reason: 'waveform needs a nonzero drawable time axis',
      );
      expect(paint.sampled, isTrue);
      expect(paint.data, c.current!.wave);
      expect(paint.xMaximum, closeTo(20, 1e-9));
      expect(
        paint.colors!.brightness,
        mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
      state.dispose();
    });
  }
}
