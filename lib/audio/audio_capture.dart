import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../model/tuning_reference.dart';
import '../model/piano_calibration.dart';

enum CaptureStatus {
  idle,
  starting,
  running,
  unsupported,
  permissionDenied,
  permissionSettings,
  permissionRevoked,
  background,
  deviceChanged,
  silenced,
  interrupted,
  stalled,
  error,
}

/// A bounded copy of one worker result. Zero Hz is never a valid measurement.
class AudioSnapshot {
  AudioSnapshot._(this.values, [this.partialFrame]);
  final List<double> values;
  final PartialFrame? partialFrame;
  static AudioSnapshot? decode(Object? input) {
    if (input is! List || input.length < 30 || input.length > 1072) return null;
    if (input.any((v) => v is! num || !v.toDouble().isFinite)) return null;
    final v = input
        .cast<num>()
        .map((e) => e.toDouble())
        .toList(growable: false);
    if (v[0] == 4) {
      try {
        if (v.length < 64 ||
            v[1] <= 0 ||
            v[2] < 0 ||
            v[3] < 0 ||
            v[4] < 0 ||
            [
              1,
              2,
              5,
              14,
              15,
              16,
              22,
            ].any((i) => v[i] != v[i].roundToDouble()) ||
            v[22] < 0 ||
            v[5] < 0 ||
            v[5] > 3 ||
            v[15] != 1 ||
            v[16] != 2 ||
            v[24] != 0 ||
            v[26] != 0 ||
            v.sublist(42, 48).any((x) => x != 0)) {
          return null;
        }
        final partial = PartialFrame.fromWire(v);
        if (partial.ready &&
            (v[6] <= 0 ||
                v[7] <= 0 ||
                v[8] < 0 ||
                v[8] > 127 ||
                v[8] != v[8].roundToDouble() ||
                (v[7] - partial.measurementHz).abs() > 1e-8)) {
          return null;
        }
        return AudioSnapshot._(List.unmodifiable(v), partial);
      } catch (_) {
        return null;
      }
    }
    if ((v[0] != 1 && v[0] != 2 && v[0] != 3) ||
        v[1] <= 0 ||
        v[2] < 0 ||
        v[4] < 0 ||
        v[1] != v[1].roundToDouble() ||
        v[2] != v[2].roundToDouble() ||
        v[5] != v[5].roundToDouble() ||
        v[5] < 0 ||
        v[5] > 3 ||
        v[14] < 8000 ||
        v[14] > 192000 ||
        v[15] != 1 ||
        v[16] != 2 ||
        v[10] < 0 ||
        v[10] > 1 ||
        v[26] < 0 ||
        v[26] > 512 ||
        v[26] != v[26].roundToDouble()) {
      return null;
    }
    final header = v[0] == 3
        ? 48
        : v[0] == 2
        ? 42
        : 30;
    if (v.length < header) return null;
    final waveCount = v[0] == 3 ? v[42].toInt() : 256;
    if (v[0] == 3 &&
        v.length == header &&
        (v[26] != 0 || v[24] != 0 || v.sublist(42, 48).any((x) => x != 0))) {
      return null;
    }
    if (v[0] == 3 &&
        (v[42] != v[42].roundToDouble() ||
            waveCount < 0 ||
            waveCount > 512 ||
            v[45] != 0 && v[45] != 1 ||
            v[47] < 0 ||
            v.length > header &&
                (waveCount < 2 ||
                    v[26] < 1 ||
                    v[43] <= 0 ||
                    v[46] < 1 ||
                    v[46] > 8 ||
                    v[46] != v[46].roundToDouble() ||
                    (v[43] - v[46] / v[14]).abs() > 1e-9 ||
                    (v[24] - (waveCount - 1) * v[43]).abs() > 1e-9 ||
                    v[44] < 0 ||
                    v[44] + v[24] > v[3] + 1e-9))) {
      return null;
    }
    if (v.length != header && v.length != header + waveCount + v[26].toInt()) {
      return null;
    }
    if (v[0] >= 2 &&
        (v[31] != 0 && v[31] != 1 ||
            v[34] < 0 ||
            v[34] > 1 ||
            v[35] < 0 ||
            v[35] > 1 ||
            v[36] < 0 ||
            v[36] > 6 ||
            v[39] < 0 ||
            v[39] > 5 ||
            v[39] != v[39].roundToDouble())) {
      return null;
    }
    if (v[5] == 2 &&
        (v[6] <= 0 ||
            v[7] <= 0 ||
            v[8] < 0 ||
            v[8] > 127 ||
            v[8] != v[8].roundToDouble())) {
      return null;
    }
    if (v.length > header && (v[24] <= 0 || (v[26] > 0 && v[25] <= 0))) {
      return null;
    }
    return AudioSnapshot._(List.unmodifiable(v));
  }

  int get session => values[1].toInt();
  int get sequence => values[2].toInt();
  double get ageMs => values[4];
  bool get valid => values[5] == 2 && ageMs <= 250;
  bool get silent => values[5] == 0;
  bool get clipped => values[5] == 3;
  double? get rawHz => values[6] > 0 ? values[6] : null;
  double? get trackedHz => valid ? values[7] : null;
  double? get cents => valid ? values[9] : null;
  double get score => values[10];
  double get dbfs => values[11];
  double get computeMs => values[13];
  int get sampleRate => values[14].toInt();
  String get backend => values[17] == 2
      ? 'AAudio'
      : values[17] == 1
      ? 'OpenSL ES'
      : 'Oboe';
  String? get note {
    if (!valid) return null;
    final midi = values[8].toInt();
    return '${const ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'][midi % 12]}${midi ~/ 12 - 1}';
  }

  int get header => values[0] == 4
      ? 64
      : values[0] == 3
      ? 48
      : values[0] == 2
      ? 42
      : 30;
  bool get sampledWave => values[0] == 3;
  int get waveCount => values[0] == 4
      ? 0
      : sampledWave
      ? values[42].toInt()
      : 256;
  double get waveStepMs => sampledWave ? values[43] * 1000 : 0;
  bool get waveTriggered => sampledWave && values[45] == 1;
  double get waveComputeMs => sampledWave ? values[47] : 0;
  double get waveStartMs => sampledWave ? values[44] * 1000 : 0;
  double get waveEndMs => waveStartMs + waveMs;
  List<double> get wave => values[0] != 4 && values.length > header
      ? values.sublist(header, header + waveCount)
      : const [];
  List<double> get spectrum =>
      values[0] != 4 && values.length > header + waveCount
      ? values.sublist(header + waveCount)
      : const [];
  bool get noiseKnown => values[0] >= 2 && values[31] == 1;
  double? get noiseFloorDb => noiseKnown ? values[30] : null;
  double? get levelMarginDb => noiseKnown ? values[32] : null;
  double? get centroidHz => values[0] >= 2 ? values[33] : null;
  double? get harmonicRatio => values[0] >= 2 ? values[34] : null;
  int? get candidateCount => values[0] >= 2 ? values[36].toInt() : null;
  String get trackerState => values[0] >= 2
      ? const [
          'idle',
          'candidate',
          'tracking',
          'switching',
          'uncertain',
          'lost',
        ][values[39].toInt()]
      : 'v1';
  double get waveMs => values[24] * 1000;
  double get binHz => values[25];
  int get dropped => values[21].toInt();
}

/// Control and snapshot transport; never accepts generated PCM in production.
abstract interface class AudioBridge {
  bool get supported;
  Future<Map<Object?, Object?>> start(double referenceHz);
  Future<void> stop();
  Future<Map<Object?, Object?>> snapshot(bool details);
  Future<void> openSettings();
}

class AndroidAudioBridge implements AudioBridge {
  const AndroidAudioBridge({
    this.piano = false,
    this.partialMidi,
    this.associationHz,
  });
  final bool piano;
  final int? partialMidi;
  final double? associationHz;
  static const channel = MethodChannel('org.opentune/audio');
  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<Map<Object?, Object?>> _call(String method, [Object? args]) async =>
      await channel.invokeMapMethod<Object?, Object?>(method, args) ?? {};
  @override
  Future<Map<Object?, Object?>> start(double referenceHz) {
    if (partialMidi != null) {
      partialAssociation(referenceHz, partialMidi!, associationHz);
    }
    return _call('start', {
      'referenceHz': referenceHz,
      if (partialMidi != null) ...{
        'mode': 'partial',
        'midi': partialMidi,
        if (associationHz != null) 'targetHz': associationHz,
      } else if (piano)
        'mode': 'piano',
    });
  }

  @override
  Future<void> stop() async {
    if (supported) await channel.invokeMethod<void>('stop');
  }

  @override
  Future<Map<Object?, Object?>> snapshot(bool details) =>
      _call('snapshot', {'details': details});
  @override
  Future<void> openSettings() async {
    if (supported) await channel.invokeMethod<void>('settings');
  }
}

class AudioCapture extends ChangeNotifier {
  AudioCapture({
    AudioBridge? bridge,
    bool piano = false,
    this.partialMidi,
    this.associationHz,
    this.referenceHz = defaultReferenceHz,
    int Function()? monotonicMs,
  }) : bridge =
           bridge ??
           AndroidAudioBridge(
             piano: piano,
             partialMidi: partialMidi,
             associationHz: associationHz,
           ),
       _testClock = monotonicMs {
    if (partialMidi != null) {
      partialAssociation(referenceHz, partialMidi!, associationHz);
    }
    if (partialMidi == null && associationHz != null) {
      throw ArgumentError('association requires partial mode');
    }
    if (!this.bridge.supported) status = CaptureStatus.unsupported;
  }
  final AudioBridge bridge;
  final double referenceHz;
  final int? partialMidi;
  final double? associationHz;
  final int Function()? _testClock;
  final Stopwatch _clock = Stopwatch()..start();
  int get _now => _testClock?.call() ?? _clock.elapsedMilliseconds;
  CaptureStatus status = CaptureStatus.idle;
  AudioSnapshot? current;
  double? _displayHz;
  int? _displayMidi;
  bool _referenceLocked = false;
  int? _pendingReferenceMidi;
  int _pendingReferenceSince = 0, _pendingReferenceFrames = 0;
  bool get referenceLocked => _referenceLocked;
  int? get referenceMidi => _displayMidi;
  String? get referenceNote =>
      _displayMidi == null ? null : _noteName(_displayMidi!);
  static String _noteName(int midi) =>
      '${const ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'][midi % 12]}${midi ~/ 12 - 1}';
  void _clearReferenceCandidate() {
    _pendingReferenceMidi = null;
    _pendingReferenceFrames = 0;
  }

  void _resetReference() {
    _referenceLocked = false;
    _displayMidi = null;
    _clearReferenceCandidate();
  }

  /// Session-only reference lock. The observation and tracked Hz are untouched.
  bool lockReference() {
    if (_referenceLocked || current?.valid != true || _displayMidi == null) {
      return false;
    }
    _referenceLocked = true;
    _clearReferenceCandidate();
    _notify();
    return true;
  }

  void unlockReference() {
    if (!_referenceLocked) return;
    _referenceLocked = false;
    _clearReferenceCandidate();
    if (current?.valid == true) {
      _displayMidi = current!.values[8].toInt();
      _displayHz = current!.trackedHz;
      _displayAt = _now;
      _visualCents = displayCents;
    }
    _notify();
  }

  int _displayAt = -1000, _lastValidAt = -1000;
  double? _visualCents;
  double? get displayHz => current?.valid == true ? _displayHz : null;
  // Backwards-compatible presentation name: this is the selected reference,
  // not a replacement for current.note (the measured nearest note).
  String? get displayNote => current?.valid == true ? referenceNote : null;

  double? get displayCents => current?.valid == true && _displayMidi != null
      ? frequencyCents(current!.trackedHz!, referenceHz) -
            100 * (_displayMidi! - 69)
      : null;
  // Invalid readings stay visibly invalid; only the dimmed pointer may hold
  // briefly. No held Hz or note is presented as a fresh observation.
  double? get visualCents => current?.valid == true
      ? displayCents
      : _now - _lastValidAt <= 200
      ? _visualCents
      : null;
  void _acceptDisplay(AudioSnapshot frame) {
    if (!frame.valid) {
      _clearReferenceCandidate();
      return;
    }
    final nearest = frame.values[8].toInt();
    final pitch = frequencyCents(frame.trackedHz!, referenceHz);
    bool change = false;
    if (_displayMidi == null) {
      _displayMidi = nearest;
      change = true;
    } else if (!_referenceLocked) {
      final distance = (pitch - 100 * (_displayMidi! - 69)).abs();
      if (distance <= 55 || nearest == _displayMidi) {
        _clearReferenceCandidate();
      } else if (distance >= 85) {
        // Clear note changes need no additional display confirmation.
        _displayMidi = nearest;
        change = true;
        _clearReferenceCandidate();
      } else {
        if (_pendingReferenceMidi != nearest) {
          _pendingReferenceMidi = nearest;
          _pendingReferenceSince = _now;
          _pendingReferenceFrames = 1;
        } else {
          ++_pendingReferenceFrames;
        }
        // Only fresh accepted snapshots can advance this short UI confirmation.
        if (_pendingReferenceFrames >= 2 &&
            _now - _pendingReferenceSince >= 60) {
          _displayMidi = nearest;
          change = true;
          _clearReferenceCandidate();
        }
      }
    }
    if (change || _now - _displayAt >= 125 || _displayHz == null) {
      _displayHz = frame.trackedHz;
      _displayAt = _now;
    }
    _lastValidAt = _now;
    _visualCents = displayCents;
  }

  String diagnostic = '';
  bool details = false;
  int _generation = 0, _session = 0, _sequence = -1;
  bool _disposed = false, _polling = false;
  Timer? _timer;
  int _lastDataMs = 0;
  int _discontinuities = 0;
  int? _recoveryDeadline;
  bool get active =>
      status == CaptureStatus.running || status == CaptureStatus.starting;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (_disposed || active || !bridge.supported) return;
    final token = ++_generation;
    current = null;
    _displayHz = null;
    _resetReference();
    _visualCents = null;
    _lastValidAt = -1000;
    diagnostic = '';
    _discontinuities = 0;
    _recoveryDeadline = null;
    status = CaptureStatus.starting;
    _notify();
    try {
      final response = await bridge.start(referenceHz);
      if (_disposed || token != _generation) return;
      status = _status(response['status']);
      if (status == CaptureStatus.running) {
        final session = response['session'];
        if (session is! num || session <= 0) {
          throw const FormatException('session');
        }
        _session = session.toInt();
        _sequence = -1;
        _lastDataMs = _now;
        _timer = Timer.periodic(
          const Duration(milliseconds: 33),
          (_) => _poll(token),
        );
      } else {
        diagnostic = '${response['error'] ?? ''}';
      }
    } catch (e) {
      if (token == _generation && !_disposed) {
        diagnostic = e.runtimeType.toString();
        await stop(CaptureStatus.error);
      }
    }
    _notify();
  }

  Future<void> _poll(int token) async {
    if (token != _generation || _disposed) return;
    // Independent of transport completion: a hung call or stale-session reply
    // cannot keep the previous valid pitch on screen indefinitely.
    if (_now - _lastDataMs > 250 && current != null) {
      current = null;
      _clearReferenceCandidate();
      _notify();
    }
    if (_recoveryDeadline != null && _now > _recoveryDeadline! ||
        _now - _lastDataMs >
            (_sequence < 0 && partialMidi != null
                ? 1500
                : _recoveryDeadline != null
                ? 1200
                : 500)) {
      await stop(CaptureStatus.stalled);
      return;
    }
    if (_polling) return;
    _polling = true;
    try {
      final response = await bridge
          .snapshot(details)
          .timeout(const Duration(milliseconds: 250));
      if (_disposed || token != _generation) return;
      final next = _status(response['status']);
      if (next != CaptureStatus.running) {
        await stop(next);
        return;
      }
      final frame = AudioSnapshot.decode(response['data']);
      if (frame == null) throw const FormatException('snapshot ABI');
      if (frame.session != _session) {
        return; // stale session can never replace current
      }
      if ((partialMidi != null) != (frame.partialFrame != null) ||
          partialMidi != null && frame.values[59] != partialMidi) {
        throw const FormatException('analysis mode/target');
      }
      if (partialMidi != null &&
          frame.partialFrame!.ready &&
          frequencyCents(
                frame.partialFrame!.firstHz,
                (associationHz ??
                    referenceHz * math.pow(2, (partialMidi! - 69) / 12)),
              ).abs() >
              60.001) {
        throw const FormatException('partial frequency association');
      }
      if (frame.sequence > _sequence &&
          frame.sequence > 0 &&
          frame.ageMs <= 250) {
        _sequence = frame.sequence;
        _lastDataMs = _now;
        if (partialMidi != null) {
          final gaps = frame.values[22].toInt();
          if (gaps > _discontinuities && frame.values[3] == 0) {
            _recoveryDeadline ??= _now + 1200;
          }
          _discontinuities = gaps;
          if (frame.values[3] > 0) _recoveryDeadline = null;
        }
        current = frame;
        _acceptDisplay(frame);
        _notify();
      }
      if (frame.sequence > 0 &&
          frame.ageMs > 250 &&
          !(_recoveryDeadline != null &&
              partialMidi != null &&
              frame.values[3] == 0)) {
        await stop(CaptureStatus.stalled);
      }
    } catch (e) {
      if (!_disposed && token == _generation) {
        diagnostic = e.runtimeType.toString();
        await stop(CaptureStatus.error);
      }
    } finally {
      _polling = false;
    }
  }

  void setDetails(bool value) {
    details = value;
    _notify();
  }

  Future<void> stop([CaptureStatus reason = CaptureStatus.idle]) async {
    _recoveryDeadline = null;
    ++_generation;
    _timer?.cancel();
    _timer = null;
    current = null;
    _displayHz = null;
    _resetReference();
    _visualCents = null;
    _lastValidAt = -1000;
    status = bridge.supported ? reason : CaptureStatus.unsupported;
    _notify();
    try {
      await bridge.stop();
    } catch (e) {
      diagnostic = e.runtimeType.toString();
    }
  }

  Future<void> openSettings() => bridge.openSettings();
  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    _timer = null;
    current = null;
    _resetReference();
    unawaited(bridge.stop().catchError((Object _) {}));
    super.dispose();
  }

  static CaptureStatus _status(Object? value) => switch (value) {
    'running' => CaptureStatus.running,
    'idle' => CaptureStatus.idle,
    'background' => CaptureStatus.background,
    'permission_denied' => CaptureStatus.permissionDenied,
    'permission_settings' => CaptureStatus.permissionSettings,
    'permission_revoked' => CaptureStatus.permissionRevoked,
    'device_changed' => CaptureStatus.deviceChanged,
    'silenced' => CaptureStatus.silenced,
    'interrupted' => CaptureStatus.interrupted,
    _ => CaptureStatus.error,
  };
}

/// Frequency/target arithmetic shared with future target-constrained modes.
double frequencyCents(double measured, double target) {
  if (!measured.isFinite || !target.isFinite || measured <= 0 || target <= 0) {
    throw ArgumentError('positive frequency');
  }
  return 1200 * math.log(measured / target) / math.ln2;
}
