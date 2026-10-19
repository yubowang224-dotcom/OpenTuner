import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/app.dart';
import 'package:opentune_tuner/audio/audio_capture.dart';
import 'package:opentune_tuner/audio/calibration_page.dart';
import 'package:opentune_tuner/audio/reference_player.dart';
import 'package:opentune_tuner/model/piano_model.dart';
import 'package:opentune_tuner/model/piano_calibration.dart';
import 'package:opentune_tuner/widgets/tuning_gauge.dart';

import 'audio_test.dart' show packet;
import 'm2_ui_test.dart' show pianoWidgets;
import 'm3_model_test.dart' show curvePacket, strongCalibration;
import 'm3_ui_test.dart' show mechanicalState, press, reveal;
import 'stage25_test.dart' show ToneFixture;

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  pianoWidgets(
    'already-stretched >60c key resamples, saves historical hints, reloads and regenerates',
    (t) async {
      final state = await mechanicalState();
      await state.profiles.saveCalibration(
        state.profiles.selected!.id,
        strongCalibration(),
        state.profiles.archive.revision,
      );
      state.selectPianoNote('A1');
      state.applyPianoCurve(state.profiles.selected!.id);
      final center = state.pianoTargetHz;
      var session = 7, seq = 0;
      final starts = <Map>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        (call) async {
          if (call.method == 'start') {
            starts.add(Map.of(call.arguments as Map));
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
      final ref = ReferencePlayer(bridge: ToneFixture());
      await t.pumpWidget(OpenTuneApp(state: state, referencePlayer: ref));
      await t.pumpAndSettle();
      await press(t, 'piano-calibrate');
      expect(find.byType(CalibrationPage), findsOneWidget);
      expect(
        t.widget<SwitchListTile>(await reveal(t, 'cal-use-hints')).value,
        isTrue,
      );
      await press(t, 'cal-capture-toggle');
      await t.pump(const Duration(milliseconds: 66));
      expect(starts.last['targetHz'], center);
      await press(t, 'cal-accept');
      expect(state.pianoCurve, isNull);
      await press(t, 'cal-save');
      var saved = state.profiles.selected!.calibration!;
      expect(saved.curve, isNull);
      expect(saved.searchHints.length, 61);
      final measured = saved.samples.firstWhere((p) => p.midi == 33);
      expect(measured.associationHz, center);
      expect(measured.associationAlgorithm, stretchAlgorithm);
      expect(frequencyCents(measured.frame.firstHz, 55), lessThan(-60));
      Navigator.of(t.element(find.byType(BackButton))).pop();
      await t.pumpAndSettle();
      await state.profiles.load();
      await t.pumpAndSettle();
      await press(t, 'piano-calibrate');
      expect(
        t.widget<SwitchListTile>(await reveal(t, 'cal-use-hints')).value,
        isFalse,
      );
      await press(t, 'cal-capture-toggle');
      await t.pump(const Duration(milliseconds: 66));
      expect(starts.last.containsKey('targetHz'), isFalse);
      expect(
        t.widget<FilledButton>(await reveal(t, 'cal-accept')).onPressed,
        isNull,
      );
      await press(t, 'cal-use-hints');
      await press(t, 'cal-capture-toggle');
      await t.pump(const Duration(milliseconds: 66));
      expect(starts.last['targetHz'], center);
      await press(t, 'cal-accept');
      await press(t, 'cal-generate');
      await press(t, 'cal-apply');
      expect(find.byType(CalibrationPage), findsNothing);
      expect(state.pianoCurve, isNotNull);
      saved = state.profiles.selected!.calibration!;
      expect(saved.curve!.point(33), isNotNull);
      await t.pumpWidget(const SizedBox());
      ref.dispose();
      state.dispose();
      await t.pump();
    },
  );
  pianoWidgets(
    'production native nonharmonic PCM >60c curve flows to actual target/gauge/reference',
    (t) async {
      final state = await mechanicalState();
      await state.profiles.saveCalibration(
        state.profiles.selected!.id,
        strongCalibration(),
        state.profiles.archive.revision,
      );
      state.selectPianoNote('A1');
      expect(state.applyPianoCurve(state.profiles.selected!.id), isTrue);
      final target = state.pianoTargetHz;
      expect(frequencyCents(target, 55), lessThan(-60));
      final tones = ToneFixture(),
          player = ReferencePlayer(bridge: ToneFixture());
      player.dispose();
      final reference = ReferencePlayer(bridge: tones);
      var session = 7, seq = 0;
      final starts = <Map>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        (call) async {
          if (call.method == 'start') {
            starts.add(Map.of(call.arguments as Map));
            return {'status': 'running', 'session': ++session};
          }
          if (call.method == 'snapshot') {
            final p = curvePacket()
              ..[1] = session.toDouble()
              ..[2] = (++seq).toDouble();
            return {'status': 'running', 'data': p};
          }
          return null;
        },
      );
      await t.pumpWidget(OpenTuneApp(state: state, referencePlayer: reference));
      await t.pumpAndSettle();
      await press(t, 'piano-capture-toggle');
      await t.pump(const Duration(milliseconds: 66));
      expect(starts.single, {
        'referenceHz': 440.0,
        'mode': 'partial',
        'midi': 33,
        'targetHz': target,
      });
      var gauge = t.widget<TuningGauge>(find.byType(TuningGauge));
      expect(gauge.targetNote, 'A1');
      expect(gauge.reading.note, 'G#1');
      expect(gauge.reading.cents, closeTo(17, .002));
      expect(gauge.detectedCaption, 'Nearest ET note (measured)');
      expect(gauge.referenceCaption, contains('Selected target key'));
      state.setMinimal(true);
      state.setThemeMode(ThemeMode.dark);
      state.setLocale(const Locale('zh'));
      await t.pumpAndSettle();
      expect(starts.length, 1);
      gauge = t.widget<TuningGauge>(find.byType(TuningGauge));
      expect(gauge.reading.cents, closeTo(17, .002));
      expect(gauge.targetNote, 'A1');
      state.setMinimal(false);
      await t.pumpAndSettle();
      await press(t, 'reference-toggle');
      expect(tones.frequencies.single, target);
      expect(tones.timbres.single, ReferenceTimbre.sine);
      expect(
        t.widget<TuningGauge>(find.byType(TuningGauge)).reading.isValid,
        isFalse,
      );
      state.setReferenceHz(442);
      await t.pumpAndSettle();
      expect(state.pianoCurve, isNull);
      expect(reference.active, isFalse);
      expect(state.pianoTargetHz, PianoKey(33).frequency(442));
      await t.pumpWidget(const SizedBox());
      reference.dispose();
      state.dispose();
      await t.pump();
    },
  );
  pianoWidgets(
    'outside measured support uses explicit ET, never an extrapolated target or partial mode',
    (t) async {
      final state = await mechanicalState();
      await state.profiles.saveCalibration(
        state.profiles.selected!.id,
        strongCalibration(),
        state.profiles.archive.revision,
      );
      state.applyPianoCurve(state.profiles.selected!.id);
      state.selectPianoNote('A0');
      expect(state.pianoCurve, isNotNull);
      expect(state.pianoPartialMeasurement, isFalse);
      expect(state.pianoTargetHz, 27.5);
      final starts = <Map>[];
      var seq = 0;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        (call) async {
          if (call.method == 'start') {
            starts.add(Map.of(call.arguments as Map));
            return {'status': 'running', 'session': 7};
          }
          if (call.method == 'snapshot') {
            return {'status': 'running', 'data': packet(sequence: ++seq)};
          }
          return null;
        },
      );
      await t.pumpWidget(OpenTuneApp(state: state));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Outside the calibrated range'),
        findsOneWidget,
      );
      await press(t, 'piano-capture-toggle');
      await t.pump(const Duration(milliseconds: 33));
      expect(starts.single, {'referenceHz': 440.0, 'mode': 'piano'});
      state.setPianoKind(PianoKind.digital);
      await t.pumpAndSettle();
      expect(state.pianoCurve, isNull);
      await t.pumpWidget(const SizedBox());
      state.dispose();
      await t.pump();
    },
  );
  test('association center validation does not widen the sampling acceptance range', () {
    for (final hz in [-1.0, 1.0, 5001.0, double.nan]) {
      expect(
        () => AudioCapture(partialMidi: 69, associationHz: hz),
        throwsArgumentError,
      );
    }
    expect(() => AudioCapture(associationHz: 440), throwsArgumentError);
  });
}
