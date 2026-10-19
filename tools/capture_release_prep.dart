// Production metronome controls, controlled snapshots; NOT phone/audio evidence.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/audio/metronome_page.dart';
import 'package:opentune_tuner/audio/metronome_player.dart';
import 'package:opentune_tuner/l10n/generated/app_localizations.dart';
import 'package:opentune_tuner/model/app_state.dart';
import 'package:opentune_tuner/theme.dart';

import '../test/metronome_transport_test.dart' show TransportBridge;

void main() {
  testWidgets('Release-prep production controls; host snapshots only', (
    t,
  ) async {
    final config = jsonDecode(File('.local/toolchain.json').readAsStringSync());
    for (final (family, path) in [
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
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(() => t.view.reset());
    final out = Directory('artifacts/release-prep/screenshots')
      ..createSync(recursive: true);
    for (final (language, brightness) in [
      ('zh', Brightness.light),
      ('en', Brightness.dark),
    ]) {
      final state = AppState()
            ..setBpm(137)
            ..setMeter('6/8')
            ..setSubdivision(3),
          player = MetronomePlayer(bridge: TransportBridge()),
          key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: Column(
            children: [
              const Directionality(
                textDirection: TextDirection.ltr,
                child: ColoredBox(
                  color: Color(0xFF462200),
                  child: SizedBox(
                    height: 26,
                    width: double.infinity,
                    child: Center(
                      child: Text(
                        'HOST TEST · CONTROLLED SNAPSHOT · NO PHONE / AUDIO',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 10,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  locale: Locale(language),
                  theme: buildTheme(brightness),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: MetronomePage(state: state, player: player),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await t.pumpAndSettle();
      Future<void> press(String value) async {
        final f = find.byKey(ValueKey(value));
        await t.ensureVisible(f);
        await t.pumpAndSettle();
        await t.tap(f);
        await t.pump(const Duration(milliseconds: 66));
      }

      Future<void> snap(String value) async {
        t
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await t.pump();
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final im =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final data = await im.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/$value-$language.png')
              .writeAsBytesSync(data!.buffer.asUint8List());
          im.dispose();
        });
      }

      await press('metro-toggle');
      await snap('playing');
      await press('metro-toggle');
      expect(player.status, 'paused');
      await snap('paused');
      await press('metro-stop');
      expect(player.current, isNull);
      await snap('stopped');
      await t.pumpWidget(const SizedBox());
      player.dispose();
      state.dispose();
      await t.pump();
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
