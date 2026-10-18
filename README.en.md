# OpenTuner

[简体中文](README.md) · English

## Download the APK

**Packages have not been published yet.** Check the [GitHub Releases list](https://github.com/yubowang224-dotcom/OpenTuner/releases); exact Beta tag/APK links will be added after verified publication.

- **arm64-v8a is recommended for typical 64-bit Android phones.**
- **Choose universal if unsure of the architecture.**
- armeabi-v7a is for compatible32-bit devices; x86_64 is for that architecture/devices or emulators. Android7+.
- **Do not uninstall an old Debug app first.** The dedicated release certificate differs and direct replacement is blocked; no user-facing profile export/import exists yet. [Install](docs/install-release.zh-CN.md) · [Migration](docs/debug-to-release-migration.zh-CN.md).

All implementation source, algorithms, tests, build scripts and resources are open under Apache-2.0. The repository must include the complete browsable/cloneable source tree; the source ZIP is a supplement. Third-party components retain their own licenses; see [third-party notices](THIRD_PARTY_NOTICES.md). Private keys, passwords, machine-private configuration, personal data and build waste are excluded.

**Current dedicated-key signed candidate: 0.7.0-beta.2, unified versionCode5001, Android7/API24+.** Local Explore, seven six-string presets,88-key ET piano, references, native metronome, themes/focus and Experimental mechanical calibration are implemented. No VIP or paid tier.

The [verified project repository](https://github.com/yubowang224-dotcom/OpenTuner) exists; published source, packages and remote CI are determined by its actual contents, not by local build success. [Release Notes: Chinese first, English follows](docs/release-notes-0.7.0-beta.2.md).

Dedicated signing establishes the long-term update identity, **not unconditional production stability or professional acoustic certification**. Mechanical calibration remains Experimental, normally A1–A6 model support. Phone/real-piano/vendor compatibility validation remains pending. Accepted208 Flutter/12 native groups and final affected checks are retained; this metadata/signing change passed analysis and13 targeted tests with unchanged native-source fingerprints. [Signing report](docs/release-signing-report.md).

**Keep the old Debug app and data; do not uninstall first.** Its certificate differs, direct replacement is blocked, and there is currently no user-facing profile export/import or lossless migration promise. [Migration guide](docs/debug-to-release-migration.zh-CN.md).

<img src="docs/screenshots/m3-piano-focus-en-dark.png" width="260" alt="Actual Flutter focus UI, test snapshot, not a phone">
<img src="docs/screenshots/m1-acknowledgements-zh-dark.png" width="260" alt="Actual Flutter acknowledgements, test render, not a phone">

These are actual production-widget test renders with controlled snapshots, not phone recordings, audio output or acoustic accuracy evidence. Source/package upload remains pending; the link above is the verified repository.

An open-source Android guitar and piano tuning project with live pitch analysis,
reference tones and a sample-clock metronome. The aim is a subscription-free tool
that people can use, study and improve. This is also a *Data Analysis and Feature
Extraction* course project; special thanks to instructor Zhang Miao (张淼).
[Course and algorithms](docs/audio-signal-processing.md) · [Experiments](docs/pitch-tracking-evaluation.md).

Earlier implementation snapshots: [Tools1](docs/tools1-report.md), [navigation fix](docs/navigationfix-report.md), [appearance/PCM](docs/appearance-report.md). These are dated reports, not current feature claims.

## Available and planned

- **Available in code / automated checks:** Explore with real PCM waveform and
  spectrum, YIN/harmonic quality checks and adaptive pitch tracking; seven
  six-string manual/automatic presets; controllable 3-second guitar pluck or piano sine
  references and App volume; native 20–300 quarter-note BPM metronome, 2/4,3/4,4/4,6/8, accents,
  1/2/3/4 subdivisions and quarter-note Tap, with separate pause/resume/stop.
- **Safety of interpretation:** no octave folding to force an in-tune result;
  automatic target matching may be ambiguous or mistake a harmonic for another
  string. Reference, microphone and metronome are mutually exclusive. No
  background recording/playback or automatic resume.
- **Piano foundation:** 88 manual targets, independent 180 ms-window analyzer, target/measured/cents separation, locally saved A4 and versioned private profiles. Digital defaults to ET; compatible mechanical profiles may explicitly apply Experimental targets within measured support. No piano measurement demo fallback.
- **Experimental:** actual partial fitting, accept/retry/undo, schema2 provenance, measured/interpolated B and modeled targets. Changing samples invalidates the curve; historical search hints never become active targets. Phone/real-piano validation and the remaining-scope items are pending. No professional tuning claim. Seven/twelve-string support was canceled. iOS follows Android completion/publication in this repository.

The approved user-provided icon and name are OpenTuner; applicationId remains
`org.opentune.tuner`; the dedicated Release certificate differs from Debug and cannot directly replace it. The directory and
existing Git history were retained. Verified project repository: https://github.com/yubowang224-dotcom/OpenTuner . Source/APK upload is verified separately.

A sanitized source snapshot was independently extracted: locked dependency resolution, generated translations, seven smoke tests and an actual unsigned arm64 AOT build passed. [Source/export evidence](docs/release-prep-export-verification.md) · [Debug installation](docs/install-release-prep.zh-CN.md).

## Build and reproduce

Pinned Flutter3.47.5/Dart3.13.4, JDK21, SDK36, NDK28.2.13676358 and Oboe1.11.0.
On the prepared Windows host:

```powershell
. ./tools/activate.ps1
flutter pub get --enforce-lockfile
flutter gen-l10n
flutter analyze
flutter test
cmake -S native -B build/m3-dsp
cmake --build build/m3-dsp --config Release
ctest --test-dir build/m3-dsp -C Release --output-on-failure
./tools/build-debug.ps1
```

The dedicated release certificate SHA256 is `ae27b3e61d3d21419b6a45236bc9c56cbddcf05044a2311f56f4627d2eaf6892`.

Choose the appropriate ABI or universal APK, all code5001. File hashes are in SHA256SUMS and the [signing report](docs/release-signing-report.md). Old Debug packages remain archived and have a different identity. Without external private signing configuration, developer/CI Release builds are explicitly unsigned; no official private key is distributed.

Public source snapshots exclude local history/private configuration/keys. [Publication inventory](docs/publication-inventory.md). GitHub is the only publication target; Gitee is canceled. Remote upload and CI are verified separately.

## Algorithm

Microphone samples enter a bounded queue; a worker removes DC and extracts
energy, YIN periodicity and spectral harmonic-consistency features. Candidate
quality gates and adaptive tracking in continuous log frequency stabilize
accepted pitches. Raw estimates, tracked Hz, displayed numbers and the rendered
needle are distinct. Uncertain sound retains its waveform/spectrum without
inventing a current pitch. Guitar and piano cents use the selected actual target frequency. The independent piano mode adds a longer window and refinement from observed integer-related partials, without feeding the selected target back as a measurement. [Piano details and limits](docs/piano-foundation.md).

Mechanical mode separately fits the stiff-string partial model, rejects insufficient or inconsistent peaks and solves weighted octave partial-coincidence targets anchored at A4. Ideal string frequency, observed first partial and inferred/model targets are distinct. All target values are model predictions; no extrapolation or calibrated correctness probability is claimed. [Detailed algorithm, provenance and references](docs/piano-calibration.md).

This engineering combination uses YIN/pYIN research, not a claim to invent
those foundational algorithms or a full pYIN implementation. The comparison
reports rejection, errors, octave failures, jitter and increased glide lag.
The accepted Analyzer/140/50ms tracking parameters were not retuned in Tools1;
57,330 comparison rows match the saved baseline except computation timing.

- [Audio signal processing](docs/audio-signal-processing.md)
- [Feature extraction](docs/feature-extraction.md)
- [Tracking comparison, plots and reproduction](docs/pitch-tracking-evaluation.md)
- [Architecture](docs/architecture.md) · [Audio bridge](docs/audio-bridge.md)
- [Privacy](docs/privacy.md) · [Dependencies](docs/dependencies.md)
- [Windows setup](docs/windows-setup.zh-CN.md)
- Earlier reports: [Stage0](docs/stage-0-report.md), [Stage1](docs/stage-1-report.md),
  [Stage2](docs/stage-2-report.md), [Stage2.5](docs/stage-2.5-report.md),
  [UX1](docs/stage25-ux1-report.md). These are dated archives, not current feature claims.

## Acknowledgements

Special thanks to Zhang Miao (张淼), the instructor of Data Analysis and Feature Extraction. Zhang helped me recognize the importance of open-source sharing and “顶级原则” (original wording). OpenTuner aims to put these ideas into practice through source code, documented algorithms and reproducible experiments.

OpenTuner began as an open-source course project for Data Analysis and Feature Extraction at Harbin Institute of Technology. Inspired by teacher Zhang Miao’s “顶级原则” and the idea of open-source sharing, the author created OpenTuner. This software is free to use, with a commitment to releasing all source code. Guided by the communist ideal of serving everyone, the author hopes to make a modest contribution.

This is a personal course project, not an official publication or endorsement by the university or teacher. These statements reflect the author’s views.

Project repository: [OpenTuner](https://github.com/yubowang224-dotcom/OpenTuner). See its current contents and Releases for published source and installation packages.

[Apache-2.0](LICENSE) · [Third-party notices](THIRD_PARTY_NOTICES.md) ·
[Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md).

[Beta2 independent source build / 干净源码独立构建](docs/release-source-beta2-verification.md)。
