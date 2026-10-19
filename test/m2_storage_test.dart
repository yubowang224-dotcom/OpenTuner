import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/model/app_state.dart';
import 'package:opentune_tuner/model/piano_model.dart';
import 'package:opentune_tuner/model/profile_store.dart';
import 'package:opentune_tuner/model/profile_store_io.dart';

import 'appearance_test.dart' show PreferenceFixture;

class DelayedProfileStore implements ProfileStore {
  @override
  bool supported = true;
  ProfileArchive data = ProfileArchive.empty();
  Completer<void>? savePending;
  Completer<ProfileArchive>? readPending;
  int reads = 0;
  @override
  Future<ProfileArchive> load() async {
    reads++;
    return readPending?.future ?? data;
  }

  @override
  Future<ProfileArchive> save(ProfileArchive next, int revision) async {
    await savePending?.future;
    if (revision != data.revision) {
      throw const ProfileException(ProfileIssue.conflict);
    }
    data = next;
    return next;
  }

  @override
  Future<ProfileArchive> recover() async =>
      throw const ProfileException(ProfileIssue.corrupt);
}

PianoProfile profile(String id, String name) => PianoProfile(
  id: id.padLeft(32, '0'),
  name: name,
  kind: PianoKind.digital,
  a4: 442,
  midi: 21,
  created: DateTime.utc(2026, 10, 19),
  updated: DateTime.utc(2026, 10, 19),
);
void main() {
  test('88 keys and A4 extrema have exact MIDI, octave and frequency relationships', () {
    expect(pianoKeys.length, 88);
    expect(pianoKeys.first.note, 'A0');
    expect(pianoKeys.last.note, 'C8');
    expect(pianoKeys.map((p) => p.number), List.generate(88, (i) => i + 1));
    for (final a4 in [400.0, 440.0, 442.0, 480.0]) {
      expect(pianoKeys.first.frequency(a4), closeTo(a4 / 16, 1e-12));
      expect(pianoKeys[48].note, 'A4');
      expect(pianoKeys[48].frequency(a4), a4);
      for (var i = 0; i < 76; i++) {
        expect(
          pianoKeys[i + 12].frequency(a4) / pianoKeys[i].frequency(a4),
          closeTo(2, 1e-12),
        );
      }
    }
    expect(() => PianoKey(20), throwsArgumentError);
    expect(() => PianoKey(109), throwsArgumentError);
  });
  test(
    'capacity refusal preserves 64 valid profiles and permits update',
    () async {
      final store = DelayedProfileStore();
      final profiles = ProfileManager(store);
      await profiles.load();
      for (var i = 0; i < 64; i++) {
        expect(
          await profiles.create('P$i', PianoKind.digital, 440, 69),
          isTrue,
        );
      }
      expect(
        await profiles.create('Overflow', PianoKind.digital, 440, 69),
        isFalse,
      );
      expect(profiles.issue, ProfileIssue.capacity);
      expect(profiles.archive.profiles.length, 64);
      expect(profiles.writable, isTrue);
      final selected = profiles.selected!;
      expect(
        await profiles.update(
          selected.id,
          'Updated',
          PianoKind.grand,
          442,
          108,
          confirmed: true,
        ),
        isTrue,
      );
      expect((await store.load()).profiles.length, 64);
      profiles.dispose();
    },
  );
  test(
    'A4 v1 preference migration, v2 roundtrip and invalid reference rejection',
    () async {
      final store = PreferenceFixture();
      final state = AppState(preferences: store);
      await state.restorePreferences();
      expect(state.referenceHz, 440);
      state.setReferenceHz(442);
      await state.preferencesSettled;
      expect(store.data, {
        'version': 2,
        'theme': 'system',
        'minimal': false,
        'referenceHz': 442.0,
      });
      final restored = AppState(preferences: store);
      await restored.restorePreferences();
      expect(restored.referenceHz, 442);
      for (final value in [399.0, 481.0, double.nan]) {
        expect(() => state.setReferenceHz(value), throwsArgumentError);
      }
      for (final value in [399, 481, '440', null]) {
        final bad = AppState(
          preferences: PreferenceFixture()
            ..data = {
              'version': 2,
              'theme': 'dark',
              'minimal': false,
              'referenceHz': value,
            },
        );
        await bad.restorePreferences();
        expect(bad.preferencesError, isTrue);
        expect(bad.referenceHz, 440);
        bad.dispose();
      }
      restored.dispose();
      state.dispose();
    },
  );
  group('production private file store', () {
    late Directory folder;
    late FileProfileStore files;
    late ProfileManager manager;
    setUp(() async {
      final parent = Directory('artifacts/m2/profile-tests').absolute;
      await parent.create(recursive: true);
      folder = await parent.createTemp('case-');
      files = FileProfileStore(folder);
      manager = ProfileManager(files);
      await manager.load();
    });
    tearDown(() async {
      manager.dispose();
      final parent = Directory('artifacts/m2/profile-tests').absolute.path;
      expect(
        folder.absolute.path.startsWith('$parent${Platform.pathSeparator}'),
        isTrue,
      );
      await folder.delete(recursive: true);
    });
    test('create, select, confirmed update and reload actual bytes', () async {
      expect(
        await manager.create('Test piano', PianoKind.upright, 442, 108),
        isTrue,
      );
      final id = manager.selected!.id;
      expect(
        await manager.create('Second', PianoKind.digital, 440, 21),
        isTrue,
      );
      expect(await manager.select(id), isTrue);
      final before = await File('${folder.path}/pianos.json').readAsString();
      expect(
        await manager.update(
          id,
          'Renamed',
          PianoKind.grand,
          441,
          60,
          confirmed: false,
        ),
        isFalse,
      );
      expect(await File('${folder.path}/pianos.json').readAsString(), before);
      expect(
        await manager.update(
          id,
          'Renamed',
          PianoKind.grand,
          441,
          60,
          confirmed: true,
        ),
        isTrue,
      );
      final loaded = await FileProfileStore(folder).load();
      expect(loaded.selectedId, id);
      expect(loaded.profiles.first.name, 'Renamed');
      expect(loaded.profiles.first.kind, PianoKind.grand);
      expect(loaded.profiles.first.midi, 60);
      expect(loaded.profiles.first.a4, 441);
      expect(loaded.profiles.first.id, id);
      expect(
        loaded.profiles.first.created,
        manager.archive.profiles.first.created,
      );
    });
    test('duplicate names, stale revision and cross-store queued writers cannot overwrite', () async {
      final stale = ProfileManager(FileProfileStore(folder));
      await stale.load();
      expect(await manager.create('Test', PianoKind.digital, 440, 69), isTrue);
      final bytes = await File('${folder.path}/pianos.json').readAsBytes();
      expect(
        await manager.create(' test ', PianoKind.digital, 440, 69),
        isFalse,
      );
      expect(await stale.create('Other', PianoKind.digital, 440, 69), isFalse);
      expect(stale.issue, ProfileIssue.conflict);
      expect(await File('${folder.path}/pianos.json').readAsBytes(), bytes);
      stale.dispose();
      final expected = manager.archive.revision;
      Future<bool> save(String name) async {
        try {
          await FileProfileStore(folder).save(
            ProfileArchive(
              revision: expected + 1,
              profiles: [
                ...manager.archive.profiles,
                profile(name == 'A' ? '1' : '2', name),
              ],
            ),
            expected,
          );
          return true;
        } on ProfileException {
          return false;
        }
      }

      final result = await Future.wait([save('A'), save('B')]);
      expect(result.where((b) => b).length, 1);
      expect((await files.load()).profiles.length, 2);
    });
    for (final corruption in ['truncated', 'utf8', 'oversize']) {
      test(
        'valid backup recovery preserves damaged $corruption file',
        () async {
          await manager.create('First', PianoKind.digital, 440, 21);
          await manager.create('Second', PianoKind.grand, 442, 108);
          final damaged = corruption == 'utf8'
              ? [0xff, 0xfe, 0xc0]
              : corruption == 'oversize'
              ? List<int>.filled(1024 * 1024 + 1, 32)
              : utf8.encode('{"schema":1');
          await File('${folder.path}/pianos.json')
              .writeAsBytes(damaged, flush: true);
          expect(await manager.load(), isTrue);
          expect(manager.issue, ProfileIssue.recovered);
          expect(manager.archive.profiles.length, 1);
          expect(manager.writable, isFalse);
          expect(
            await manager.create('Blocked', PianoKind.digital, 440, 69),
            isFalse,
          );
          expect(await manager.recover(), isTrue);
          expect(manager.writable, isTrue);
          final preserved = await folder
              .list()
              .where((e) => e.path.contains('pianos.corrupt-'))
              .toList();
          expect(preserved.length, 1);
          expect(await File(preserved.single.path).readAsBytes(), damaged);
          expect((await files.load()).profiles.single.name, 'First');
        },
      );
    }
    test(
      'unknown schema with valid backup is read-only, never downgraded',
      () async {
        await manager.create('First', PianoKind.digital, 440, 21);
        await manager.create('Second', PianoKind.digital, 440, 69);
        final future =
            '{"schema":99,"revision":123,"profiles":[],"selectedId":null}';
        await File('${folder.path}/pianos.json')
            .writeAsString(future, flush: true);
        expect(await manager.load(), isFalse);
        expect(manager.issue, ProfileIssue.schema);
        expect(await manager.recover(), isFalse);
        expect(await manager.create('No', PianoKind.digital, 440, 69), isFalse);
        expect(await File('${folder.path}/pianos.json').readAsString(), future);
      },
    );
    test(
      'no backup corruption is reported without destructive recreation',
      () async {
        await File('${folder.path}/pianos.json').writeAsString('broken');
        expect(await manager.load(), isFalse);
        expect(manager.issue, ProfileIssue.corrupt);
        expect(await manager.create('No', PianoKind.digital, 440, 69), isFalse);
        expect(
          await File('${folder.path}/pianos.json').readAsString(),
          'broken',
        );
      },
    );
  });
  test('strict archive rejects bad calendar, duplicate IDs and extra keys', () {
    final p = profile('1', 'First');
    final encoded = ProfileArchive(
      revision: 1,
      profiles: [p],
      selectedId: p.id,
    ).encode();
    expect(ProfileArchive.decode(encoded).profiles.single.a4, 442);
    for (final text in [
      encoded.replaceAll('2026-10-19', '2026-02-30'),
      encoded.replaceFirst('"selectedId":', '"other":'),
      encoded.replaceFirst('"a4":442.0', '"a4":999'),
      encoded.replaceFirst('"mode":"equalTemperament"', '"mode":"stretched"'),
    ]) {
      expect(
        () => ProfileArchive.decode(text),
        throwsA(isA<ProfileException>()),
      );
    }
    expect(
      () => ProfileArchive(revision: 1, profiles: [p, p]),
      throwsA(isA<ProfileException>()),
    );
  });
  testWidgets(
    'read timeout is visible and retries share the one pending load',
    (t) async {
      final store = DelayedProfileStore()..readPending = Completer();
      final manager = ProfileManager(store);
      final loading = manager.load();
      await t.pump(const Duration(milliseconds: 2100));
      expect(await loading, isFalse);
      expect(manager.busy, isFalse);
      expect(manager.issue, ProfileIssue.unavailable);
      final retry = manager.load();
      expect(store.reads, 1);
      await t.pump(const Duration(milliseconds: 2100));
      expect(await retry, isFalse);
      store.readPending!.complete(
        ProfileArchive(revision: 1, profiles: [profile('1', 'Late')]),
      );
      await t.pump();
      expect(manager.archive.profiles, isEmpty);
      manager.dispose();
    },
  );
  for (final change in ['a4', 'key', 'kind', 'page']) {
    test('delayed profile apply cannot replace newer $change intent', () async {
      final store = DelayedProfileStore();
      final profiles = ProfileManager(store);
      await profiles.load();
      await profiles.create('Saved', PianoKind.grand, 442, 21);
      final state = AppState(profiles: profiles);
      store.savePending = Completer();
      final request = state.loadPianoProfile(profiles.selected!.id);
      switch (change) {
        case 'a4':
          state.setReferenceHz(443);
        case 'key':
          state.selectPianoNote('C8');
        case 'kind':
          state.setPianoKind(PianoKind.upright);
        case 'page':
          state.selectPage(2);
      }
      store.savePending!.complete();
      expect(await request, isFalse);
      expect(state.referenceHz, change == 'a4' ? 443 : 440);
      expect(state.pianoNote, change == 'key' ? 'C8' : 'A4');
      state.dispose();
    });
  }
}
