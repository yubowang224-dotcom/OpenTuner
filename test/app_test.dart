import 'package:opentune_tuner/widgets/tuning_gauge.dart' as opentune_gauge;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/app.dart';
import 'package:opentune_tuner/model/app_state.dart';

Future<void> openApp(
  WidgetTester tester, {
  AppState? state,
  Locale locale = const Locale('en'),
  Size size = const Size(393, 852),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = [locale];
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearLocalesTestValue();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(OpenTuneApp(state: state));
  await tester.pumpAndSettle();
}

Future<void> navigate(WidgetTester tester, int page) async {
  if (find.byKey(ValueKey('nav-$page')).evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('focus-tools')));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.byKey(ValueKey('nav-$page')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('nav-$page')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('follows system locale and responds to system language changes', (
    tester,
  ) async {
    await openApp(tester, locale: const Locale('zh', 'CN'));
    expect(find.text('让每根弦，恰到好处。'), findsOneWidget);
    tester.platformDispatcher.localesTestValue = [const Locale('en', 'US')];
    await tester.pumpAndSettle();
    expect(find.text('Find your balance.'), findsOneWidget);
    tester.platformDispatcher.localesTestValue = [const Locale('fr', 'FR')];
    await tester.pumpAndSettle();
    expect(find.text('Find your balance.'), findsOneWidget);
  });

  testWidgets('all pages navigate in Chinese and English', (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await openApp(tester, state: state, locale: const Locale('zh'));
    for (final language in ['zh', 'en']) {
      state.setLocale(Locale(language));
      await tester.pumpAndSettle();
      final titles = language == 'zh'
          ? ['让每根弦，恰到好处。', '认真对待，每一个音。', '看见你的声音。', '找到自己的节奏。', '简单一点，刚刚好。']
          : [
              'Find your balance.',
              'Every note, considered.',
              'Get to know your sound.',
              'Make room for rhythm.',
              'Just the essentials.',
            ];
      for (var i = 0; i < 5; i++) {
        await navigate(tester, i);
        expect(find.text(titles[i]), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('language selection through settings and return to system', (
    tester,
  ) async {
    await openApp(tester, locale: const Locale('zh'));
    await navigate(tester, 4);
    await tester.tap(find.byKey(const ValueKey('language-system')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(find.text('Just the essentials.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('language-en')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follow system').last);
    await tester.pumpAndSettle();
    expect(find.text('简单一点，刚刚好。'), findsOneWidget);
  });

  testWidgets('minimal mode hides advanced UI and preserves target selection', (
    tester,
  ) async {
    final state = AppState();
    addTearDown(state.dispose);
    await openApp(tester, state: state);
    expect(find.byKey(const ValueKey('gauge-status')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('guitar-target-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guitar-target-2')));
    await tester.pumpAndSettle();
    expect(state.guitarString, 2);
    await tester.tap(find.byKey(const ValueKey('minimal-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Find your balance.'), findsNothing);
    expect(find.byKey(const ValueKey('measurement-details')), findsNothing);
    expect(find.byKey(const ValueKey('demo-toggle')), findsNothing);
    expect(
      tester
          .widget<opentune_gauge.TuningGauge>(
            find.byType(opentune_gauge.TuningGauge),
          )
          .targetNote,
      'D3',
    );
    await navigate(tester, 1);
    expect(find.byKey(const ValueKey('piano-target-A4')), findsOneWidget);
    expect(find.text('Every note, considered.'), findsNothing);
    await navigate(tester, 4);
    await tester.tap(find.byKey(const ValueKey('settings-minimal')));
    await tester.pumpAndSettle();
    await navigate(tester, 0);
    expect(find.text('Find your balance.'), findsOneWidget);
    expect(
      tester
          .widget<opentune_gauge.TuningGauge>(
            find.byType(opentune_gauge.TuningGauge),
          )
          .targetNote,
      'D3',
    );
  });

  testWidgets(
    'real piano has no demonstration fallback and navigation clears measurement',
    (tester) async {
      final state = AppState();
      addTearDown(state.dispose);
      await openApp(tester, state: state);
      await navigate(tester, 1);
      expect(find.byKey(const ValueKey('demo-toggle')), findsNothing);
      expect(
        tester
            .widget<opentune_gauge.TuningGauge>(
              find.byType(opentune_gauge.TuningGauge),
            )
            .reading
            .isValid,
        isFalse,
      );
      expect(state.demo, isFalse);
      await navigate(tester, 2);
      await navigate(tester, 1);
      expect(
        tester
            .widget<opentune_gauge.TuningGauge>(
              find.byType(opentune_gauge.TuningGauge),
            )
            .reading
            .isValid,
        isFalse,
      );
      expect(find.text('Demo · no audio'), findsNothing);
    },
  );

  testWidgets(
    'capture and metronome are opt-in; tempo edits do not start audio',
    (tester) async {
      await openApp(tester);
      await navigate(tester, 2);
      final capture = find.byWidgetPredicate((w) => w is FilledButton);
      await tester.ensureVisible(capture);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(capture).onPressed, isNotNull);
      expect(
        find.text('Microphone stopped · start when ready'),
        findsOneWidget,
      );
      await navigate(tester, 3);
      await tester.tap(find.byKey(const ValueKey('bpm-increase')));
      await tester.pumpAndSettle();
      expect(find.text('101'), findsOneWidget);
      final playback = find.byWidgetPredicate((w) => w is FilledButton);
      expect(tester.widget<FilledButton>(playback).onPressed, isNotNull);
      expect(find.text('Stopped'), findsOneWidget);
    },
  );

  // Include all pages, narrow phones, landscape, rail navigation and 200% text.
  for (final locale in ['en', 'zh']) {
    for (final (size, scale) in [
      (const Size(320, 568), 1.0),
      (const Size(393, 852), 1.0),
      (const Size(600, 960), 1.0),
      (const Size(844, 390), 1.0),
      (const Size(1024, 768), 1.0),
      (const Size(320, 640), 2.0),
    ]) {
      testWidgets('layout $locale ${size.width}x${size.height} text $scale', (
        tester,
      ) async {
        await openApp(tester, locale: Locale(locale), size: size, scale: scale);
        for (var i = 0; i < 5; i++) {
          await navigate(tester, i);
          expect(tester.takeException(), isNull, reason: 'initial page $i');
          await tester.drag(
            find.byType(ListView).first,
            const Offset(0, -1800),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'scrolled page $i');
        }
      });
    }
  }
}
