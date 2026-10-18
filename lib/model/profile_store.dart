import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'piano_model.dart';
import 'piano_calibration.dart';

enum ProfileIssue {
  unsupported,
  unavailable,
  corrupt,
  schema,
  conflict,
  invalid,
  recovered,
  capacity,
}

class ProfileException implements Exception {
  const ProfileException(this.issue);
  final ProfileIssue issue;
}

class ProfileArchive {
  ProfileArchive({
    required this.revision,
    required List<PianoProfile> profiles,
    this.selectedId,
    this.recovered = false,
  }) : profiles = List.unmodifiable(profiles) {
    if (revision < 0 ||
        profiles.length > 64 ||
        profiles.map((p) => p.id).toSet().length != profiles.length ||
        profiles.map((p) => p.name.toLowerCase()).toSet().length !=
            profiles.length ||
        selectedId != null && !profiles.any((p) => p.id == selectedId)) {
      throw const ProfileException(ProfileIssue.corrupt);
    }
  }
  factory ProfileArchive.empty() => ProfileArchive(revision: 0, profiles: []);
  final int revision;
  final List<PianoProfile> profiles;
  final String? selectedId;
  final bool recovered;
  String encode() => jsonEncode({
    'schema': 2,
    'revision': revision,
    'selectedId': selectedId,
    'profiles': profiles.map((p) => p.toJson()).toList(),
  });
  static ProfileArchive decode(String text, {bool recovered = false}) {
    try {
      final raw = jsonDecode(text);
      if (raw is! Map || raw['schema'] is! int) {
        throw const ProfileException(ProfileIssue.corrupt);
      }
      if (raw['schema'] != 1 && raw['schema'] != 2) {
        throw const ProfileException(ProfileIssue.schema);
      }
      if (!raw.containsKey('selectedId') ||
          raw.length != 4 ||
          raw['revision'] is! int ||
          raw['profiles'] is! List ||
          raw['selectedId'] != null && raw['selectedId'] is! String) {
        throw const ProfileException(ProfileIssue.corrupt);
      }
      return ProfileArchive(
        revision: raw['revision'] as int,
        profiles: (raw['profiles'] as List)
            .map((p) => PianoProfile.fromJson(p, legacy: raw['schema'] == 1))
            .toList(),
        selectedId: raw['selectedId'] as String?,
        recovered: recovered,
      );
    } on CalibrationVersionException {
      throw const ProfileException(ProfileIssue.schema);
    } on ProfileException {
      rethrow;
    } catch (_) {
      throw const ProfileException(ProfileIssue.corrupt);
    }
  }
}

abstract interface class ProfileStore {
  bool get supported;
  Future<ProfileArchive> load();
  Future<ProfileArchive> save(ProfileArchive next, int expectedRevision);
  Future<ProfileArchive> recover();
}

class UnsupportedProfileStore implements ProfileStore {
  const UnsupportedProfileStore({this.issue = ProfileIssue.unsupported});
  final ProfileIssue issue;
  @override
  bool get supported => issue != ProfileIssue.unsupported;
  @override
  Future<ProfileArchive> load() async => throw ProfileException(issue);
  @override
  Future<ProfileArchive> save(
    ProfileArchive next,
    int expectedRevision,
  ) async => throw ProfileException(issue);
  @override
  Future<ProfileArchive> recover() async => throw ProfileException(issue);
}

class ProfileManager extends ChangeNotifier {
  ProfileManager(this.store);
  final ProfileStore store;
  ProfileArchive archive = ProfileArchive.empty();
  bool busy = false, _disposed = false;
  int operation = 0;
  ProfileIssue? issue;
  Future<ProfileArchive>? _loading;
  bool get writable =>
      store.supported &&
      !busy &&
      !archive.recovered &&
      (issue == null ||
          issue == ProfileIssue.invalid ||
          issue == ProfileIssue.conflict ||
          issue == ProfileIssue.capacity);
  PianoProfile? get selected =>
      archive.profiles.where((p) => p.id == archive.selectedId).firstOrNull;
  Future<bool> _run(Future<void> Function() action) async {
    if (busy) return false;
    ++operation;
    busy = true;
    notifyListeners();
    try {
      await action();
      issue = archive.recovered ? ProfileIssue.recovered : null;
      return true;
    } on ProfileException catch (e) {
      issue = e.issue;
      return false;
    } catch (_) {
      issue = ProfileIssue.unavailable;
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> load() => _run(() async {
    final pending = _loading ?? store.load();
    if (_loading == null) {
      _loading = pending;
      unawaited(
        pending.then<void>(
          (_) {
            if (identical(_loading, pending)) _loading = null;
          },
          onError: (Object _, StackTrace _) {
            if (identical(_loading, pending)) _loading = null;
          },
        ),
      );
    }
    archive = await pending.timeout(const Duration(seconds: 2));
  });
  Future<bool> recover() => _run(() async {
    archive = await store.recover();
  });
  Future<bool> _commit(List<PianoProfile> profiles, String? selected) =>
      _run(() async {
        if (archive.recovered) {
          throw const ProfileException(ProfileIssue.recovered);
        }
        archive = await store.save(
          ProfileArchive(
            revision: archive.revision + 1,
            profiles: profiles,
            selectedId: selected,
          ),
          archive.revision,
        );
      });
  Future<bool> create(String name, PianoKind kind, double a4, int midi) async {
    if (!writable) return false;
    if (archive.profiles.length >= 64) {
      issue = ProfileIssue.capacity;
      notifyListeners();
      return false;
    }
    try {
      final now = DateTime.now().toUtc();
      final p = PianoProfile(
        id: PianoProfile.newId(),
        name: name,
        kind: kind,
        a4: a4,
        midi: midi,
        created: now,
        updated: now,
      );
      if (archive.profiles.any(
        (v) => v.name.toLowerCase() == p.name.toLowerCase(),
      )) {
        throw const ProfileException(ProfileIssue.conflict);
      }
      return await _commit([...archive.profiles, p], p.id);
    } catch (_) {
      issue = ProfileIssue.invalid;
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(
    String id,
    String name,
    PianoKind kind,
    double a4,
    int midi, {
    required bool confirmed,
  }) async {
    if (!writable) return false;
    try {
      if (!confirmed) throw const ProfileException(ProfileIssue.conflict);
      final old = archive.profiles.firstWhere((p) => p.id == id);
      final next = PianoProfile(
        id: id,
        name: name,
        kind: kind,
        a4: a4,
        midi: midi,
        created: old.created,
        updated: DateTime.now().toUtc(),
        calibration: old.calibration,
      );
      if (archive.profiles.any(
        (p) => p.id != id && p.name.toLowerCase() == next.name.toLowerCase(),
      )) {
        throw const ProfileException(ProfileIssue.conflict);
      }
      return await _commit(
        archive.profiles.map((p) => p.id == id ? next : p).toList(),
        id,
      );
    } catch (_) {
      issue = ProfileIssue.invalid;
      notifyListeners();
      return false;
    }
  }

  Future<bool> select(String id) async {
    if (!writable || !archive.profiles.any((p) => p.id == id)) return false;
    return await _commit(archive.profiles, id);
  }

  Future<bool> saveCalibration(
    String id,
    PianoCalibration calibration,
    int expectedRevision,
  ) async {
    if (!writable) return false;
    if (expectedRevision != archive.revision) {
      issue = ProfileIssue.conflict;
      notifyListeners();
      return false;
    }
    try {
      final old = archive.profiles.firstWhere((p) => p.id == id);
      if (old.kind.name != calibration.kind || old.a4 != calibration.a4) {
        throw const FormatException('calibration association');
      }
      final next = PianoProfile(
        id: old.id,
        name: old.name,
        kind: old.kind,
        a4: old.a4,
        midi: old.midi,
        created: old.created,
        updated: DateTime.now().toUtc(),
        calibration: calibration,
      );
      return await _commit(
        archive.profiles.map((p) => p.id == id ? next : p).toList(),
        id,
      );
    } catch (_) {
      issue = ProfileIssue.invalid;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
