import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'profile_store.dart';

ProfileStore createDirectoryProfileStore(String path) =>
    FileProfileStore(Directory(path));

/// Only fixed filenames in the OS-provided app-private directory; names/IDs
/// never become paths. Lock + expected revision protect against stale writers.
class FileProfileStore implements ProfileStore {
  FileProfileStore(this.directory);
  final Directory directory;
  static final Map<String, Future<void>> _writers = {};
  @override
  bool get supported => true;
  File get _main => File('${directory.path}/pianos.json');
  File get _backup => File('${directory.path}/pianos.bak');
  Future<T> _locked<T>(Future<T> Function() action) async {
    final key = directory.absolute.path;
    final previous = _writers[key] ?? Future<void>.value();
    final done = Completer<void>();
    _writers[key] = done.future;
    await previous;
    try {
      await directory.create(recursive: true);
      final lock = await File('${directory.path}/pianos.lock')
          .open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.exclusive);
        return await action();
      } finally {
        try {
          await lock.unlock();
        } finally {
          await lock.close();
        }
      }
    } finally {
      done.complete();
      if (identical(_writers[key], done.future)) _writers.remove(key);
    }
  }

  Future<ProfileArchive> _read(File file, {bool recovered = false}) async {
    if (await file.length() > 1024 * 1024) {
      throw const ProfileException(ProfileIssue.corrupt);
    }
    final bytes = await file.readAsBytes();
    try {
      return ProfileArchive.decode(utf8.decode(bytes), recovered: recovered);
    } on FormatException {
      throw const ProfileException(ProfileIssue.corrupt);
    }
  }

  Future<ProfileArchive> _load() async {
    if (!await _main.exists()) {
      return await _backup.exists()
          ? await _read(_backup, recovered: true)
          : ProfileArchive.empty();
    }
    try {
      return await _read(_main);
    } on ProfileException catch (e) {
      if (e.issue == ProfileIssue.schema) rethrow;
      if (await _backup.exists()) return _read(_backup, recovered: true);
      rethrow;
    }
  }

  @override
  Future<ProfileArchive> load() => _locked(_load);
  @override
  Future<ProfileArchive> save(
    ProfileArchive next,
    int expectedRevision,
  ) => _locked(() async {
    final current = await _load();
    if (current.recovered) throw const ProfileException(ProfileIssue.recovered);
    if (current.revision != expectedRevision ||
        next.revision != expectedRevision + 1) {
      throw const ProfileException(ProfileIssue.conflict);
    }
    // Validate before touching existing bytes. Flush temporary payload, keep
    // the previous valid main as backup, then same-directory file replacement.
    final encoded = next.encode();
    if (utf8.encode(encoded).length > 1024 * 1024) {
      throw const ProfileException(ProfileIssue.capacity);
    }
    ProfileArchive.decode(encoded);
    final temporary = File('${directory.path}/pianos.tmp');
    await temporary.writeAsString(encoded, flush: true);
    if (await _main.exists()) {
      await _backup.writeAsBytes(await _main.readAsBytes(), flush: true);
    }
    await temporary.rename(_main.path);
    return next;
  });
  @override
  Future<ProfileArchive> recover() => _locked(() async {
    final state = await _load();
    if (!state.recovered) throw const ProfileException(ProfileIssue.conflict);
    final good = await _read(_backup);
    if (await _main.exists()) {
      await _main.rename(
        '${directory.path}/pianos.corrupt-${DateTime.now().microsecondsSinceEpoch}',
      );
    }
    final temporary = File('${directory.path}/pianos.tmp');
    await temporary.writeAsString(good.encode(), flush: true);
    await temporary.rename(_main.path);
    return good;
  });
}
