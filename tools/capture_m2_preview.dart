// flutter test tools/capture_m2_preview.dart
// Actual production widgets; test-only channel snapshots, never phone evidence.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../test/m2_ui_test.dart' show MemoryProfiles, press;

import 'package:opentune_tuner/model/profile_store.dart';
import 'package:opentune_tuner/model/piano_model.dart';

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
  testWidgets(
    'M2 piano/profile actual production widgets; synthetic snapshots not phone',
    (t) async {
      final config = jsonDecode(
        File('.local/toolchain.json').readAsStringSync(),
      );
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
      final profiles = ProfileManager(MemoryProfiles());
      await profiles.load();
      await profiles.create('Studio piano / 练习琴', PianoKind.digital, 442, 69);
      final state = AppState(profiles: profiles)
        ..selectPage(1)
        ..setLocale(const Locale('zh'));
      var uncertain = false, outputError = false;
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
            final hz =
                pianoKey(state.pianoNote).frequency(state.referenceHz) *
                math.pow(2, 8 / 1200);
            p[6] = hz;
            p[7] = hz;
            p[8] = (69 + 12 * math.log(hz / state.referenceHz) / math.ln2)
                .roundToDouble();
            p[9] = 8;
            if (uncertain) {
              p[5] = 1;
              p[6] = 0;
              p[7] = 0;
              p[10] = 0;
            }
            return {'status': 'running', 'data': p};
          }
          if (call.method == 'toneStart') {
            return {
              'status': outputError ? 'error' : 'playing',
              'rate': outputError ? 8000 : 48000,
            };
          }
          if (call.method == 'toneStatus') {
            return {
              'status': outputError ? 'error' : 'playing',
              'rate': outputError ? 8000 : 48000,
            };
          }
          return null;
        },
      );
      final output = Directory('artifacts/m2/screenshots')
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

      for (final (note, mode, focus, language) in [
        ('A0', ThemeMode.light, false, 'zh'),
        ('C8', ThemeMode.dark, true, 'en'),
        ('A4', ThemeMode.light, true, 'zh'),
        ('C4', ThemeMode.dark, false, 'en'),
      ]) {
        state.setMinimal(false);
        state.setLocale(Locale(language));
        state.setThemeMode(mode);
        state.selectPianoNote(note);
        await wait();
        await press(t, 'piano-capture-toggle');
        await wait();
        state.setMinimal(focus);
        await wait();
        t
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await capture('piano-$note-${mode.name}-${focus ? 'focus' : 'normal'}');
      }
      await t.ensureVisible(
        find.byKey(const PageStorageKey<String>('piano-profile-list-v1')),
      );
      await wait();
      await capture('piano-target-and-measured');
      outputError = true;
      await press(t, 'reference-toggle');
      await wait();
      await t.ensureVisible(find.byKey(const ValueKey('reference-toggle')));
      await wait();
      await capture('piano-reference-error');
      outputError = false;
      state.setMinimal(false);
      state.setPianoKind(PianoKind.grand);
      await wait();
      t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await capture('piano-mechanical-et-only');
      uncertain = true;
      await press(t, 'piano-capture-toggle');
      await wait();
      t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await capture('piano-uncertain');
      await press(t, 'piano-profile-list-v1');
      final profileName = find.byKey(
        const PageStorageKey<String>('profile-name'),
      );
      await t.ensureVisible(profileName);
      await wait();
      await capture('piano-profile-list');
      state.selectPage(4);
      state.setLocale(const Locale('zh'));
      state.setThemeMode(ThemeMode.light);
      await wait();
      final input = find.byKey(const ValueKey('reference-a4'));
      await t.ensureVisible(input);
      await wait();
      await t.enterText(input, '442');
      await press(t, 'reference-apply');
      final scroll = t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      scroll.jumpTo(math.max(0, scroll.pixels - 110));
      await wait();
      await capture('settings-a4-442');
      await t.pumpWidget(const SizedBox());
      state.dispose();
      debugDefaultTargetPlatformOverride = null;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        null,
      );
    },
  );
}
