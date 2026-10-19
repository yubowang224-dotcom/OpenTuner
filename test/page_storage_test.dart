import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/app.dart';
import 'package:opentune_tuner/model/app_state.dart';

void main() {
  testWidgets(
    'Explore scroll, navigation and expansion restore without type conflict',
    (tester) async {
      tester.view.physicalSize = const Size(393, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState()..selectPage(2);
      await tester.pumpWidget(OpenTuneApp(state: state));
      await tester.pumpAndSettle();
      final scroll = find.byType(ListView);
      await tester.drag(scroll, const Offset(0, -420));
      await tester.pumpAndSettle();
      state.selectPage(0);
      await tester.pumpAndSettle();
      state.selectPage(2);
      await tester.pumpAndSettle();
      // Do not consume/suppress FlutterError: a cast error must fail this test.
      expect(find.byType(ErrorWidget), findsNothing);
      final details = find.byType(ExpansionTile);
      await tester.ensureVisible(details);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Live waveform, spectrum & diagnostics'));
      await tester.pumpAndSettle();
      state.setMinimal(true);
      await tester.pumpAndSettle();
      state.setMinimal(false);
      await tester.pumpAndSettle();
      expect(find.byType(ErrorWidget), findsNothing);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
