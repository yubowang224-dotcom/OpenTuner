// flutter test tools/capture_appearance_preview.dart
// Actual production widgets; test-only channel snapshots, never phone evidence.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../test/guitar_presets_test.dart' show choose;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/app.dart';
import 'package:opentune_tuner/audio/audio_capture.dart';
import 'package:opentune_tuner/model/app_state.dart';

import '../test/waveform_test.dart' show wavePacket;

void main() {
  testWidgets('M1 preset/voice actual component preview; injected not phone', (
    t,
  ) async {
    final config = jsonDecode(File('.local/toolchain.json').readAsStringSync());
    for (final (family, path) in [
      (
        'Ahem',
        '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts/msyh.ttc',
      ),
      (
        'Roboto',
        '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts/msyh.ttc',
      ),
      (
        'MaterialIcons',
        '${config['flutter']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    ]) {
      await (FontLoader(family)..addFont(
            Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
          ))
          .load();
    }
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      t.view.reset();
    });
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    var seq = 0, session = 7;
    const signal = 'sine440';
    final state = AppState()..setLocale(const Locale('zh'));
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      AndroidAudioBridge.channel,
      (call) async {
        if (call.method == 'start') {
          return {'status': 'running', 'session': ++session};
        }
        if (call.method == 'snapshot') {
          final p = wavePacket(
            name: signal,
            details: (call.arguments as Map)['details'] == true,
          );
          p[1] = session.toDouble();
          p[2] = (++seq).toDouble();
          if (state.page == 0) {
            final hz =
                state.selectedGuitarPreset.strings[state.guitarString]
                    .frequency(440) *
                math.pow(2, 10 / 1200);
            p[6] = hz;
            p[7] = hz;
            p[8] = (69 + 12 * math.log(hz / 440) / math.ln2).roundToDouble();
            p[9] = 10;
          }
          if (signal == 'silence' || signal == 'noise') {
            p[5] = signal == 'silence' ? 0 : 1;
            p[6] = 0;
            p[7] = 0;
            p[10] = 0;
            p[11] = signal == 'silence' ? -120 : -22;
          }
          return {'status': 'running', 'data': p};
        }
        if (call.method == 'toneStart') {
          return {'status': 'playing', 'rate': 48000};
        }
        if (call.method == 'toneStatus') {
          return {'status': 'playing', 'rate': 48000};
        }
        return null;
      },
    );
    final output = Directory('artifacts/m1-guitar/screenshots')
      ..createSync(recursive: true);
    final boundary = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: Column(
          children: [
            const Directionality(
              textDirection: TextDirection.ltr,
              child: ColoredBox(
                color: Color(0xFF462200),
                child: SizedBox(
                  height: 28,
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      'TEST SNAPSHOT · NOT A PHONE · NO AUDIO OUTPUT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontFamily: 'Roboto',
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: OpenTuneApp(state: state)),
          ],
        ),
      ),
    );
    Future<void> wait() async {
      for (var i = 0; i < 24; i++) {
        await t.pump(const Duration(milliseconds: 20));
        expect(t.takeException(), isNull);
      }
    }

    Future<void> capture(String name) async {
      await wait();
      await t.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${output.path}/$name.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final (language, mode, focus, id) in [
      ('zh', ThemeMode.light, false, 'dropD'),
      ('zh', ThemeMode.dark, true, 'openD'),
      ('en', ThemeMode.light, false, 'halfDown'),
      ('en', ThemeMode.dark, true, 'openG'),
    ]) {
      state.setLocale(Locale(language));
      state.setThemeMode(mode);
      state.setMinimal(false);
      await wait();
      await choose(t, id);
      await wait();
      await capture('preset-$id-stopped');
      final button = find.byKey(const ValueKey('capture-toggle'));
      await t.ensureVisible(button);
      await t.tap(button);
      await wait();
      state.setMinimal(focus);
      await wait();
      t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await capture('preset-$id-${mode.name}-${focus ? 'focus' : 'normal'}');
    }
    state.setMinimal(false);
    state.setThemeMode(ThemeMode.dark);
    state.setLocale(const Locale('zh'));
    await wait();
    final gain = find.byKey(const ValueKey('guitar-reference-gain'));
    await t.ensureVisible(gain);
    await capture('guitar-reference-gain-dark');
    final ref = find.byKey(const ValueKey('reference-toggle'));
    await t.ensureVisible(ref);
    await t.tap(ref);
    await capture('guitar-reference-playing-dark');
    state.selectPage(3);
    await capture('metronome-material-note-dark');
    state.setLocale(const Locale('en'));
    state.setThemeMode(ThemeMode.light);
    await capture('metronome-material-note-light-en');
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      state.setThemeMode(mode);
      await wait();
      await t.ensureVisible(find.byKey(const ValueKey('metro-gain')));
      await capture('metronome-gain-${mode.name}');
    }
    state.selectPage(4);
    await wait();
    final ack = find.byKey(const ValueKey('acknowledgements-link'));
    await t.ensureVisible(ack);
    await wait();
    expect(ack.hitTestable(), findsOneWidget);
    await t.tap(ack);
    await wait();
    for (final (locale, mode) in [
      ('zh', ThemeMode.dark),
      ('en', ThemeMode.light),
    ]) {
      state.setLocale(Locale(locale));
      state.setThemeMode(mode);
      await capture('acknowledgements-$locale-${mode.name}');
    }
    Navigator.of(t.element(find.byType(BackButton))).pop();
    await wait();
    await t.pumpWidget(const SizedBox());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      AndroidAudioBridge.channel,
      null,
    );
  });
}
