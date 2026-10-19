// Actual production widgets; synthetic production-native snapshots, NOT a phone.
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

import '../test/m3_ui_test.dart'
    show mechanicalState, calibrationHost, press, reveal;
import '../test/m3_model_test.dart' show strongCalibration, curvePacket;

void main() {
  testWidgets('M3 actual-widget host previews, synthetic data only', (t) async {
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
    // Canvas TextPainter has no inherited Material font; load its system aliases
    // only in this host screenshot harness. App fonts and APK stay unchanged.
    for (final family in ['Arial', 'sans-serif', 'Segoe UI']) {
      await (FontLoader(family)..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts/msyh.ttc',
                ).readAsBytesSync(),
              ),
            ),
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
    final state = await mechanicalState();
    await state.profiles.saveCalibration(
      state.profiles.selected!.id,
      strongCalibration(),
      state.profiles.archive.revision,
    );
    state.selectPianoNote('A1');
    state.applyPianoCurve(state.profiles.selected!.id);
    var seq = 0, session = 7;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      AndroidAudioBridge.channel,
      (call) async {
        if (call.method == 'start') {
          return {'status': 'running', 'session': ++session};
        }
        if (call.method == 'snapshot') {
          return {
            'status': 'running',
            'data': curvePacket()
              ..[1] = session.toDouble()
              ..[2] = (++seq).toDouble(),
          };
        }
        return null;
      },
    );
    final out = Directory('artifacts/m3/screenshots')
      ..createSync(recursive: true);
    final boundary = GlobalKey();
    Widget frame(Widget child) => RepaintBoundary(
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
                    'HOST TEST · SYNTHETIC · NOT PHONE / PIANO EVIDENCE',
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
          Expanded(child: child),
        ],
      ),
    );
    Future<void> snap(String name) async {
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final (language, mode) in [
      ('zh', ThemeMode.light),
      ('en', ThemeMode.dark),
    ]) {
      state.setLocale(Locale(language));
      state.setThemeMode(mode);
      state.setMinimal(false);
      await t.pumpWidget(frame(OpenTuneApp(state: state)));
      await t.pumpAndSettle();
      await press(t, 'piano-capture-toggle');
      await t.pump(const Duration(milliseconds: 100));
      t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await snap('piano-curve-$language-${mode.name}');
      state.setMinimal(true);
      await t.pumpAndSettle();
      t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await snap('piano-focus-$language-${mode.name}');
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      state.setMinimal(false);
      await t.pumpWidget(
        frame(
          calibrationHost(
            state,
            factory: (midi, a4, association) => AudioCapture(
              partialMidi: midi,
              referenceHz: a4,
              associationHz: association,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await snap('calibration-entry-$language-${mode.name}');
      await press(t, 'cal-capture-toggle');
      await t.pump(const Duration(milliseconds: 100));
      await reveal(t, 'cal-first-source');
      await snap('calibration-quality-$language-${mode.name}');
      await reveal(t, 'cal-curve-plot');
      await snap('calibration-curve-$language-${mode.name}');
      await press(t, 'calibration-target-table');
      await snap('calibration-table-$language-${mode.name}');
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    }
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      AndroidAudioBridge.channel,
      null,
    );
  });
}
