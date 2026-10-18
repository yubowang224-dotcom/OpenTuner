import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum ReferenceTimbre { sine, guitar }

abstract interface class ReferenceBridge {
  bool get supported;
  Future<Map<Object?, Object?>> start(
    double hz, {
    ReferenceTimbre timbre = ReferenceTimbre.sine,
    double gain = 1,
  });
  Future<void> stop();
  Future<Map<Object?, Object?>> status();
}

class AndroidReferenceBridge implements ReferenceBridge {
  const AndroidReferenceBridge();
  static const channel = MethodChannel('org.opentune/audio');
  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  Future<Map<Object?, Object?>> start(
    double hz, {
    ReferenceTimbre timbre = ReferenceTimbre.sine,
    double gain = 1,
  }) async =>
      await channel.invokeMapMethod<Object?, Object?>('toneStart', {
        'hz': hz,
        'voice': timbre.index,
        'gain': gain,
      }) ??
      {};
  @override
  Future<void> stop() async {
    if (supported) await channel.invokeMethod<void>('toneStop');
  }

  @override
  Future<Map<Object?, Object?>> status() async =>
      await channel.invokeMapMethod<Object?, Object?>('toneStatus') ?? {};
}

enum ReferenceStatus { idle, starting, playing, unsupported, error }

class ReferencePlayer extends ChangeNotifier with WidgetsBindingObserver {
  ReferencePlayer({ReferenceBridge? bridge})
    : bridge = bridge ?? const AndroidReferenceBridge() {
    if (!this.bridge.supported) state = ReferenceStatus.unsupported;
    WidgetsBinding.instance.addObserver(this);
  }
  final ReferenceBridge bridge;
  ReferenceStatus state = ReferenceStatus.idle;
  String? note;
  double? hz;
  int sampleRate = 0;
  int _generation = 0;
  bool _disposed = false, _polling = false;
  Timer? _timer;
  bool get active =>
      state == ReferenceStatus.playing || state == ReferenceStatus.starting;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> play(
    String name,
    double frequency, {
    ReferenceTimbre timbre = ReferenceTimbre.sine,
    double gain = 1,
  }) async {
    if (_disposed || !bridge.supported) return;
    if (!frequency.isFinite ||
        frequency < 20 ||
        frequency > 5000 ||
        !gain.isFinite ||
        gain < 0 ||
        gain > 1) {
      throw ArgumentError('tone frequency');
    }
    final token = ++_generation;
    _timer?.cancel();
    note = name;
    hz = frequency;
    state = ReferenceStatus.starting;
    _notify();
    try {
      final result = await bridge.start(frequency, timbre: timbre, gain: gain);
      if (_disposed || token != _generation) return;
      state = result['status'] == 'playing'
          ? ReferenceStatus.playing
          : ReferenceStatus.error;
      sampleRate = (result['rate'] as num?)?.toInt() ?? 0;
      if (state == ReferenceStatus.playing) {
        _timer = Timer.periodic(
          const Duration(milliseconds: 100),
          (_) => _poll(token),
        );
      }
    } catch (_) {
      if (!_disposed && token == _generation) {
        state = ReferenceStatus.error;
        unawaited(bridge.stop().catchError((Object _) {}));
      }
    }
    _notify();
  }

  Future<void> _poll(int token) async {
    if (_polling || _disposed || token != _generation) return;
    _polling = true;
    try {
      final response = await bridge.status().timeout(
        const Duration(milliseconds: 500),
      );
      if (_disposed || token != _generation) return;
      if (response['status'] != 'playing') {
        await stop(error: response['status'] == 'error');
      }
    } catch (_) {
      if (!_disposed && token == _generation) await stop(error: true);
    } finally {
      _polling = false;
    }
  }

  Future<void> stop({bool error = false}) async {
    final token = ++_generation;
    _timer?.cancel();
    _timer = null;
    state = !bridge.supported
        ? ReferenceStatus.unsupported
        : error
        ? ReferenceStatus.error
        : ReferenceStatus.idle;
    _notify();
    try {
      await bridge.stop();
    } catch (_) {
      if (!_disposed && token == _generation) {
        state = ReferenceStatus.error;
        _notify();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(stop());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(bridge.stop().catchError((Object _) {}));
    super.dispose();
  }
}

/// Equal-temperament note conversion. Presets/individual curves supply Hz to
/// the player; target mappings are never hardcoded inside the synthesizer.
double noteFrequency(String note, double referenceHz) {
  const pitchClasses = {
    'C': 0,
    'D': 2,
    'E': 4,
    'F': 5,
    'G': 7,
    'A': 9,
    'B': 11,
  };
  final match = RegExp(r'^([A-G])([#♯b♭]?)(-?\d+)$').firstMatch(note);
  if (match == null || !referenceHz.isFinite || referenceHz <= 0) {
    throw ArgumentError('note/reference');
  }
  final accidental = match[2]!;
  final semitone =
      pitchClasses[match[1]]! +
      (accidental == '#' || accidental == '♯'
          ? 1
          : accidental == 'b' || accidental == '♭'
          ? -1
          : 0);
  final midi = (int.parse(match[3]!) + 1) * 12 + semitone;
  return referenceHz * math.pow(2, (midi - 69) / 12);
}
