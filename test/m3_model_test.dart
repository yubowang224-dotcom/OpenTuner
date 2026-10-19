import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/audio/audio_capture.dart';
import 'package:opentune_tuner/model/piano_calibration.dart';
import 'package:opentune_tuner/model/piano_model.dart';

List<double> partialPacket([int midi = 69]) => (jsonDecode(
  File('test/fixtures/partial/fixture-$midi.json').readAsStringSync(),
) as List).cast<num>().map((x) => x.toDouble()).toList();
PianoMeasurement actualSample(int midi) => PianoMeasurement(
  id: midi.toRadixString(16).padLeft(32, '0'),
  midi: midi,
  captured: DateTime.utc(2026, 10, 18),
  source: 'synthetic_test',
  rate: 48000,
  backend: 'synthetic',
  preset: -1,
  session: 7,
  sequence: 4,
  endSeconds: 1.05,
  frame: AudioSnapshot.decode(partialPacket(midi))!.partialFrame!,
);
PianoMeasurement strongSample(int midi) => PianoMeasurement(
  id: midi.toRadixString(16).padLeft(32, '0'),
  midi: midi,
  captured: DateTime.utc(2026, 10, 18),
  source: 'synthetic_test',
  rate: 48000,
  backend: 'synthetic',
  preset: -1,
  session: 7,
  sequence: 4,
  endSeconds: 1.05,
  frame: AudioSnapshot.decode(
    (jsonDecode(
      File('test/fixtures/partial/fixture-strong-$midi.json')
          .readAsStringSync(),
    ) as List).cast<num>().map((x) => x.toDouble()).toList(),
  )!.partialFrame!,
);
PianoMeasurement modelSample(int midi, double b, {double a4 = 440}) {
  final first = a4 * math.pow(2, (midi - 69) / 12),
      ideal = first / math.sqrt(1 + b);
  return PianoMeasurement(
    id: midi.toRadixString(16).padLeft(32, '0'),
    midi: midi,
    captured: DateTime.utc(2026, 10, 18),
    source: 'synthetic_test',
    rate: 48000,
    backend: 'synthetic',
    preset: -1,
    session: 7,
    sequence: 4,
    endSeconds: 1.05,
    frame: PartialFrame(
      reason: 0,
      idealHz: ideal,
      firstHz: first,
      b: b,
      residual: 0,
      sensitivity: .0000001,
      explained: 1,
      score: 1,
      stable: 4,
      peaks: 8,
      partials: List.generate(8, (i) {
        final n = i + 1;
        return MeasuredPartial(
          n,
          n * ideal * math.sqrt(1 + b * n * n),
          1 / n,
          0,
        );
      }),
    ),
  );
}

List<PianoMeasurement> get actualGuide =>
    [33, 45, 57, 69, 81, 93].map(actualSample).toList();
PianoCalibration calibration({bool curve = true}) {
  final time = DateTime.utc(2026, 10, 18);
  final data = PianoCalibration(
    a4: 440,
    kind: 'grand',
    created: time,
    updated: time,
    samples: actualGuide,
  );
  return curve ? data.generate() : data;
}

PianoCalibration strongCalibration() {
  final time = DateTime.utc(2026, 10, 18);
  return PianoCalibration(
    a4: 440,
    kind: 'grand',
    created: time,
    updated: time,
    samples: [33, 45, 57, 69, 81, 93].map(strongSample).toList(),
  ).generate();
}

List<double> curvePacket() => (jsonDecode(
  File('test/fixtures/partial/curve-offset.json').readAsStringSync(),
) as List).cast<num>().map((x) => x.toDouble()).toList();
void main() {
  test('historical hint provenance requires the exact known version and explicit key', () {
    final original = strongCalibration().toJson();
    for (final version in [null, 'future']) {
      final raw = Map<String, Object?>.from(original)
        ..['hintAlgorithm'] = version;
      expect(
        () => PianoCalibration.decode(raw),
        version == null
            ? throwsFormatException
            : throwsA(isA<CalibrationVersionException>()),
      );
    }
    final empty = calibration(curve: false).toJson();
    expect(PianoCalibration.decode(empty).searchHints, isEmpty);
    expect(
      () => PianoCalibration.decode(
        Map<String, Object?>.from(empty)..['hintAlgorithm'] = 'future',
      ),
      throwsA(isA<CalibrationVersionException>()),
    );
    expect(
      () => PianoCalibration.decode(
        Map<String, Object?>.from(empty)
          ..remove('hintAlgorithm')
          ..['unknown'] = null,
      ),
      throwsFormatException,
    );
    expect(
      () => PianoCalibration.decode(
        Map<String, Object?>.from(empty)..['hintAlgorithm'] = stretchAlgorithm,
      ),
      throwsFormatException,
    );
  });

  test('actual native ABI4 preserves model vs observed first partial and has no fake PCM', () {
    for (final midi in [33, 45, 57, 69, 81, 93]) {
      final r = AudioSnapshot.decode(partialPacket(midi))!;
      expect(r.valid, isTrue);
      expect(r.partialFrame!.ready, isTrue);
      expect(r.partialFrame!.observedFirstHz, isNull);
      expect(r.partialFrame!.firstHz, r.trackedHz);
      expect(r.wave, isEmpty);
      expect(r.spectrum, isEmpty);
      expect(r.values[59], midi);
      expect(
        r.partialFrame!.firstHz,
        closeTo(PianoKey(midi).frequency(440), .01),
      );
      expect(r.partialFrame!.idealHz, lessThan(r.partialFrame!.firstHz));
    }
  });
  test('ABI4 rejects wrong count, target, raw first/source contradiction, quality and nonfinite', () {
    for (final (field, value) in [
      (57, 17.0),
      (59, 20.0),
      (60, 440.0),
      (61, 2.0),
      (48, .5),
      (55, 2.0),
      (10, 0.0),
      (51, -.0001),
      (22, .5),
      (3, double.nan),
    ]) {
      expect(
        AudioSnapshot.decode(partialPacket()..[field] = value),
        isNull,
        reason: 'field $field',
      );
    }
    expect(AudioSnapshot.decode(partialPacket().sublist(0, 80)), isNull);
  });
  test('actual fitted measurements produce bounded modeled targets anchored at first-partial A4', () {
    final curve = StretchCurve.solve(440, actualGuide);
    expect(curve.low, 33);
    expect(curve.high, 93);
    expect(curve.points.length, 61);
    expect(curve.point(21), isNull);
    expect(curve.point(108), isNull);
    expect(curve.point(69)!.firstHz, 440);
    expect(curve.point(69)!.cents, 0);
    expect(curve.points.where((p) => p.measuredB).length, 6);
    expect(curve.point(70)!.measuredB, isFalse);
    expect(curve.objective, lessThan(curve.etObjective));
    expect(curve.point(33)!.cents, lessThan(0));
    expect(curve.point(93)!.cents, greaterThan(0));
    final different = StretchCurve.solve(
      440,
      [33, 45, 57, 69, 81, 93].map((m) => modelSample(m, .001)).toList(),
    );
    expect(
      (different.point(93)!.firstHz - curve.point(93)!.firstHz).abs(),
      greaterThan(.01),
    );
  });
  test('zero B returns ET and every target means first partial, not ideal parameter', () {
    for (final a4 in [400.0, 440.0, 480.0]) {
      final curve = StretchCurve.solve(
        a4,
        [33, 45, 57, 69, 81, 93].map((m) => modelSample(m, 0, a4: a4)).toList(),
      );
      for (final point in curve.points) {
        expect(point.cents, closeTo(0, 1e-8));
        expect(
          point.firstHz,
          closeTo(PianoKey(point.midi).frequency(a4), 1e-9),
        );
      }
    }
    expect(StretchCurve.partialRatio(1, .006), 1);
    expect(StretchCurve.partialRatio(2, .006), greaterThan(2));
  });
  test('insufficient/duplicate/gap/no-anchor inputs cannot create full or partial fake curves', () {
    final samples = actualGuide;
    for (final values in [
      samples.take(4).toList(),
      samples.where((s) => s.midi != 69).toList(),
      [samples[0], ...samples.skip(2)],
      [...samples, samples[0]],
    ]) {
      expect(() => StretchCurve.solve(440, values), throwsFormatException);
    }
  });
  test(
    'stored targets are recomputed and tampering/unknown algorithm rejected',
    () {
      final data = calibration();
      final encoded = jsonEncode(data.toJson());
      final loaded = PianoCalibration.decode(jsonDecode(encoded));
      expect(
        loaded.curve!.points.map((p) => p.firstHz),
        data.curve!.points.map((p) => p.firstHz),
      );
      final raw = jsonDecode(encoded) as Map;
      ((raw['curve'] as Map)['points'] as List)[0]['first'] += 1;
      expect(() => PianoCalibration.decode(raw), throwsFormatException);
      raw['algorithm'] = 'future-v99';
      expect(
        () => PianoCalibration.decode(raw),
        throwsA(isA<CalibrationVersionException>()),
      );
      expect(data.withSamples(data.samples.take(5).toList()).curve, isNull);
    },
  );
  test(
    'a sample from another A4/key cannot be relabeled as this calibration',
    () {
      final time = DateTime.utc(2026, 10, 18);
      expect(
        () => PianoCalibration(
          a4: 480,
          kind: 'grand',
          created: time,
          updated: time,
          samples: [actualSample(69)],
        ),
        throwsFormatException,
      );
    },
  );
}
