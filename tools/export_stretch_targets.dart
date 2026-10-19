// Pure Dart production model applied to original native synthetic measurements.
// dart run tools/export_stretch_targets.dart build/m3-dsp/partial-results build/m3-dsp/stretch-targets
import 'dart:convert';
import 'dart:io';

import 'package:opentune_tuner/model/piano_calibration.dart';

void main(List<String> args) {
  if (args.length != 2) {
    throw ArgumentError('native-result-directory output-directory');
  }
  final input = Directory(args[0]),
      output = Directory(args[1])..createSync(recursive: true);
  final summaries = <String, Object>{};
  for (final strong in [false, true]) {
    final samples = <PianoMeasurement>[];
    for (final midi in [33, 45, 57, 69, 81, 93]) {
      final name = strong ? 'fixture-strong-$midi.json' : 'fixture-$midi.json';
      final wire = (jsonDecode(
        File('${input.path}/$name').readAsStringSync(),
      ) as List).cast<num>().map((x) => x.toDouble()).toList();
      samples.add(
        PianoMeasurement(
          id: (midi + (strong ? 128 : 0)).toRadixString(16).padLeft(32, '0'),
          midi: midi,
          captured: DateTime.utc(2026, 10, 18),
          source: 'synthetic_test',
          rate: wire[14].toInt(),
          backend: 'synthetic',
          preset: -1,
          session: 7,
          sequence: wire[2].toInt(),
          endSeconds: wire[3],
          frame: PartialFrame.fromWire(wire),
        ),
      );
    }
    final curve = StretchCurve.solve(440, samples),
        label = strong ? 'strong' : 'guide';
    final time = DateTime.utc(
      2026,
      10,
      18,
    ); // Fixed synthetic metadata, not an asserted recording time.
    final data = PianoCalibration(
      a4: 440,
      kind: 'grand',
      created: time,
      updated: time,
      samples: samples,
      curve: curve,
    );
    File('${output.path}/curve-$label.json')
        .writeAsStringSync('${jsonEncode(data.toJson())}\n');
    final csv = StringBuffer('midi,a4,target_first_hz,b\n');
    for (final point in curve.points) {
      csv.writeln(
        '${point.midi},${curve.a4},${point.firstHz.toStringAsPrecision(17)},${point.b.toStringAsPrecision(17)}',
      );
    }
    File('${output.path}/curve-$label.csv').writeAsStringSync(csv.toString());
    for (var i = 0; i < 20; i++) {
      StretchCurve.solve(440, samples);
    }
    final times = <int>[];
    for (var i = 0; i < 200; i++) {
      final watch = Stopwatch()..start();
      StretchCurve.solve(440, samples);
      watch.stop();
      times.add(watch.elapsedMicroseconds);
    }
    times.sort();
    summaries[label] = {
      'source': 'production native synthetic measurements, not a phone',
      'keys': curve.points.length,
      'low': curve.low,
      'high': curve.high,
      'objective': curve.objective,
      'et_objective': curve.etObjective,
      'low_cents': curve.points.first.cents,
      'high_cents': curve.points.last.cents,
      'warmup_solves': 20,
      'timed_solves': 200,
      'host_p50_solve_us': times[99],
      'host_p95_solve_us': times[189],
    };
  }
  summaries['runtime'] = Platform.version;
  File('${output.path}/summary.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(summaries)}\n',
  );
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(summaries));
}
