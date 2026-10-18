import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// BPM is always quarter notes/minute. 6/8 has six eighth-note pulses, 3+3.
class MetroConfig {
  MetroConfig({
    required this.bpm,
    required this.beats,
    required this.denominator,
    required this.divisions,
    required this.accent,
    this.gain = 100,
  }) {
    if (bpm < 20 ||
        bpm > 300 ||
        beats < 1 ||
        beats > 12 ||
        ![4, 8].contains(denominator) ||
        divisions < 1 ||
        divisions > 4 ||
        gain < 0 ||
        gain > 100) {
      throw ArgumentError('metronome configuration');
    }
  }
  final int bpm, beats, denominator, divisions, gain;
  final bool accent;
  Map<String, Object> get arguments => {
    'bpm': bpm,
    'beats': beats,
    'denominator': denominator,
    'divisions': divisions,
    'accent': accent,
    'gain': gain,
  };
  @override
  bool operator ==(Object other) =>
      other is MetroConfig &&
      bpm == other.bpm &&
      beats == other.beats &&
      denominator == other.denominator &&
      divisions == other.divisions &&
      accent == other.accent &&
      gain == other.gain;
  @override
  int get hashCode =>
      Object.hash(bpm, beats, denominator, divisions, accent, gain);
}

abstract interface class MetroBridge {
  bool get supported;
  Future<Map<Object?, Object?>> start(MetroConfig config, int request);
  Future<Map<Object?, Object?>> update(MetroConfig config, int request);
  Future<Map<Object?, Object?>> snapshot(int request);
  Future<void> stop(int request);
  Future<Map<Object?, Object?>> setPaused(bool paused, int request);
}

class AndroidMetroBridge implements MetroBridge {
  const AndroidMetroBridge();
  static const channel = MethodChannel('org.opentune/audio');
  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<Map<Object?, Object?>> _call(
    String method,
    int request, [
    MetroConfig? c,
  ]) async =>
      await channel.invokeMapMethod<Object?, Object?>(method, {
        'request': request,
        ...?c?.arguments,
      }) ??
      {};
  @override
  Future<Map<Object?, Object?>> start(MetroConfig c, int r) =>
      _call('metroStart', r, c);
  @override
  Future<Map<Object?, Object?>> update(MetroConfig c, int r) =>
      _call('metroUpdate', r, c);
  @override
  Future<Map<Object?, Object?>> snapshot(int r) => _call('metroStatus', r);
  @override
  Future<Map<Object?, Object?>> setPaused(bool paused, int r) async =>
      await channel.invokeMapMethod<Object?, Object?>('metroPause', {
        'request': r,
        'paused': paused,
      }) ??
      {};
  @override
  Future<void> stop(int r) async {
    if (supported) {
      await channel.invokeMethod<void>('metroStop', {'request': r});
    }
  }
}

class MetroSnapshot {
  MetroSnapshot._(
    this.session,
    this.rate,
    this.frames,
    this.beat,
    this.division,
    this.ticks,
    this.config,
    this.pending,
    this.transport,
    this.outputFrames,
  );
  final int session, rate, frames, beat, division, ticks;
  final MetroConfig config;
  final bool pending;
  final int transport, outputFrames;
  static MetroSnapshot? decode(Object? input, int session) {
    if (input is! List ||
        (input.length != 16 && input.length != 17 && input.length != 19) ||
        input.any(
          (v) =>
              v is! num ||
              !v.isFinite ||
              v != v.roundToDouble() ||
              v.abs() > 9007199254740991,
        )) {
      return null;
    }
    final a = input.cast<num>();
    if ((a[0] != 1 && a[0] != 2 && a[0] != 3) ||
        (a[0] == 1 && a.length != 16) ||
        (a[0] == 2 && a.length != 17) ||
        (a[0] == 3 &&
            (a.length != 19 || a[17] < 0 || a[17] > 3 || a[18] < a[4])) ||
        a[1] != session ||
        a[2] != 1 ||
        a[3] < 8000 ||
        a[3] > 192000 ||
        a[4] < 0 ||
        a[7] < 0 ||
        a[13] != 0 ||
        ![0, 1].contains(a[12]) ||
        ![0, 1].contains(a[14]) ||
        a[15] < 0 ||
        a[15] > a[4]) {
      return null;
    }
    try {
      final c = MetroConfig(
        bpm: a[8].toInt(),
        beats: a[9].toInt(),
        denominator: a[10].toInt(),
        divisions: a[11].toInt(),
        accent: a[12] == 1,
        gain: a[0] >= 2 ? a[16].toInt() : 100,
      );
      if (a[5] < -1 ||
          a[5] >= c.beats ||
          a[6] < -1 ||
          a[6] >= c.divisions ||
          (a[5] < 0) != (a[6] < 0)) {
        return null;
      }
      return MetroSnapshot._(
        session,
        a[3].toInt(),
        a[4].toInt(),
        a[5].toInt(),
        a[6].toInt(),
        a[7].toInt(),
        c,
        a[14] == 1,
        a[0] == 3 ? a[17].toInt() : 0,
        a[0] == 3 ? a[18].toInt() : a[4].toInt(),
      );
    } on ArgumentError {
      return null;
    }
  }
}

/// Timer polls submitted sample positions for display. It never schedules sound.
class MetronomePlayer extends ChangeNotifier with WidgetsBindingObserver {
  MetronomePlayer({MetroBridge? bridge, int Function()? monotonicMs})
    : bridge = bridge ?? const AndroidMetroBridge(),
      _now = monotonicMs ?? _elapsed {
    if (!this.bridge.supported) status = 'unsupported';
    WidgetsBinding.instance.addObserver(this);
  }
  static final _clock = Stopwatch()..start();
  static int _elapsed() => _clock.elapsedMilliseconds;
  static int _requests = 0;
  final MetroBridge bridge;
  final int Function() _now;
  String status = 'idle';
  MetroSnapshot? current;
  MetroConfig? _wanted, _sent;
  int _request = 0, _session = 0, _lastAdvance = 0, _lastFrames = -1;
  int? _polling, _updating;
  Timer? _timer;
  bool _disposed = false;
  bool get active =>
      ['starting', 'playing', 'pausing', 'paused', 'resuming'].contains(status);
  bool _wantPaused = false;
  int _transportStart = 0;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start(MetroConfig c) async {
    if (_disposed || !bridge.supported || active) return;
    final r = ++_requests;
    _request = r;
    _wanted = c;
    _wantPaused = false;
    _sent = c;
    current = null;
    status = 'starting';
    _notify();
    try {
      final result = await bridge
          .start(c, r)
          .timeout(const Duration(seconds: 5));
      if (_disposed || _request != r) return;
      if (result['status'] != 'playing' ||
          result['session'] is! num ||
          (result['session'] as num) <= 0) {
        await stop(reason: result['status'] as String? ?? 'error');
        return;
      }
      _session = (result['session'] as num).toInt();
      status = 'playing';
      _lastFrames = -1;
      _lastAdvance = _now();
      _timer = Timer.periodic(
        const Duration(milliseconds: 33),
        (_) => _poll(r),
      );
      _flush(r);
      _notify();
    } catch (_) {
      if (_request == r && !_disposed) await stop(reason: 'error');
    }
  }

  void configure(MetroConfig c) {
    _wanted = c;
    if (active && status != 'starting') _flush(_request);
  }

  Future<void> _flush(int r) async {
    if (_updating == r || _sent == _wanted || _wanted == null) return;
    _updating = r;
    try {
      while (!_disposed &&
          _request == r &&
          active &&
          status != 'starting' &&
          _sent != _wanted) {
        final c = _wanted!;
        final result = await bridge
            .update(c, r)
            .timeout(const Duration(seconds: 1));
        if (_request != r || _disposed) return;
        if (result['status'] != 'accepted') {
          await stop(reason: 'interrupted');
          return;
        }
        _sent = c;
      }
    } catch (_) {
      if (_request == r && !_disposed) await stop(reason: 'error');
    } finally {
      if (_updating == r) _updating = null;
    }
  }

  Future<void> _poll(int r) async {
    if (_disposed || _request != r || _polling == r) return;
    _polling = r;
    try {
      final result = await bridge
          .snapshot(r)
          .timeout(const Duration(milliseconds: 500));
      if (_disposed || _request != r) return;
      if (result['status'] != 'playing') {
        await stop(reason: result['status'] as String? ?? 'error');
        return;
      }
      final next = MetroSnapshot.decode(result['data'], _session);
      if (next == null ||
          next.outputFrames < _lastFrames ||
          next.frames < (current?.frames ?? 0) ||
          next.ticks < (current?.ticks ?? 0)) {
        await stop(reason: 'error');
        return;
      }
      if (next.outputFrames > _lastFrames) {
        _lastAdvance = _now();
        _lastFrames = next.outputFrames;
      }
      if (_now() - _lastAdvance >= 500) {
        await stop(reason: 'stalled');
        return;
      }
      current = next;
      if (_wantPaused && next.transport == 2) {
        status = 'paused';
      } else if (!_wantPaused && next.transport == 0) {
        status = 'playing';
      } else {
        status = _wantPaused ? 'pausing' : 'resuming';
        if (_now() - _transportStart >= 1000) {
          await stop(reason: 'stalled');
          return;
        }
      }
      _notify();
    } catch (_) {
      if (!_disposed && _request == r) await stop(reason: 'error');
    } finally {
      if (_polling == r) _polling = null;
    }
  }

  Future<void> pause() => _setPaused(true);
  Future<void> resume() => _setPaused(false);
  Future<void> _setPaused(bool paused) async {
    if (_disposed || status != (paused ? 'playing' : 'paused')) return;
    final r = _request;
    _wantPaused = paused;
    _transportStart = _now();
    status = paused ? 'pausing' : 'resuming';
    _notify();
    try {
      final result = await bridge
          .setPaused(paused, r)
          .timeout(const Duration(seconds: 1));
      if (_request != r || _disposed) return;
      if (result['status'] != 'accepted') await stop(reason: 'interrupted');
    } catch (_) {
      if (_request == r && !_disposed) await stop(reason: 'error');
    }
  }

  Future<void> stop({String reason = 'idle'}) async {
    final r = _request;
    _request = 0;
    _timer?.cancel();
    _timer = null;
    current = null;
    status = bridge.supported ? reason : 'unsupported';
    _notify();
    if (r != 0) {
      try {
        await bridge.stop(r);
      } catch (_) {
        if (!_disposed && _request == 0) {
          status = 'error';
          _notify();
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ].contains(state)) {
      unawaited(stop(reason: 'background'));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(stop());
    super.dispose();
  }
}

/// Quarter-note taps. Median of the latest four valid intervals; short duplicate
/// taps do not move the anchor. Long/reversed timestamps reset the sequence.
class TapTempo {
  int? _last;
  final _intervals = <int>[];
  int? tap(int milliseconds) {
    final previous = _last;
    if (previous == null) {
      _last = milliseconds;
      return null;
    }
    final dt = milliseconds - previous;
    if (dt <= 0 || dt > 3000) {
      _last = milliseconds;
      _intervals.clear();
      return null;
    }
    if (dt < 200) return null;
    _last = milliseconds;
    _intervals.add(dt);
    if (_intervals.length > 4) _intervals.removeAt(0);
    final sorted = [..._intervals]..sort();
    final n = sorted.length;
    final median = n.isOdd
        ? sorted[n ~/ 2].toDouble()
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
    return (60000 / median).round().clamp(20, 300);
  }
}
