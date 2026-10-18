import 'package:flutter/foundation.dart';

import 'profile_store.dart';
import 'ui_preferences.dart';
import 'profile_store_stub.dart'
    if (dart.library.io) 'profile_store_io.dart'
    as implementation;

Future<ProfileStore> createPlatformProfileStore() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const UnsupportedProfileStore();
  }
  try {
    final path = await AndroidUiPreferences.channel
        .invokeMethod<String>('profileDirectory')
        .timeout(const Duration(seconds: 2));
    if (path == null || path.isEmpty) throw const FormatException('directory');
    return implementation.createDirectoryProfileStore(path);
  } catch (_) {
    return const UnsupportedProfileStore(issue: ProfileIssue.unavailable);
  }
}
