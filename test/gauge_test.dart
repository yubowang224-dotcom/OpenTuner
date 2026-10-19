import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/l10n/generated/app_localizations.dart';
import 'package:opentune_tuner/model/gauge_reading.dart';
import 'package:opentune_tuner/widgets/tuning_gauge.dart';

Future<void> showGauge(
  WidgetTester tester,
  GaugeReading reading, {
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: SizedBox(
            width: 360,
            child: TuningGauge(reading: reading, targetNote: 'A4'),
          ),
        ),
      ),
    ),
  );
}

DialPainter dial(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(find.byKey(const ValueKey('gauge-dial')))
            .painter!
        as DialPainter;

void main() {
  testWidgets('no signal is not zero cents or in tune', (tester) async {
    await showGauge(tester, const GaugeReading.waiting());
    expect(find.text('— cents'), findsOneWidget);
    expect(find.text('In tune'), findsNothing);
    expect(dial(tester).active, isFalse);
  });
  testWidgets('needle interpolates and retargets continuously', (tester) async {
    await showGauge(tester, const GaugeReading.waiting());
    await showGauge(tester, GaugeReading.tracked(note: 'A4', cents: -40));
    await tester.pump(const Duration(milliseconds: 80));
    final halfway = dial(tester).cents;
    expect(halfway, inExclusiveRange(-40, 0));
    await showGauge(tester, GaugeReading.tracked(note: 'A4', cents: 40));
    expect(dial(tester).cents, closeTo(halfway, .001));
    await tester.pump(const Duration(milliseconds: 160));
    expect(dial(tester).cents, closeTo(40, .001));
    expect(find.text('Sharp'), findsOneWidget);
  });
  testWidgets(
    'invalid input clears values and fades needle while returning to center',
    (tester) async {
      await showGauge(tester, GaugeReading.tracked(note: 'A4', cents: -20));
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.text('Flat'), findsOneWidget);
      await showGauge(tester, const GaugeReading.uncertain());
      expect(find.text('No stable pitch'), findsOneWidget);
      expect(find.text('— cents'), findsOneWidget);
      expect(dial(tester).active, isFalse);
      await tester.pump(const Duration(milliseconds: 160));
      expect(dial(tester).cents, closeTo(0, .001));
    },
  );
  testWidgets(
    'visual clamp preserves actual numeric deviation and demo provenance',
    (tester) async {
      await showGauge(
        tester,
        GaugeReading.demonstration(note: 'A4', cents: 120),
      );
      await tester.pump(const Duration(milliseconds: 160));
      expect(dial(tester).cents, 50);
      expect(find.text('+120.0 cents'), findsOneWidget);
      expect(find.text('Demo note'), findsOneWidget);
    },
  );
  testWidgets('in-tune state and reduced motion update without an animation', (
    tester,
  ) async {
    await showGauge(
      tester,
      GaugeReading.tracked(note: 'A4', cents: -2),
      reduceMotion: true,
    );
    expect(dial(tester).cents, -2);
    expect(find.text('In tune'), findsOneWidget);
    await showGauge(
      tester,
      GaugeReading.tracked(note: 'A4', cents: 25),
      reduceMotion: true,
    );
    expect(dial(tester).cents, 25);
  });
  test('non-finite readings cannot enter the display', () {
    expect(
      () => GaugeReading.tracked(note: 'A4', cents: double.nan),
      throwsArgumentError,
    );
    expect(() => GaugeReading.tracked(note: '', cents: 0), throwsArgumentError);
  });
}
