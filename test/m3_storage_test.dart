import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/model/app_state.dart';
import 'package:opentune_tuner/model/piano_calibration.dart';
import 'package:opentune_tuner/model/piano_model.dart';
import 'package:opentune_tuner/model/profile_store.dart';
import 'package:opentune_tuner/model/profile_store_io.dart';

import 'm3_model_test.dart'
    show calibration, modelSample, strongCalibration, curvePacket;

import 'package:opentune_tuner/audio/audio_capture.dart';

void main() {
  late Directory directory;
  late FileProfileStore store;
  late ProfileManager manager;
  setUp(() async {
    final root = Directory('artifacts/m3/profile-tests').absolute;
    await root.create(recursive: true);
    directory = await root.createTemp('case-');
    store = FileProfileStore(directory);
    manager = ProfileManager(store);
    await manager.load();
  });
  tearDown(() async {
    manager.dispose();
    final root = Directory('artifacts/m3/profile-tests').absolute.path;
    if (!directory.absolute.path.startsWith('$root${Platform.pathSeparator}')) {
      throw StateError('test cleanup boundary');
    }
    await directory.delete(recursive: true);
  });
  Future<String> create() async {
    expect(
      await manager.create('Test grand', PianoKind.grand, 440, 69),
      isTrue,
    );
    return manager.selected!.id;
  }

  test('actual file stores >60c resampled partial provenance and historical hints, regenerates on reload', () async {
    final id = await create(),
        old = strongCalibration(),
        center = strongCalibration().curve!.point(33)!.firstHz;
    final sample = PianoMeasurement(
      id: 'a'.padLeft(32, '0'),
      midi: 33,
      captured: DateTime.now().toUtc(),
      source: 'synthetic_test',
      rate: 48000,
      backend: 'synthetic',
      preset: -1,
      session: 7,
      sequence: 4,
      endSeconds: 1.05,
      frame: AudioSnapshot.decode(curvePacket())!.partialFrame!,
      associationHz: center,
      associationAlgorithm: stretchAlgorithm,
    );
    final dirty = old.withSamples([
      ...old.samples.where((s) => s.midi != 33),
      sample,
    ]);
    expect(
      await manager.saveCalibration(id, dirty, manager.archive.revision),
      isTrue,
    );
    final reopened = ProfileManager(FileProfileStore(directory));
    expect(await reopened.load(), isTrue);
    final read = reopened.selected!.calibration!;
    expect(read.curve, isNull);
    expect(read.searchHints.length, 61);
    final stored = read.samples.firstWhere((s) => s.midi == 33);
    expect(stored.associationHz, center);
    expect(stored.associationAlgorithm, stretchAlgorithm);
    expect(stored.frame.firstHz, sample.frame.firstHz);
    expect(read.generate().curve!.point(33), isNotNull);
    reopened.dispose();
  });
  test('unknown historical hint version blocks file write and backup downgrade, even with empty map', () async {
    final id = await create();
    await manager.saveCalibration(id, calibration(), manager.archive.revision);
    final good = await File('${directory.path}/pianos.json').readAsString();
    for (final empty in [false, true]) {
      final raw = jsonDecode(good) as Map;
      final data = raw['profiles'][0]['calibration'];
      data['hintAlgorithm'] = 'future';
      if (empty) {
        data['searchHints'] = {};
        data['curve'] = null;
      }
      final text = jsonEncode(raw);
      await File('${directory.path}/pianos.json').writeAsString(text);
      expect(await manager.load(), isFalse);
      expect(manager.issue, ProfileIssue.schema);
      expect(manager.writable, isFalse);
      expect(await manager.recover(), isFalse);
      expect(await File('${directory.path}/pianos.json').readAsString(), text);
    }
  });
  test('M2 schema1 file migrates only on save and previous valid file remains backup', () async {
    final time = DateTime.utc(2026, 10, 18).toIso8601String();
    final old = jsonEncode({
      'schema': 1,
      'revision': 7,
      'selectedId': '1'.padLeft(32, '0'),
      'profiles': [
        {
          'id': '1'.padLeft(32, '0'),
          'name': 'Legacy grand',
          'kind': 'grand',
          'a4': 440,
          'midi': 69,
          'created': time,
          'updated': time,
          'mode': 'equalTemperament',
        },
      ],
    });
    final file = File('${directory.path}/pianos.json');
    await file.writeAsString(old, flush: true);
    expect(await manager.load(), isTrue);
    expect(manager.selected!.calibration, isNull);
    expect(await file.readAsString(), old);
    expect(
      await manager.saveCalibration(manager.selected!.id, calibration(), 7),
      isTrue,
    );
    expect((jsonDecode(await file.readAsString()) as Map)['schema'], 2);
    expect(await File('${directory.path}/pianos.bak').readAsString(), old);
    final reload = ProfileManager(FileProfileStore(directory));
    await reload.load();
    expect(reload.selected!.calibration!.curve!.point(69)!.firstHz, 440);
    reload.dispose();
  });
  test('actual sample/curve roundtrip, stale update protection and corrupted target recovery', () async {
    final id = await create();
    expect(
      await manager.saveCalibration(
        id,
        calibration(),
        manager.archive.revision,
      ),
      isTrue,
    );
    final bytes = await File('${directory.path}/pianos.json').readAsString();
    expect(
      await manager.saveCalibration(id, calibration(curve: false), 0),
      isFalse,
    );
    expect(manager.issue, ProfileIssue.conflict);
    expect(await File('${directory.path}/pianos.json').readAsString(), bytes);
    // Make a previous good calibrated backup, then corrupt only a modeled Hz.
    expect(
      await manager.update(
        id,
        'Renamed',
        PianoKind.grand,
        440,
        69,
        confirmed: true,
      ),
      isTrue,
    );
    final raw = jsonDecode(
      await File('${directory.path}/pianos.json').readAsString(),
    ) as Map;
    raw['profiles'][0]['calibration']['curve']['points'][0]['first'] += 10;
    await File('${directory.path}/pianos.json').writeAsString(jsonEncode(raw));
    expect(await manager.load(), isTrue);
    expect(manager.archive.recovered, isTrue);
    expect(manager.writable, isFalse);
    expect(manager.selected!.calibration!.curve, isNotNull);
    expect(await manager.recover(), isTrue);
    expect(manager.selected!.calibration!.samples.length, 6);
    expect(
      directory.listSync().any((f) => f.path.contains('pianos.corrupt-')),
      isTrue,
    );
  });
  test(
    'unknown partial/curve algorithm blocks write and backup downgrade',
    () async {
      final id = await create();
      await manager.saveCalibration(
        id,
        calibration(),
        manager.archive.revision,
      );
      for (final which in ['partial', 'curve']) {
        final raw = jsonDecode(manager.archive.encode()) as Map;
        final data = raw['profiles'][0]['calibration'];
        if (which == 'partial') {
          data['algorithm'] = 'future-partials';
        } else {
          data['curve']['algorithm'] = 'future-curve';
        }
        final text = jsonEncode(raw);
        await File('${directory.path}/pianos.json').writeAsString(text);
        expect(await manager.load(), isFalse);
        expect(manager.issue, ProfileIssue.schema);
        expect(await manager.recover(), isFalse);
        expect(
          await manager.saveCalibration(
            id,
            calibration(),
            manager.archive.revision,
          ),
          isFalse,
        );
        expect(
          await File('${directory.path}/pianos.json').readAsString(),
          text,
        );
      }
    },
  );
  test(
    'A4/type metadata edits retain historical calibration but cannot apply it',
    () async {
      final id = await create();
      await manager.saveCalibration(
        id,
        calibration(),
        manager.archive.revision,
      );
      final state = AppState(profiles: manager)..setPianoKind(PianoKind.grand);
      expect(state.applyPianoCurve(id), isTrue);
      expect(state.pianoCurve, isNotNull);
      expect(
        await manager.update(
          id,
          'Retained',
          PianoKind.digital,
          442,
          69,
          confirmed: true,
        ),
        isTrue,
      );
      expect(state.pianoCurve, isNull);
      await state.loadPianoProfile(id);
      expect(state.referenceHz, 442);
      expect(state.pianoKind, PianoKind.digital);
      expect(state.applyPianoCurve(id), isFalse);
      await manager.load();
      expect(manager.selected!.calibration!.a4, 440);
      expect(manager.selected!.calibration!.kind, 'grand');
      expect(state.applyPianoCurve(id), isFalse);
      // AppState owns manager; detach this test's tearDown reference safely.
      state.dispose();
      manager = ProfileManager(store);
    },
  );
  test('new sample/undo invalidates persisted targets and save revision invalidates active targets', () async {
    final id = await create();
    final original = calibration();
    await manager.saveCalibration(id, original, manager.archive.revision);
    final state = AppState(profiles: manager)..setPianoKind(PianoKind.grand);
    expect(state.applyPianoCurve(id), isTrue);
    final changed = original.withSamples(original.samples.take(5).toList());
    expect(changed.curve, isNull);
    expect(
      await manager.saveCalibration(id, changed, manager.archive.revision),
      isTrue,
    );
    expect(state.pianoCurve, isNull);
    expect(state.applyPianoCurve(id), isFalse);
    await manager.load();
    expect(manager.selected!.calibration!.samples.length, 5);
    expect(manager.selected!.calibration!.curve, isNull);
    state.dispose();
    manager = ProfileManager(store);
  });
  test('oversized calibration archive is rejected before replacing valid main bytes', () async {
    await create();
    final prior = await File('${directory.path}/pianos.json').readAsBytes();
    final time = DateTime.utc(2026, 10, 18);
    final big = PianoCalibration(
      a4: 440,
      kind: 'grand',
      created: time,
      updated: time,
      samples: List.generate(88, (i) => modelSample(i + 21, .0004)),
    ).generate();
    final archive = ProfileArchive(
      revision: manager.archive.revision + 1,
      profiles: List.generate(
        64,
        (i) => PianoProfile(
          id: (i + 1).toRadixString(16).padLeft(32, '0'),
          name: 'Large $i',
          kind: PianoKind.grand,
          a4: 440,
          midi: 69,
          created: time,
          updated: time,
          calibration: big,
        ),
      ),
    );
    expect(utf8.encode(archive.encode()).length, greaterThan(1024 * 1024));
    await expectLater(
      store.save(archive, manager.archive.revision),
      throwsA(
        isA<ProfileException>().having(
          (e) => e.issue,
          'issue',
          ProfileIssue.capacity,
        ),
      ),
    );
    expect(await File('${directory.path}/pianos.json').readAsBytes(), prior);
    expect((await store.load()).profiles.single.calibration, isNull);
  });
}
