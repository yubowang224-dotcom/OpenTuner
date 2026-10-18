import 'dart:math';

import '../audio/reference_player.dart' show noteFrequency;
import 'piano_calibration.dart';

enum PianoKind { digital, upright, grand }

class PianoKey {
  PianoKey(this.midi) {
    if (midi < 21 || midi > 108) throw ArgumentError.value(midi);
  }
  final int midi;
  int get number => midi - 20;
  String get note =>
      '${const ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'][midi % 12]}${midi ~/ 12 - 1}';
  double frequency(double a4) => noteFrequency(note, a4);
}

final pianoKeys = List<PianoKey>.unmodifiable(
  List.generate(88, (i) => PianoKey(i + 21)),
);
PianoKey pianoKey(String note) =>
    pianoKeys.firstWhere((key) => key.note == note);

class PianoProfile {
  PianoProfile({
    required this.id,
    required String name,
    required this.kind,
    required this.a4,
    required this.midi,
    required this.created,
    required this.updated,
    this.calibration,
  }) : name = name.trim() {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id) ||
        this.name.isEmpty ||
        this.name.length > 80 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(this.name) ||
        !a4.isFinite ||
        a4 < 400 ||
        a4 > 480 ||
        midi < 21 ||
        midi > 108 ||
        !created.isUtc ||
        !updated.isUtc ||
        updated.isBefore(created)) {
      throw const FormatException('profile');
    }
  }
  final String id, name;
  final PianoKind kind;
  final double a4;
  final int midi;
  final DateTime created, updated;
  final PianoCalibration? calibration;
  static String newId() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'a4': a4,
    'midi': midi,
    'created': created.toIso8601String(),
    'updated': updated.toIso8601String(),
    'mode': 'equalTemperament',
    'calibration': calibration?.toJson(),
  };
  static PianoProfile fromJson(Object? raw, {bool legacy = false}) {
    if (raw is! Map ||
        raw.length != (legacy ? 8 : 9) ||
        (!legacy && !raw.containsKey('calibration')) ||
        raw['mode'] != 'equalTemperament' ||
        raw['id'] is! String ||
        raw['name'] is! String ||
        raw['kind'] is! String ||
        raw['a4'] is! num ||
        raw['midi'] is! int ||
        raw['created'] is! String ||
        raw['updated'] is! String) {
      throw const FormatException('profile fields');
    }
    DateTime utc(String text) {
      final time = DateTime.parse(text);
      if (!time.isUtc || time.toIso8601String() != text) {
        throw const FormatException('canonical UTC');
      }
      return time;
    }

    return PianoProfile(
      id: raw['id'] as String,
      name: raw['name'] as String,
      kind: PianoKind.values.firstWhere((k) => k.name == raw['kind']),
      a4: (raw['a4'] as num).toDouble(),
      midi: raw['midi'] as int,
      created: utc(raw['created'] as String),
      updated: utc(raw['updated'] as String),
      calibration: legacy || raw['calibration'] == null
          ? null
          : PianoCalibration.decode(raw['calibration']),
    );
  }
}
