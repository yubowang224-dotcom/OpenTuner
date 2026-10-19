import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/app.dart';
import 'package:opentune_tuner/model/app_state.dart';
import 'package:opentune_tuner/pages.dart';

import 'app_test.dart' show navigate;

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  for (final locale in ['zh', 'en']) {
    testWidgets(
      'acknowledgements from focus, theme/locale/font every frame and system back $locale',
      (t) async {
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(t.platformDispatcher.clearLocalesTestValue);
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(393, 852);
        final state = AppState()
          ..setLocale(Locale(locale))
          ..setMinimal(true);
        await t.pumpWidget(OpenTuneApp(state: state));
        await t.pumpAndSettle();
        await navigate(t, 4);
        Future<void> frames() async {
          for (var i = 0; i < 24; i++) {
            await t.pump(const Duration(milliseconds: 16));
            expect(t.takeException(), isNull);
            expect(find.byType(ErrorWidget), findsNothing);
          }
        }

        for (final theme in [ThemeMode.dark, ThemeMode.light]) {
          final entry = find.byKey(const ValueKey('acknowledgements-link'));
          await t.ensureVisible(entry);
          await t.pumpAndSettle();
          await t.tap(entry);
          await frames();
          expect(find.byType(AcknowledgementsPage), findsOneWidget);
          state.setThemeMode(theme);
          state.setLocale(null);
          t.platformDispatcher.localesTestValue = [const Locale('zh')];
          t.platformDispatcher.textScaleFactorTestValue = 2;
          await frames();
          var text = t
              .widget<SelectableText>(
                find.byKey(const ValueKey('acknowledgements-body')),
              )
              .data!;
          expect(text, contains('哈尔滨工业大学'));
          expect(text, contains('张淼'));
          expect(text, contains('顶级原则'));
          expect(text, contains('共产主义'));
          t.platformDispatcher.localesTestValue = [const Locale('en')];
          await frames();
          text = t
              .widget<SelectableText>(
                find.byKey(const ValueKey('acknowledgements-body')),
              )
              .data!;
          expect(text, contains('Harbin Institute of Technology'));
          expect(text, contains('Zhang Miao'));
          expect(text, contains('communist ideal'));
          await t.drag(
            find.byType(SingleChildScrollView).last,
            const Offset(0, -1600),
          );
          await frames();
          final repository = t
              .widget<SelectableText>(
                find.byKey(const ValueKey('source-repository')),
              )
              .data!;
          expect(
            repository,
            contains('https://github.com/yubowang224-dotcom/OpenTuner'),
          );
          expect(repository, contains('Source repository'));
          await t.binding.handlePopRoute();
          await frames();
          expect(find.byType(AcknowledgementsPage), findsNothing);
          t.platformDispatcher.textScaleFactorTestValue = 1;
          await frames();
        }
        await t.pumpWidget(const SizedBox());
        state.dispose();
      },
    );
  }
}
