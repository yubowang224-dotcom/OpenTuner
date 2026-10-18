# Contributing

Stage 1 provides the Flutter UI; audio is not implemented. Start with the requirements, architecture and latest stage report in `docs/`.

Use Flutter 3.47.5 (Dart 3.13.4), JDK 21, Android SDK 36 and the pinned lockfile. Run `flutter pub get --enforce-lockfile`, `flutter gen-l10n`, `dart format --output=none --set-exit-if-changed lib test tools/capture_preview.dart`, `flutter analyze`, `flutter test`, and an Android Debug build. On this Windows machine, activate the existing toolchain with `tools/activate.ps1`. `tools/build-debug.ps1` can take a local proxy host/port without writing global Gradle configuration.

Edit both ARB files, regenerate and commit `lib/l10n/generated/`. The CI workflow has been authored but has not run remotely. Screenshot rendering uses a Windows font locally and never redistributes that font; see `tools/capture_preview.dart` and the stage report.

Use small reviewable changes. Record exact commands, tool versions and test results. Pitch tests must include rejected/invalid frames, octave errors, latency and noise rejection, not just errors on accepted frames. Keep failing evidence; do not loosen a criterion after observing a failure to call it a pass.

Do not add recordings without documented redistribution rights and source attribution. Do not commit raw user audio, credentials, keystores or binaries. New dependencies require a version, source, license and compatibility review.

Use English and Simplified Chinese centralized resources for user-facing text. Include no-signal, permission-denial, lifecycle and small-screen behavior when adding UI/audio features.

Before Android release, complete real-device checks and license/manifest/signing review. No external publishing is authorized by this document.
