import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/app.dart';
import 'package:opentune_tuner/audio/audio_capture.dart';
import 'package:opentune_tuner/audio/calibration_page.dart';
import 'package:opentune_tuner/audio/reference_player.dart';
import 'package:opentune_tuner/l10n/generated/app_localizations.dart';
import 'package:opentune_tuner/model/app_state.dart';
import 'package:opentune_tuner/model/profile_store.dart';
import 'package:opentune_tuner/theme.dart';

import 'audio_test.dart' show FixtureBridge, packet;
import 'm2_ui_test.dart' show MemoryProfiles, pianoWidgets;
import 'm3_model_test.dart' show partialPacket, calibration;
import 'stage25_test.dart' show ToneFixture;

Future<Finder> reveal(WidgetTester t, String key) async {
  final finder = find.byWidgetPredicate(
    (w) => w.key == ValueKey(key) || w.key == PageStorageKey<String>(key),
    description: key,
  );
  if (finder.evaluate().isEmpty) {
    final scrollable = find
        .descendant(
          of: find.byType(CalibrationPage),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = t.state<ScrollableState>(scrollable).position;
    position.jumpTo(0);
    await t.pumpAndSettle();
    for (
      var attempt = 0;
      attempt < 80 && finder.evaluate().isEmpty;
      attempt++
    ) {
      final next = (position.pixels + position.viewportDimension * .65).clamp(
        0,
        position.maxScrollExtent,
      );
      if (next == position.pixels) break;
      position.jumpTo(next.toDouble());
      await t.pumpAndSettle();
    }
  }
  expect(finder, findsOneWidget, reason: 'bounded real scroll to $key');
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  return finder;
}

Future<void> press(WidgetTester t, String key) async {
  final item = await reveal(t, key);
  final target = t.widget(item) is ExpansionTile
      ? find.descendant(of: item, matching: find.byType(ListTile)).first
      : item;
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await t.tap(target);
  await t.pumpAndSettle();
}

class PendingProfileStore extends MemoryProfiles {
  Completer<void>? pending;
  bool fail = false;
  @override
  Future<ProfileArchive> save(ProfileArchive next, int revision) async {
    await pending?.future;
    if (fail) throw const ProfileException(ProfileIssue.unavailable);
    return super.save(next, revision);
  }
}

Future<AppState> mechanicalState({
  MemoryProfiles? store,
  bool calibrated = false,
}) async {
  final profiles = ProfileManager(store ?? MemoryProfiles());
  await profiles.load();
  await profiles.create('Host test grand', PianoKind.grand, 440, 69);
  if (calibrated) {
    await profiles.saveCalibration(
      profiles.selected!.id,
      calibration(),
      profiles.archive.revision,
    );
  }
  return AppState(profiles: profiles)
    ..selectPage(1)
    ..setPianoKind(PianoKind.grand);
}

Widget calibrationHost(
  AppState state, {
  AudioCapture Function(int, double, double?)? factory,
}) => ListenableBuilder(
  listenable: state,
  builder: (context, _) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: state.locale ?? const Locale('en'),
    theme: buildTheme(),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: state.themeMode,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: CalibrationPage(
      state: state,
      profile: state.profiles.selected!,
      captureFactory:
          factory ??
          (midi, a4, association) => AudioCapture(
            bridge: FixtureBridge()
              ..makePacket = (seq, _) =>
                  partialPacket(midi)..[2] = seq.toDouble(),
            partialMidi: midi,
            referenceHz: a4,
            associationHz: association,
          ),
      measurementSource: 'synthetic_test',
    ),
  ),
);
void main() {
  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          AndroidAudioBridge.channel,
          (_) async => null,
        );
  });
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  pianoWidgets(
    'guided actual native feature fixtures: accept six, save, curve, remove/undo invalidates',
    (t) async {
      final state = await mechanicalState();
      await t.pumpWidget(calibrationHost(state));
      await t.pumpAndSettle();
      expect(
        t.widget<FilledButton>(await reveal(t, 'cal-generate')).onPressed,
        isNull,
      );
      for (final midi in [33, 45, 57, 69, 81, 93]) {
        await press(t, 'cal-guide-$midi');
        await press(t, 'cal-capture-toggle');
        await t.pump(const Duration(milliseconds: 66));
        expect(
          t.widget<FilledButton>(await reveal(t, 'cal-accept')).onPressed,
          isNotNull,
        );
        await reveal(t, 'cal-first-source');
        expect(find.textContaining('not directly measured'), findsOneWidget);
        await press(t, 'cal-accept');
        await reveal(t, 'cal-sample-$midi');
        expect(find.byKey(ValueKey('cal-sample-$midi')), findsOneWidget);
      }
      await press(t, 'cal-generate');
      await reveal(t, 'cal-curve-plot');
      expect(find.byKey(const ValueKey('cal-curve-plot')), findsOneWidget);
      await press(t, 'cal-save');
      expect(state.profiles.selected!.calibration!.samples.length, 6);
      expect(state.profiles.selected!.calibration!.curve!.points.length, 61);
      expect(state.applyPianoCurve(state.profiles.selected!.id), isTrue);
      await t.pumpAndSettle();
      await press(t, 'cal-remove');
      expect(state.pianoCurve, isNull);
      expect(find.byKey(const ValueKey('cal-curve-plot')), findsNothing);
      await press(t, 'cal-undo');
      await press(t, 'cal-save');
      expect(state.profiles.selected!.calibration!.samples.length, 6);
      expect(state.profiles.selected!.calibration!.curve, isNull);
      expect(t.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      await t.pumpWidget(const SizedBox());
      state.dispose();
      await t.pump();
    },
  );

  for (final fail in [false, true]) {
    pianoWidgets(
      'background during profile ${fail ? 'failed' : 'successful'} save releases busy without late apply',
      (t) async {
        final store = PendingProfileStore();
        final s = await mechanicalState(store: store);
        await t.pumpWidget(calibrationHost(s));
        await t.pumpAndSettle();
        store.pending = Completer();
        store.fail = fail;
        await press(t, 'cal-save');
        expect(s.profiles.busy, isTrue);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await t.pump();
        store.pending!.complete();
        await t.pumpAndSettle();
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
        expect(s.profiles.busy, isFalse);
        expect(
          t
              .widget<FilledButton>(await reveal(t, 'cal-capture-toggle'))
              .onPressed,
          isNotNull,
        );
        expect(s.pianoCurve, isNull);
        if (fail) {
          expect(s.profiles.issue, ProfileIssue.unavailable);
        } else {
          expect(s.profiles.selected!.calibration, isNotNull);
        }
        await t.pumpWidget(const SizedBox());
        s.dispose();
        await t.pump();
      },
    );
  }

  for (final change in ['a4', 'kind', 'page', 'target']) {
    pianoWidgets(
      'calibration config $change stops and forbids accepting old samples',
      (t) async {
        final state = await mechanicalState();
        await t.pumpWidget(calibrationHost(state));
        await t.pumpAndSettle();
        await press(t, 'cal-capture-toggle');
        await t.pump(const Duration(milliseconds: 33));
        switch (change) {
          case 'a4':
            state.setReferenceHz(442);
          case 'kind':
            state.setPianoKind(PianoKind.digital);
          case 'page':
            state.selectPage(2);
          case 'target':
            state.selectPianoNote('C8');
        }
        await t.pumpAndSettle();
        expect(
          t.widget<FilledButton>(await reveal(t, 'cal-accept')).onPressed,
          isNull,
        );
        await reveal(t, 'cal-stale');
        expect(find.textContaining('close and reopen'), findsOneWidget);
        expect(state.profiles.selected!.calibration, isNull);
        await t.pumpWidget(const SizedBox());
        state.dispose();
        await t.pump();
      },
    );
  }

  pianoWidgets(
    'late old-key partial snapshot cannot be saved under the next key',
    (t) async {
      final state = await mechanicalState();
      await t.pumpWidget(
        calibrationHost(
          state,
          factory: (midi, a4, association) => AudioCapture(
            bridge: FixtureBridge()
              ..makePacket = (seq, _) =>
                  partialPacket(69)..[2] = seq.toDouble(),
            partialMidi: midi,
            referenceHz: a4,
            associationHz: association,
          ),
        ),
      );
      await t.pumpAndSettle();
      await press(t, 'cal-guide-33');
      await press(t, 'cal-capture-toggle');
      await t.pump(const Duration(milliseconds: 66));
      expect(
        t.widget<FilledButton>(await reveal(t, 'cal-accept')).onPressed,
        isNull,
      );
      await press(t, 'cal-save');
      expect(state.profiles.selected!.calibration!.samples, isEmpty);
      await t.pumpWidget(const SizedBox());
      state.dispose();
      await t.pump();
    },
  );

  pianoWidgets(
    'actual App stops underlying input/reference before calibration route, back does not auto resume',
    (t) async {
      final state = await mechanicalState();
      final tones = ToneFixture();
      final player = ReferencePlayer(bridge: tones);
      var session = 7, sequence = 0, partial = false, midi = 69;
      final calls = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        (call) async {
          calls.add(call.method);
          if (call.method == 'start') {
            final args = call.arguments as Map;
            partial = args['mode'] == 'partial';
            midi = args['midi'] as int? ?? 69;
            return {'status': 'running', 'session': ++session};
          }
          if (call.method == 'snapshot') {
            final p = partial ? partialPacket(midi) : packet();
            p[1] = session.toDouble();
            p[2] = (++sequence).toDouble();
            return {'status': 'running', 'data': p};
          }
          return null;
        },
      );
      await t.pumpWidget(OpenTuneApp(state: state, referencePlayer: player));
      await t.pumpAndSettle();
      await press(t, 'piano-capture-toggle');
      await t.pump(const Duration(milliseconds: 66));
      await press(t, 'piano-calibrate');
      expect(find.byType(CalibrationPage), findsOneWidget);
      expect(calls.last, 'stop');
      expect(tones.stops, greaterThan(0));
      await press(t, 'cal-capture-toggle');
      await t.pump(const Duration(milliseconds: 66));
      expect(partial, isTrue);
      state.setThemeMode(ThemeMode.dark);
      state.setLocale(const Locale('zh'));
      await t.pumpAndSettle();
      for (var frame = 0; frame < 20; frame++) {
        await t.pump(const Duration(milliseconds: 16));
        expect(t.takeException(), isNull);
      }
      Navigator.of(t.element(find.byType(BackButton))).pop();
      await t.pumpAndSettle();
      expect(find.byType(CalibrationPage), findsNothing);
      expect(calls.last, 'stop');
      await t.pumpWidget(const SizedBox());
      player.dispose();
      state.dispose();
      await t.pump();
    },
  );

  for (final lang in ['zh', 'en']) {
    pianoWidgets(
      'calibration narrow/large text all themes $lang and target table PageStorage',
      (t) async {
        t.view.physicalSize = const Size(320, 640);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() {
          t.view.reset();
          t.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final state = await mechanicalState(calibrated: true)
          ..setLocale(Locale(lang));
        await t.pumpWidget(calibrationHost(state));
        await t.pumpAndSettle();
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          state.setThemeMode(mode);
          await t.pumpAndSettle();
          await press(t, 'calibration-target-table');
          await press(t, 'calibration-target-table');
          expect(t.takeException(), isNull);
          expect(find.byType(ErrorWidget), findsNothing);
        }
        await t.pumpWidget(const SizedBox());
        state.dispose();
        await t.pump();
      },
    );
  }
}
