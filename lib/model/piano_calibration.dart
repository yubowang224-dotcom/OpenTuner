import 'dart:math' as math;

const partialAlgorithm = 'stiff-partials-v1';
const stretchAlgorithm = 'octave-lsq-v1';

double partialAssociation(double a4, int midi, double? target) {
  if (!a4.isFinite || a4 < 400 || a4 > 480 || midi < 21 || midi > 108) {
    throw ArgumentError('partial association');
  }
  final et = a4 * math.pow(2, (midi - 69) / 12), center = target ?? et;
  if (!center.isFinite ||
      center < 20 ||
      center > 5000 ||
      _cents(center, et).abs() > 150.001) {
    throw ArgumentError('partial association');
  }
  return center;
}

class CalibrationVersionException implements Exception {}

double _cents(double a, double b) => 1200 * math.log(a / b) / math.ln2;
bool _finite(num value) => value.isFinite;
void _require(bool condition) {
  if (!condition) throw const FormatException('calibration data');
}

DateTime calibrationUtc(String text) {
  final value = DateTime.parse(text);
  _require(value.isUtc && value.toIso8601String() == text);
  return value;
}

class MeasuredPartial {
  const MeasuredPartial(this.order, this.hz, this.power, this.residual);
  final int order;
  final double hz, power, residual;
  List<num> toJson() => [order, hz, power, residual];
  static MeasuredPartial decode(Object? value) {
    _require(value is List && value.length == 4);
    final row = value as List;
    _require(row[0] is int && row.skip(1).every((x) => x is num && x.isFinite));
    return MeasuredPartial(
      row[0] as int,
      (row[1] as num).toDouble(),
      (row[2] as num).toDouble(),
      (row[3] as num).toDouble(),
    );
  }
}

/// A fitted first partial is a model estimate even when order 1 was observed.
/// Actual order-1 Hz remains separate, and is absent when the fundamental is weak.
class PartialFrame {
  PartialFrame({
    required this.reason,
    required this.idealHz,
    required this.firstHz,
    required this.b,
    required this.residual,
    required this.sensitivity,
    required this.explained,
    required this.score,
    required this.stable,
    required this.peaks,
    required List<MeasuredPartial> partials,
  }) : partials = List.unmodifiable(partials) {
    _require(
      reason >= 0 &&
          reason <= 10 &&
          stable >= 0 &&
          stable <= 1000000000 &&
          peaks >= 0 &&
          peaks <= 64 &&
          partials.length <= 16,
    );
    _require(
      [
        idealHz,
        firstHz,
        b,
        residual,
        sensitivity,
        explained,
        score,
      ].every(_finite),
    );
    _require(
      idealHz >= 0 &&
          firstHz >= 0 &&
          b >= 0 &&
          b <= .010001 &&
          residual >= 0 &&
          sensitivity >= 0 &&
          explained >= 0 &&
          explained <= 1.000001 &&
          score >= 0 &&
          score <= 1,
    );
    _require(partials.map((p) => p.order).toSet().length == partials.length);
    for (final p in partials) {
      _require(
        p.order >= 1 &&
            p.order <= 16 &&
            p.hz > 0 &&
            p.hz < 40000 &&
            p.power > 0 &&
            p.power <= 1.000001 &&
            [p.hz, p.power, p.residual].every(_finite),
      );
    }
    if (ready) {
      _require(
        score > 0 &&
            (score - explained * math.exp(-residual / 2)).abs() < .000001,
      );
      _require(
        stable >= 4 &&
            partials.length >= 4 &&
            idealHz > 0 &&
            firstHz > 20 &&
            firstHz < 5100 &&
            residual <= 1.5 &&
            sensitivity <= math.max(.000002, b * .4) &&
            explained >= .8,
      );
      _require(_cents(firstHz, idealHz * math.sqrt(1 + b)).abs() < .0001);
      var squared = 0.0, divisor = 0;
      for (final p in partials) {
        divisor = divisor.gcd(p.order);
        final error = _cents(
          p.hz,
          p.order * idealHz * math.sqrt(1 + b * p.order * p.order),
        );
        _require(error.abs() <= 3.0001 && (error - p.residual).abs() < .0001);
        squared += error * error;
      }
      _require(
        divisor == 1 &&
            (math.sqrt(squared / partials.length) - residual).abs() < .0001,
      );
    }
  }
  final int reason, stable, peaks;
  final double idealHz, firstHz, b, residual, sensitivity, explained, score;
  final List<MeasuredPartial> partials;
  bool get ready => reason == 0;
  double? get observedFirstHz =>
      partials.where((p) => p.order == 1).firstOrNull?.hz;
  double get measurementHz => observedFirstHz ?? firstHz;
  Map<String, Object> toJson() => {
    'reason': reason,
    'ideal': idealHz,
    'first': firstHz,
    'b': b,
    'residual': residual,
    'sensitivity': sensitivity,
    'explained': explained,
    'score': score,
    'stable': stable,
    'peaks': peaks,
    'partials': partials.map((p) => p.toJson()).toList(),
  };
  static PartialFrame decode(Object? raw) {
    _require(raw is Map && raw.length == 11);
    final r = raw as Map;
    _require(['reason', 'stable', 'peaks'].every((key) => r[key] is int));
    _require(
      [
        'ideal',
        'first',
        'b',
        'residual',
        'sensitivity',
        'explained',
        'score',
      ].every((key) => r[key] is num && (r[key] as num).isFinite),
    );
    _require(r['partials'] is List);
    double number(String key) => (r[key] as num).toDouble();
    return PartialFrame(
      reason: r['reason'] as int,
      idealHz: number('ideal'),
      firstHz: number('first'),
      b: number('b'),
      residual: number('residual'),
      sensitivity: number('sensitivity'),
      explained: number('explained'),
      score: number('score'),
      stable: r['stable'] as int,
      peaks: r['peaks'] as int,
      partials: (r['partials'] as List).map(MeasuredPartial.decode).toList(),
    );
  }

  static PartialFrame fromWire(List<double> v) {
    _require(
      v.length >= 64 &&
          v[0] == 4 &&
          v[61] == 1 &&
          v[57] >= 0 &&
          v[57] <= 16 &&
          v[57] == v[57].roundToDouble() &&
          v.length == 64 + 4 * v[57],
    );
    _require(
      [48, 55, 56, 59].every((i) => v[i] == v[i].roundToDouble()) &&
          v[59] >= 21 &&
          v[59] <= 108 &&
          v[58] == .75,
    );
    _require(
      v[14] >= 16000 &&
          v[14] <= 96000 &&
          v.sublist(62, 64).every((x) => x == 0),
    );
    final partials = <MeasuredPartial>[];
    for (var i = 64; i < v.length; i += 4) {
      _require(v[i] == v[i].roundToDouble());
      partials.add(MeasuredPartial(v[i].toInt(), v[i + 1], v[i + 2], v[i + 3]));
    }
    final frame = PartialFrame(
      reason: v[48].toInt(),
      idealHz: v[49],
      firstHz: v[50],
      b: v[51],
      residual: v[52],
      sensitivity: v[53],
      explained: v[54],
      score: v[10],
      stable: v[55].toInt(),
      peaks: v[56].toInt(),
      partials: partials,
    );
    _require(
      (frame.observedFirstHz ?? 0) - v[60] == 0 && (v[5] == 2) == frame.ready,
    );
    return frame;
  }
}

class PianoMeasurement {
  PianoMeasurement({
    required this.id,
    required this.midi,
    required this.captured,
    required this.source,
    required this.rate,
    required this.backend,
    required this.preset,
    required this.session,
    required this.sequence,
    required this.endSeconds,
    required this.frame,
    this.associationHz,
    this.associationAlgorithm,
  }) {
    _require(
      RegExp(r'^[a-f0-9]{32}$').hasMatch(id) &&
          midi >= 21 &&
          midi <= 108 &&
          captured.isUtc &&
          frame.ready,
    );
    _require(
      ['android_microphone', 'synthetic_test'].contains(source) &&
          rate >= 16000 &&
          rate <= 96000 &&
          ['AAudio', 'OpenSL ES', 'Oboe', 'synthetic'].contains(backend),
    );
    _require((associationHz == null) == (associationAlgorithm == null));
    if (associationHz != null) {
      _require(
        associationHz!.isFinite &&
            associationHz! >= 20 &&
            associationHz! <= 5000,
      );
      if (associationAlgorithm != stretchAlgorithm) {
        throw CalibrationVersionException();
      }
    }
    _require(
      preset >= -1 &&
          session > 0 &&
          sequence > 0 &&
          endSeconds.isFinite &&
          endSeconds >= .75,
    );
  }
  final String id, source, backend;
  final int midi, rate, preset, session, sequence;
  final double endSeconds;
  final DateTime captured;
  final PartialFrame frame;
  final double? associationHz;
  final String? associationAlgorithm;
  Map<String, Object?> toJson() => {
    'id': id,
    'midi': midi,
    'captured': captured.toIso8601String(),
    'source': source,
    'rate': rate,
    'backend': backend,
    'preset': preset,
    'session': session,
    'sequence': sequence,
    'time': endSeconds,
    'frame': frame.toJson(),
    'associationHz': associationHz,
    'associationAlgorithm': associationAlgorithm,
  };
  static PianoMeasurement decode(Object? value) {
    _require(value is Map && value.length == 13);
    final r = value as Map;
    _require(
      r.containsKey('associationHz') && r.containsKey('associationAlgorithm'),
    );
    if (r['associationAlgorithm'] != null &&
        r['associationAlgorithm'] != stretchAlgorithm) {
      throw CalibrationVersionException();
    }
    _require(r['associationHz'] == null || r['associationHz'] is num);
    _require(
      [
            'id',
            'captured',
            'source',
            'backend',
          ].every((key) => r[key] is String) &&
          [
            'midi',
            'rate',
            'preset',
            'session',
            'sequence',
          ].every((key) => r[key] is int) &&
          r['time'] is num,
    );
    return PianoMeasurement(
      id: r['id'] as String,
      midi: r['midi'] as int,
      captured: calibrationUtc(r['captured'] as String),
      source: r['source'] as String,
      rate: r['rate'] as int,
      backend: r['backend'] as String,
      preset: r['preset'] as int,
      session: r['session'] as int,
      sequence: r['sequence'] as int,
      endSeconds: (r['time'] as num).toDouble(),
      frame: PartialFrame.decode(r['frame']),
      associationHz: (r['associationHz'] as num?)?.toDouble(),
      associationAlgorithm: r['associationAlgorithm'] as String?,
    );
  }
}

class StretchPoint {
  const StretchPoint(
    this.midi,
    this.firstHz,
    this.b,
    this.measuredB,
    this.cents,
  );
  final int midi;
  final double firstHz, b, cents;
  final bool measuredB;
  Map<String, Object> toJson() => {
    'midi': midi,
    'first': firstHz,
    'b': b,
    'bSource': measuredB ? 'measured' : 'interpolated',
    'targetSource': 'model',
    'cents': cents,
  };
}

/// B is interpolated only between measured points. Targets are ALWAYS modeled.
class StretchCurve {
  StretchCurve._(this.a4, this.points, this.objective, this.etObjective);
  final double a4, objective, etObjective;
  final List<StretchPoint> points;
  int get low => points.first.midi;
  int get high => points.last.midi;
  StretchPoint? point(int midi) =>
      midi < low || midi > high ? null : points[midi - low];
  static double partialRatio(int order, double b) =>
      order * math.sqrt((1 + b * order * order) / (1 + b));

  static StretchCurve solve(double a4, List<PianoMeasurement> measurements) {
    _require(a4.isFinite && a4 >= 400 && a4 <= 480);
    final samples = [...measurements]..sort((a, b) => a.midi.compareTo(b.midi));
    _require(
      samples.length >= 5 &&
          samples.length <= 88 &&
          samples.map((s) => s.midi).toSet().length == samples.length,
    );
    _require(
      samples.any((s) => s.midi == 69) &&
          samples.first.midi <= 57 &&
          samples.last.midi >= 81 &&
          samples.last.midi - samples.first.midi >= 36,
    );
    for (var i = 1; i < samples.length; i++) {
      _require(samples[i].midi - samples[i - 1].midi <= 12);
    }
    for (final sample in samples) {
      _require(
        _cents(
              sample.frame.firstHz,
              partialAssociation(a4, sample.midi, sample.associationHz),
            ).abs() <=
            60.001,
      );
    }
    final low = samples.first.midi,
        high = samples.last.midi,
        n = high - low + 1;
    final bs = <double>[], qualities = <double>[], measured = <bool>[];
    for (var midi = low; midi <= high; midi++) {
      final exact = samples.where((s) => s.midi == midi).firstOrNull;
      if (exact != null) {
        bs.add(exact.frame.b);
        qualities.add(exact.frame.score);
        measured.add(true);
      } else {
        final left = samples.lastWhere((s) => s.midi < midi),
            right = samples.firstWhere((s) => s.midi > midi);
        final t = (midi - left.midi) / (right.midi - left.midi);
        bs.add(
          math.max(
            0,
            math.exp(
                  (1 - t) * math.log(left.frame.b + .000001) +
                      t * math.log(right.frame.b + .000001),
                ) -
                .000001,
          ),
        );
        qualities.add(.6 * math.min(left.frame.score, right.frame.score));
        measured.add(false);
      }
    }
    final matrix = List.generate(n, (_) => List<double>.filled(n, 0)),
        rhs = List<double>.filled(n, 0);
    final edges = <(int, int, double, double)>[];
    for (var i = 0; i < n; i++) {
      matrix[i][i] += .002;
      if (i + 1 < n) edges.add((i, i + 1, .05, 0));
      for (final (distance, lowerOrder, upperOrder, weight) in [
        (12, 2, 1, 1.0),
        (12, 4, 2, .25),
        (24, 4, 1, .1),
      ]) {
        final j = i + distance;
        if (j >= n) continue;
        final desired =
            _cents(
              partialRatio(lowerOrder, bs[i]),
              partialRatio(upperOrder, bs[j]),
            ) -
            distance * 100;
        edges.add((i, j, weight * qualities[i] * qualities[j], desired));
      }
    }
    for (final (i, j, weight, desired) in edges) {
      matrix[i][i] += weight;
      matrix[j][j] += weight;
      matrix[i][j] -= weight;
      matrix[j][i] -= weight;
      rhs[i] -= weight * desired;
      rhs[j] += weight * desired;
    }
    final anchor = 69 - low;
    for (var i = 0; i < n; i++) {
      matrix[i][anchor] = 0;
      matrix[anchor][i] = 0;
    }
    matrix[anchor][anchor] = 1;
    rhs[anchor] = 0;
    // Cholesky: the ET prior gives a positive-definite problem; no UI frame loop.
    final l = List.generate(n, (_) => List<double>.filled(n, 0));
    for (var i = 0; i < n; i++) {
      for (var j = 0; j <= i; j++) {
        var value = matrix[i][j];
        for (var k = 0; k < j; k++) {
          value -= l[i][k] * l[j][k];
        }
        if (i == j) {
          _require(value > 0);
          l[i][j] = math.sqrt(value);
        } else {
          l[i][j] = value / l[j][j];
        }
      }
    }
    final y = List<double>.filled(n, 0), x = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      var v = rhs[i];
      for (var k = 0; k < i; k++) {
        v -= l[i][k] * y[k];
      }
      y[i] = v / l[i][i];
    }
    for (var i = n - 1; i >= 0; i--) {
      var v = y[i];
      for (var k = i + 1; k < n; k++) {
        v -= l[k][i] * x[k];
      }
      x[i] = v / l[i][i];
    }
    _require(x.every((v) => v.isFinite && v.abs() < 150));
    double objective(List<double> values) {
      var sum = .002 * values.fold(0.0, (a, b) => a + b * b);
      for (final (i, j, w, d) in edges) {
        sum += w * math.pow(values[j] - values[i] - d, 2);
      }
      return sum;
    }

    final points = List.generate(
      n,
      (i) => StretchPoint(
        low + i,
        a4 * math.pow(2, ((low + i) - 69) / 12 + x[i] / 1200),
        bs[i],
        measured[i],
        x[i],
      ),
    );
    return StretchCurve._(
      a4,
      List.unmodifiable(points),
      objective(x),
      objective(List.filled(n, 0)),
    );
  }

  Map<String, Object> toJson() => {
    'algorithm': stretchAlgorithm,
    'a4': a4,
    'low': low,
    'high': high,
    'points': points.map((p) => p.toJson()).toList(),
  };
  static StretchCurve verified(
    Object? raw,
    double a4,
    List<PianoMeasurement> samples,
  ) {
    _require(raw is Map);
    final r = raw as Map;
    if (r['algorithm'] != stretchAlgorithm) throw CalibrationVersionException();
    final expected = solve(a4, samples);
    _require(
      r.length == 5 &&
          r['a4'] == a4 &&
          r['low'] == expected.low &&
          r['high'] == expected.high &&
          r['points'] is List,
    );
    final points = r['points'] as List;
    _require(points.length == expected.points.length);
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      _require(p is Map && p.length == 6);
      final actual = p as Map, target = expected.points[i].toJson();
      for (final key in target.keys) {
        if (target[key] is double) {
          _require(
            actual[key] is num &&
                (actual[key] as num).isFinite &&
                ((actual[key] as num) - (target[key] as double)).abs() < 1e-8,
          );
        } else {
          _require(actual[key] == target[key]);
        }
      }
    }
    return expected;
  }
}

class PianoCalibration {
  PianoCalibration({
    required this.a4,
    required this.kind,
    required this.created,
    required this.updated,
    required List<PianoMeasurement> samples,
    this.curve,
    Map<int, double>? searchHints,
  }) : samples = List.unmodifiable(samples),
       searchHints = Map.unmodifiable(
         searchHints ??
             {
               for (final point in curve?.points ?? <StretchPoint>[])
                 point.midi: point.firstHz,
             },
       ) {
    _require(
      a4.isFinite &&
          a4 >= 400 &&
          a4 <= 480 &&
          ['upright', 'grand'].contains(kind),
    );
    _require(
      created.isUtc &&
          updated.isUtc &&
          !updated.isBefore(created) &&
          samples.length <= 88,
    );
    _require(
      samples.map((p) => p.midi).toSet().length == samples.length &&
          samples.map((p) => p.id).toSet().length == samples.length,
    );
    for (final sample in samples) {
      _require(
        _cents(
              sample.frame.firstHz,
              partialAssociation(a4, sample.midi, sample.associationHz),
            ).abs() <=
            60.001,
      );
    }
    _require(this.searchHints.length <= 88);
    for (final entry in this.searchHints.entries) {
      partialAssociation(a4, entry.key, entry.value);
    }
    if (curve != null) {
      StretchCurve.verified(curve!.toJson(), a4, samples);
      _require(
        this.searchHints.length == curve!.points.length &&
            curve!.points.every(
              (p) =>
                  this.searchHints[p.midi] != null &&
                  (this.searchHints[p.midi]! - p.firstHz).abs() < 1e-8,
            ),
      );
    }
  }
  final double a4;
  final String kind;
  final DateTime created, updated;
  final List<PianoMeasurement> samples;
  final StretchCurve? curve;

  /// Historical association hints, NEVER active tuning targets without a new curve.
  final Map<int, double> searchHints;
  PianoCalibration withSamples(List<PianoMeasurement> value) =>
      PianoCalibration(
        a4: a4,
        kind: kind,
        created: created,
        updated: DateTime.now().toUtc(),
        samples: value,
        searchHints: searchHints,
      );
  PianoCalibration generate() => PianoCalibration(
    a4: a4,
    kind: kind,
    created: created,
    updated: DateTime.now().toUtc(),
    samples: samples,
    curve: StretchCurve.solve(a4, samples),
  );
  Map<String, Object?> toJson() => {
    'algorithm': partialAlgorithm,
    'a4': a4,
    'kind': kind,
    'created': created.toIso8601String(),
    'updated': updated.toIso8601String(),
    'samples': samples.map((s) => s.toJson()).toList(),
    'curve': curve?.toJson(),
    'hintAlgorithm': searchHints.isEmpty ? null : stretchAlgorithm,
    'searchHints': {
      for (final entry in searchHints.entries)
        entry.key.toString(): entry.value,
    },
  };
  static PianoCalibration decode(Object? value) {
    _require(value is Map);
    final r = value as Map;
    if (r['algorithm'] != partialAlgorithm) throw CalibrationVersionException();
    _require(
      r.length == 9 &&
          r.containsKey('curve') &&
          r.containsKey('hintAlgorithm') &&
          r['a4'] is num &&
          r['kind'] is String &&
          r['created'] is String &&
          r['updated'] is String &&
          r['samples'] is List &&
          r['searchHints'] is Map,
    );
    final rawHints = r['searchHints'] as Map;
    if (r['hintAlgorithm'] != null && r['hintAlgorithm'] != stretchAlgorithm) {
      throw CalibrationVersionException();
    }
    _require(
      rawHints.isEmpty
          ? r['hintAlgorithm'] == null
          : r['hintAlgorithm'] == stretchAlgorithm,
    );
    final hints = <int, double>{};
    for (final entry in rawHints.entries) {
      _require(entry.key is String && entry.value is num);
      final midi = int.tryParse(entry.key as String);
      _require(midi != null && midi.toString() == entry.key);
      hints[midi!] = (entry.value as num).toDouble();
    }
    final a4 = (r['a4'] as num).toDouble(),
        samples = (r['samples'] as List).map(PianoMeasurement.decode).toList();
    return PianoCalibration(
      a4: a4,
      kind: r['kind'] as String,
      created: calibrationUtc(r['created'] as String),
      updated: calibrationUtc(r['updated'] as String),
      samples: samples,
      searchHints: hints,
      curve: r['curve'] == null
          ? null
          : StretchCurve.verified(r['curve'], a4, samples),
    );
  }
}
