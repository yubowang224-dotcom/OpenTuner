import 'package:flutter/material.dart';

import 'tuning_reference.dart';
import 'ui_preferences.dart';
import 'guitar_tuning.dart';
import 'piano_model.dart';
import 'profile_store.dart';
import 'piano_calibration.dart';
export 'piano_model.dart' show PianoKind;

/// UI preferences only. Never restores audio sessions or measurement results.
class AppState extends ChangeNotifier {
  AppState({this.preferences, ProfileManager? profiles})
    : profiles = profiles ?? ProfileManager(const UnsupportedProfileStore()) {
    this.profiles.addListener(_profilesChanged);
  }
  final ProfileManager profiles;
  void _profilesChanged() {
    if (!_disposed) {
      if (_curveProfileId != null &&
          profiles.archive.revision != _curveRevision) {
        _curveProfileId = null;
        ++_audioRevision;
      }
      notifyListeners();
    }
  }

  final UiPreferences? preferences;
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  bool preferencesError = false, preferencesSaving = false;
  bool get preferencesPersistent => preferences?.supported == true;
  int _revision = 0;
  bool _disposed = false;
  Future<void>? _save;
  Map<String, Object>? _pendingPreferences;
  Future<void> get preferencesSettled => _save ?? Future<void>.value();

  Future<void> restorePreferences() async {
    if (!preferencesPersistent) return;
    final revision = _revision;
    try {
      final data = await preferences!.read().timeout(
        const Duration(seconds: 2),
      );
      if (_disposed || revision != _revision) return;
      if ((data['version'] != 1 && data['version'] != 2) ||
          data['minimal'] is! bool ||
          (data['version'] == 2 &&
              (data['referenceHz'] is! num ||
                  !(data['referenceHz'] as num).isFinite ||
                  (data['referenceHz'] as num) < 400 ||
                  (data['referenceHz'] as num) > 480)) ||
          !ThemeMode.values.any((m) => m.name == data['theme'])) {
        throw const FormatException('UI preferences');
      }
      _themeMode = ThemeMode.values.firstWhere((m) => m.name == data['theme']);
      _minimal = data['minimal'] as bool;
      _referenceHz = data['version'] == 2
          ? (data['referenceHz'] as num).toDouble()
          : defaultReferenceHz;
      preferencesError = false;
    } catch (_) {
      if (_disposed || revision != _revision) return;
      preferencesError = true;
    }
    notifyListeners();
  }

  void setThemeMode(ThemeMode value) {
    _themeMode = value;
    _storeAppearance();
    notifyListeners();
  }

  void _storeAppearance() {
    ++_revision;
    if (!preferencesPersistent) return;
    preferencesSaving = true;
    _pendingPreferences = {
      'version': 2,
      'theme': _themeMode.name,
      'minimal': _minimal,
      'referenceHz': _referenceHz,
    };
    _save ??= Future<void>.microtask(_drainPreferences);
  }

  Future<void> _drainPreferences() async {
    preferencesSaving = true;
    // One in-flight write and one latest pending value: bounded even under
    // rapid toggles. Disk order is serialized by both Dart and Android.
    while (_pendingPreferences != null) {
      final value = _pendingPreferences!;
      _pendingPreferences = null;
      try {
        await preferences!.write(value).timeout(const Duration(seconds: 2));
        preferencesError = false;
      } catch (_) {
        preferencesError = true;
      }
    }
    preferencesSaving = false;
    _save = null;
    if (!_disposed) notifyListeners();
  }

  double _referenceHz = defaultReferenceHz;
  int _audioRevision = 0;
  int _configurationIntent = 0;
  String? _curveProfileId;
  int _curveRevision = -1;
  StretchCurve? get pianoCurve {
    if (_curveProfileId == null || pianoKind == PianoKind.digital) return null;
    final p = profiles.archive.profiles
        .where((p) => p.id == _curveProfileId)
        .firstOrNull;
    final c = p?.calibration;
    return c != null &&
            c.a4 == referenceHz &&
            c.kind == pianoKind.name &&
            p!.a4 == referenceHz &&
            p.kind == pianoKind
        ? c.curve
        : null;
  }

  bool get pianoPartialMeasurement =>
      pianoCurve?.point(pianoKey(pianoNote).midi) != null;
  double get pianoTargetHz =>
      pianoCurve?.point(pianoKey(pianoNote).midi)?.firstHz ??
      pianoKey(pianoNote).frequency(referenceHz);
  bool applyPianoCurve(String id) {
    final profile = profiles.selected, c = profiles.selected?.calibration;
    if (profile?.id != id ||
        profiles.busy ||
        c?.curve == null ||
        c!.kind != pianoKind.name ||
        c.a4 != referenceHz ||
        profile!.kind != pianoKind ||
        profile.a4 != referenceHz ||
        pianoKind == PianoKind.digital) {
      return false;
    }
    _curveProfileId = id;
    _curveRevision = profiles.archive.revision;
    ++_audioRevision;
    ++_configurationIntent;
    _demo = false;
    notifyListeners();
    return true;
  }

  void clearPianoCurve() {
    if (_curveProfileId == null) return;
    _curveProfileId = null;
    ++_audioRevision;
    ++_configurationIntent;
    notifyListeners();
  }

  double get referenceHz => _referenceHz;
  int get audioRevision => _audioRevision;
  void setReferenceHz(double value) {
    if (!value.isFinite || value < 400 || value > 480) {
      throw ArgumentError.value(value);
    }
    if (value == _referenceHz) return;
    _referenceHz = value;
    _curveProfileId = null;
    ++_audioRevision;
    ++_configurationIntent;
    _demo = false;
    _storeAppearance();
    notifyListeners();
  }

  Future<bool> loadPianoProfile(String id) async {
    if (profiles.busy) return false;
    final generation = ++_configurationIntent;
    if (!await profiles.select(id) ||
        _disposed ||
        generation != _configurationIntent) {
      return false;
    }
    final selected = profiles.selected!;
    _curveProfileId = null;
    _referenceHz = selected.a4;
    _pianoKind = selected.kind;
    _pianoNote = PianoKey(selected.midi).note;
    ++_audioRevision;
    _demo = false;
    _storeAppearance();
    notifyListeners();
    return true;
  }

  int _page = 0;
  Locale? _locale;
  bool _minimal = false;
  bool _demo = false;
  double _demoCents = 0;
  int _guitarString = 0;
  GuitarPreset _guitarPreset = guitarPresets.first;
  GuitarPreset get selectedGuitarPreset => _guitarPreset;
  double _guitarGain = .8;
  double get guitarGain => _guitarGain;
  void setGuitarGain(double value) {
    if (!value.isFinite) throw ArgumentError.value(value);
    _guitarGain = value.clamp(0, 1);
    notifyListeners();
  }

  void selectGuitarPreset(String id) {
    final next = guitarPreset(id);
    if (next.id == _guitarPreset.id) return;
    _guitarPreset = next;
    _guitarString = 0;
    notifyListeners();
  }

  String _pianoNote = 'A4';
  PianoKind _pianoKind = PianoKind.digital;
  int _bpm = 100;
  String _meter = '4/4';
  int _subdivision = 0;
  bool _accent = true;
  int _metroGain = 100;
  int get metroGain => _metroGain;
  void setMetroGain(int value) {
    _metroGain = value.clamp(0, 100);
    notifyListeners();
  }

  bool get accent => _accent;
  void setAccent(bool value) {
    _accent = value;
    notifyListeners();
  }

  int get page => _page;
  Locale? get locale => _locale;
  bool get minimal => _minimal;
  bool get demo => _demo;
  double get demoCents => _demoCents;
  int get guitarString => _guitarString;
  String get pianoNote => _pianoNote;
  PianoKind get pianoKind => _pianoKind;
  int get bpm => _bpm;
  String get meter => _meter;
  int get subdivision => _subdivision;

  void selectPage(int value) {
    if (value < 0 || value > 4) throw RangeError.range(value, 0, 4);
    if (value == _page) return;
    ++_configurationIntent;
    _page = value;
    _demo = false;
    _demoCents = 0;
    notifyListeners();
  }

  void setLocale(Locale? value) {
    _locale = value;
    notifyListeners();
  }

  void setMinimal(bool value) {
    _minimal = value;
    _storeAppearance();
    notifyListeners();
  }

  void setDemo(bool value) {
    _demo = value;
    _demoCents = 0;
    notifyListeners();
  }

  void setDemoCents(double value) {
    if (!value.isFinite) throw ArgumentError.value(value);
    _demoCents = value.clamp(-50, 50);
    notifyListeners();
  }

  void selectString(int value) {
    if (value < 0 || value > 5) throw RangeError.range(value, 0, 5);
    _guitarString = value;
    notifyListeners();
  }

  void selectPianoNote(String value) {
    pianoKey(value);
    ++_configurationIntent;
    _pianoNote = value;
    notifyListeners();
  }

  void setPianoKind(PianoKind value) {
    if (value != _pianoKind) _curveProfileId = null;
    ++_configurationIntent;
    _pianoKind = value;
    notifyListeners();
  }

  void setBpm(int value) {
    _bpm = value.clamp(20, 300);
    notifyListeners();
  }

  void setMeter(String value) {
    _meter = value;
    notifyListeners();
  }

  void setSubdivision(int value) {
    _subdivision = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    profiles.removeListener(_profilesChanged);
    profiles.dispose();
    super.dispose();
  }
}
