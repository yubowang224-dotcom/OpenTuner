import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../audio/audio_capture.dart';
import '../audio/reference_player.dart';

class GuitarString {
  const GuitarString(this.number, this.note);
  final int number;
  final String note;
  double frequency(double a4) => noteFrequency(note, a4);
}

const standardGuitar = [
  GuitarString(6, 'E2'),
  GuitarString(5, 'A2'),
  GuitarString(4, 'D3'),
  GuitarString(3, 'G3'),
  GuitarString(2, 'B3'),
  GuitarString(1, 'E4'),
];

/// Physical string order is always 6 (lowest) through 1 (highest).
/// Notes retain their actual octaves; a preset never folds a measured octave.
class GuitarPreset {
  const GuitarPreset(this.id, this.strings);
  final String id;
  final List<GuitarString> strings;
}

const guitarPresets = [
  GuitarPreset('standard', standardGuitar),
  GuitarPreset('dropD', [
    GuitarString(6, 'D2'),
    GuitarString(5, 'A2'),
    GuitarString(4, 'D3'),
    GuitarString(3, 'G3'),
    GuitarString(2, 'B3'),
    GuitarString(1, 'E4'),
  ]),
  GuitarPreset('dStandard', [
    GuitarString(6, 'D2'),
    GuitarString(5, 'G2'),
    GuitarString(4, 'C3'),
    GuitarString(3, 'F3'),
    GuitarString(2, 'A3'),
    GuitarString(1, 'D4'),
  ]),
  GuitarPreset('halfDown', [
    GuitarString(6, 'Eb2'),
    GuitarString(5, 'Ab2'),
    GuitarString(4, 'Db3'),
    GuitarString(3, 'Gb3'),
    GuitarString(2, 'Bb3'),
    GuitarString(1, 'Eb4'),
  ]),
  GuitarPreset('dadgad', [
    GuitarString(6, 'D2'),
    GuitarString(5, 'A2'),
    GuitarString(4, 'D3'),
    GuitarString(3, 'G3'),
    GuitarString(2, 'A3'),
    GuitarString(1, 'D4'),
  ]),
  GuitarPreset('openD', [
    GuitarString(6, 'D2'),
    GuitarString(5, 'A2'),
    GuitarString(4, 'D3'),
    GuitarString(3, 'F#3'),
    GuitarString(2, 'A3'),
    GuitarString(1, 'D4'),
  ]),
  GuitarPreset('openG', [
    GuitarString(6, 'D2'),
    GuitarString(5, 'G2'),
    GuitarString(4, 'D3'),
    GuitarString(3, 'G3'),
    GuitarString(2, 'B3'),
    GuitarString(1, 'D4'),
  ]),
];

GuitarPreset guitarPreset(String id) =>
    guitarPresets.firstWhere((p) => p.id == id);
double targetCents(double measured, double target) {
  if (!measured.isFinite || measured <= 0 || !target.isFinite || target <= 0) {
    throw ArgumentError('pitch');
  }
  return 1200 * math.log(measured / target) / math.ln2;
}

enum GuitarMatchState { matched, confirming, ambiguous, outside, invalid }

class GuitarMatch {
  const GuitarMatch(this.state, [this.index]);
  final GuitarMatchState state;
  final int? index;
}

/// Absolute pitch only: no octave folding and no claim of physical-string ID.
GuitarMatch matchGuitar(
  double hz,
  double a4, [
  GuitarPreset preset = const GuitarPreset('standard', standardGuitar),
]) {
  if (!hz.isFinite || hz <= 0) {
    return const GuitarMatch(GuitarMatchState.invalid);
  }
  final distances = List.generate(
    6,
    (i) => (i, targetCents(hz, preset.strings[i].frequency(a4)).abs()),
  )..sort((a, b) => a.$2.compareTo(b.$2));
  if (distances[1].$2 - distances[0].$2 <= 25) {
    return const GuitarMatch(GuitarMatchState.ambiguous);
  }
  if (distances[0].$2 > 150) return const GuitarMatch(GuitarMatchState.outside);
  return GuitarMatch(GuitarMatchState.matched, distances[0].$1);
}

/// Consumes the production Analyzer's tracked Hz unchanged. Only auto TARGET
/// selection requires two distinct fresh snapshots; it adds no pitch filtering.
class GuitarTuner extends ChangeNotifier {
  GuitarTuner({required this.capture, int selected = 0, GuitarPreset? preset})
    : _selected = selected,
      _preset = preset ?? guitarPresets.first {
    if (selected < 0 || selected > 5) throw RangeError.range(selected, 0, 5);
    capture.addListener(_changed);
  }
  final AudioCapture capture;
  GuitarPreset _preset;
  GuitarPreset get preset => _preset;
  bool automatic = false;
  int? _selected, _candidate;
  int _count = 0, _sequence = -1;
  AudioSnapshot? _blockedPresetFrame;
  GuitarMatchState matchState = GuitarMatchState.invalid;
  int? get selected => _selected;
  GuitarString? get target =>
      _selected == null ? null : _preset.strings[_selected!];
  double? get targetHz => target?.frequency(capture.referenceHz);
  double? get cents =>
      capture.current?.valid == true &&
          !identical(capture.current, _blockedPresetFrame) &&
          targetHz != null &&
          (!automatic || matchState == GuitarMatchState.matched)
      ? targetCents(capture.current!.trackedHz!, targetHz!)
      : null;

  /// Caller stops/clears capture before changing the target set. Never interprets
  /// a snapshot retained from the previous preset as a new accepted result.
  void setPreset(GuitarPreset value) {
    if (identical(_preset, value)) return;
    _preset = value;
    _blockedPresetFrame = capture.current;
    _selected = automatic ? null : 0;
    _candidate = null;
    _count = 0;
    _sequence = -1;
    matchState = GuitarMatchState.invalid;
    notifyListeners();
  }

  void manual(int i) {
    if (i < 0 || i > 5) throw RangeError.range(i, 0, 5);
    automatic = false;
    _selected = i;
    _candidate = null;
    _count = 0;
    notifyListeners();
  }

  void setAutomatic(bool value) {
    automatic = value;
    _candidate = null;
    _count = 0;
    _sequence = -1;
    matchState = GuitarMatchState.invalid;
    if (value) {
      _selected = null;
    } else {
      _selected ??= 0;
    }
    notifyListeners();
  }

  void _changed() {
    final r = capture.current;
    if (automatic) {
      if (r?.valid != true || identical(r, _blockedPresetFrame)) {
        matchState = GuitarMatchState.invalid;
        _candidate = null;
        _count = 0;
      } else if (r!.sequence != _sequence) {
        _sequence = r.sequence;
        final m = matchGuitar(r.trackedHz!, capture.referenceHz, _preset);
        matchState = m.state;
        if (m.state != GuitarMatchState.matched) {
          _candidate = null;
          _count = 0;
        } else if (m.index == _selected) {
          _candidate = null;
          _count = 0;
        } else {
          if (_candidate == m.index) {
            _count++;
          } else {
            _candidate = m.index;
            _count = 1;
          }
          if (_count >= 2) {
            _selected = m.index;
            _candidate = null;
            _count = 0;
          } else {
            matchState = GuitarMatchState.confirming;
          }
        }
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    capture.removeListener(_changed);
    super.dispose();
  }
}
