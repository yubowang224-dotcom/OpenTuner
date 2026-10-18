# Third-party notices — stage 2

The project license is Apache-2.0. Flutter/Dart, the statically linked Oboe source and the NDK C++ runtime retain their licenses. The YIN/FFT implementation is original project code based on published mathematics; no third-party algorithm source or instrument recording was copied. No external font, ad or tracking SDK is bundled.

| Native component | Pin | Notice |
|---|---|---|
| Oboe | 1.11.0, b115f47593969fd67a21e9f63640ffef749b5067 | [Apache-2.0](native/third_party/oboe/LICENSE), [source provenance](native/third_party/oboe/OPENTUNE-PROVENANCE.md) |
| libc++_shared / compiler runtime | NDK 28.2.13676358 | [Actual NDK LLVM combined notices](third_party/licenses/ndk-llvm-notice.txt), including Apache-2.0 with LLVM exceptions and third-party terms |

The NDK notice is an aggregate supplied by the installed toolchain, not a claim that every named tool ships in the APK. Oboe is linked into libopentune_audio.so, with no separate liboboe.so. The three declared ABIs also contain libc++_shared.so and Flutter. The arm64 Debug engine includes a Vulkan validation layer; Flutter's combined engine notices apply. Native notices are registered with Flutter's LicenseRegistry and packaged as assets for offline inspection.

Actual Dart runtime dependency graph from the locked stage-1 build:

| Component | Version | License / local notice |
|---|---|---|
| Flutter | SDK3.47.5 | [BSD-3-Clause](third_party/licenses/flutter.txt) |
| flutter_localizations | SDK3.47.5 | [BSD-3-Clause](third_party/licenses/flutter_localizations.txt) |
| sky_engine / Flutter engine dependencies | SDK-bundled | [Combined upstream notices, multiple licenses](third_party/licenses/sky_engine.txt) |
| intl | 0.20.3 | [BSD-3-Clause](third_party/licenses/intl.txt) |
| characters | 1.4.1 | [BSD-3-Clause](third_party/licenses/characters.txt) |
| collection | 1.19.1 | [BSD-3-Clause](third_party/licenses/collection.txt) |
| meta | 1.19.0 | [BSD-3-Clause](third_party/licenses/meta.txt) |
| path | 1.9.1 | [BSD-3-Clause](third_party/licenses/path.txt) |
| vector_math | 2.4.3 | [BSD-3-Clause](third_party/licenses/vector_math.txt) |
| clock | 1.1.3 | [Apache-2.0](third_party/licenses/clock.txt) |
| material_color_utilities | 0.13.0 | [Apache-2.0](third_party/licenses/material_color_utilities.txt) |

These texts were copied from the actual local SDK/pub package licenses; line endings and trailing whitespace were normalized, preserving the license wording and copyright notices. The engine file is an upstream aggregate, not a claim that every listed engine component ships in this exact APK. Flutter also generates its packaged notices. The app lockfile contains development/testing packages as well; those are not all runtime dependencies. See [dependency review](docs/dependencies.md) for the build-tool and prospective audio dependencies. Recheck the actual binary inventory before release.

Before release, review native shared libraries, notices and any new assets again. Development tools retain their own licenses and are installed outside this repository. This repository's Apache-2.0 license does not relicense third-party components. UI screenshot rendering used a local Windows font without copying that font into source or APK.

No real instrument sample assets have been added. Public access to a recording does not by itself authorize redistribution.
