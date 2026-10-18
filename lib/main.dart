import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'model/app_state.dart';
import 'model/ui_preferences.dart';
import 'model/profile_store.dart';
import 'model/profile_store_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Oboe 1.11.0',
    ], await rootBundle.loadString('native/third_party/oboe/LICENSE'));
    yield LicenseEntryWithLineBreaks([
      'NDK libc++ / LLVM runtime',
    ], await rootBundle.loadString('third_party/licenses/ndk-llvm-notice.txt'));
  });
  final state = AppState(
    preferences: const AndroidUiPreferences(),
    profiles: ProfileManager(await createPlatformProfileStore()),
  );
  await state.restorePreferences();
  unawaited(state.profiles.load());
  runApp(OpenTuneApp(state: state));
}
