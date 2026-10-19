// flutter test tools/capture_appearance_preview.dart
// Actual production widgets; test-only channel snapshots, never phone evidence.
import 'dart:convert';
import 'dart:io';
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
  testWidgets('actual appearance preview with labeled synthetic input', (
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
    var signal = 'sine440';
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
            p[6] = 82.884;
            p[7] = 82.884;
            p[8] = 40;
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
        return null;
      },
    );
    final output = Directory('artifacts/appearance2/screenshots')
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
                      'TEST INJECTION · C++ SYNTHETIC PCM · NOT A PHONE',
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

    for (final page in [0, 2]) {
      state.setMinimal(false);
      state.selectPage(page);
      await wait();
      await t.ensureVisible(find.byKey(const ValueKey('capture-toggle')));
      await t.tap(find.byKey(const ValueKey('capture-toggle')));
      await wait();
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        state.setThemeMode(mode);
        for (final focus in [false, true]) {
          state.setMinimal(focus);
          await wait();
          t
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await capture(
            '${page == 0 ? 'guitar' : 'explore'}-${mode.name}-${focus ? 'focus' : 'normal'}',
          );
        }
      }
    }
    state.setMinimal(false);
    await wait();
    final header = find
        .descendant(
          of: find.byType(ExpansionTile),
          matching: find.byType(ListTile),
        )
        .first;
    await t.ensureVisible(header);
    await wait();
    await t.tap(header);
    await wait();
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      state.setThemeMode(mode);
      for (final name in ['sine440', 'dual', 'silence', 'noise']) {
        signal = name;
        await wait();
        await t.ensureVisible(find.byKey(const ValueKey('live-waveform')));
        await capture('wave-${mode.name}-$name');
      }
    }
    for (final page in [1, 3, 4]) {
      state.selectPage(page);
      await capture('page-$page-dark');
    }
    await t.ensureVisible(find.byKey(const ValueKey('theme-dark')));
    await t.tap(find.byKey(const ValueKey('theme-dark')));
    await capture('theme-popup-dark');
    Navigator.of(t.element(find.byType(Scaffold).first)).pop();
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
