// Run with: flutter test tools/capture_preview.dart
// Renders the actual production widgets. No alternate HTML/mock UI.
// Uses a local Windows font for readable CJK in screenshots only; never bundles it.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/app.dart';
import 'package:opentune_tuner/model/app_state.dart';

void main() {
  testWidgets('capture actual Flutter UI states', (tester) async {
    final config = jsonDecode(
      File('.local/toolchain.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final fonts = [
      (
        'Roboto',
        '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts/msyh.ttc',
      ),
      (
        'MaterialIcons',
        '${config['flutter']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    ];
    for (final (family, path) in fonts) {
      final file = File(path);
      if (!file.existsSync()) throw StateError('Preview font not found: $path');
      final bytes = file.readAsBytesSync();
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    final output = Directory('artifacts/screenshots')
      ..createSync(recursive: true);
    final state = AppState()..setLocale(const Locale('zh'));
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: OpenTuneApp(state: state),
      ),
    );

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${output.path}/$name.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }

    await capture('guitar-zh');
    state.setMinimal(true);
    await capture('minimal-zh');
    state.setDemo(true);
    state.setDemoCents(-18);
    await capture('demo-minimal-zh');
    state.setMinimal(false);
    state.selectPage(1);
    await capture('piano-zh');
    state.selectPage(2);
    await capture('explore-zh');
    state.selectPage(3);
    await capture('metronome-zh');
    state.selectPage(4);
    await capture('settings-zh');
    state.setLocale(const Locale('en'));
    state.selectPage(0);
    await capture('guitar-en');
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
