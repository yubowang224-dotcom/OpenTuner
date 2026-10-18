# Changelog

## 0.6.1-release-prep.1 (base code17) — 2026-10-19

- Add independent sample-domain metronome pause/resume with frozen musical phase, output heartbeat, muted-resume guarantees and separate stop/reset.
- Fix Android ABI2/17-field snapshot rejection using a production Java decoder, add ABI3/19-field transport and production C++→Java/Dart tests.
- Correct A4 persistence/privacy wording, record user-supplied icon provenance, de-identify current public documents while retaining local history.
- 208 Flutter checks, 12 native groups plus final affected checks; Debug17 and smaller three-ABI unsigned AOT splits inspected. Unsigned is NOT INSTALLABLE; no signing key, credentials or remote publication created.

## 0.6.0-piano-experimental (code15) — 2026-10-19

- Integrate production stiff-string partial fitting, explicit quality rejection and guided mechanical calibration with accept/retry/undo, schema2 provenance and safe legacy migration.
- Generate, review, save and explicitly apply bounded first-partial stretch targets; separate measured/interpolated B, modeled targets and historical resampling hints. Default A1–A6, no extrapolation; digital remains ET.
- Add actual production-model→nonharmonic PCM→measurement/target/reference tests, 201 Flutter checks, 11 native groups, figures and three-ABI static APK verification. General/ET DSP and route protection preserved.
- Experimental: no new phone or real-piano validation; about1.05s first stable fit, limited high-note identifiability. See docs/m3-report.md.

## 0.5.0-piano-foundation (code14) — 2026-10-19

- Add manual A0–C8 targets, independent native piano analyzer and full-range sine references; digital/mechanical modes are explicitly basic equal temperament.
- Save global A4 (400–480 Hz), safely invalidate old sessions and add private versioned piano metadata profiles with stale-write/capacity/corruption recovery checks.
- Fix the new profile TextField/ExpansionTile PageStorage collision using its own typed key; preserve historical navigation protection and accepted general DSP.
- 164 Flutter tests, nine native groups, JVM admission and three-ABI APK/signature/16KB static checks passed. Synthetic piano precision is not phone or real-piano certification; M3 professional calibration/stretch remains unimplemented.


## 0.4.0-guitar-presets (2026-10-19)

- Seven structured six-string presets share manual/auto targets and accurate reference frequencies. Preset changes stop capture/output, clear stale results and cancel old play intents.
- Original additive plucked guitar voice and App gain; piano keeps sine. Louder bounded metronome clicks, live 5ms gain slew without clock reset, ABI2 gain snapshot.
- Accessible bilingual Settings acknowledgements, source publication status and personal-project attribution. Preserve user values and original wording.
- 130 Flutter checks, six C++ groups, 16 labeled widget previews and three-ABI Debug code13, original signature/16KB static checks. New phone checks unperformed; user reports earlier red screen resolved.
- No remote actions; M2/M3 and Android publication gates remain. See docs/m1-guitar-report.md.

## 0.3.2-appearance.1 (2026-10-19)

- Light/dark/system palettes, persistent Android theme/focus preferences, distinct live focus layouts and explicit exit without restarting audio. Header remains text only.
- Display-only anti-aliased PCM extraction, actual sample timing/FS axes and zero-crossing trigger, ABI3; independent FFT and accepted F0/Tracker unchanged. Fix zero-width expanded charts.
- 109 Flutter checks, four native groups, three-ABI Debug package/signature/16KB static checks; real device checks unperformed. Preserve RouteTooltipsTransitions and unreproduced framework6430 risk.
- Final code12; code11 was retained as an intermediate before final lint cleanup. Historical APKs preserved. See docs/appearance-report.md.

## 0.3.1-navigationfix.1 (2026-10-18)

- Guard tooltip portals by current Material route, including license/detail pages; preserve platform transitions and predictive back. Controlled App failures now pass; do not claim all phone assertions resolved.
- Remove header icon only; retain approved launcher/master asset and signing identity.
- 86 Flutter checks, three native groups, three-ABI Debug build and static signature/16KB checks passed. Exact framework6430 phone assertion not independently reproduced; phone regression unperformed.
- versionCode10; code9 is an intermediate home-only fix. Theme/minimal/waveform work preserved and paused per urgent user priority. See docs/navigationfix-report.md.


## 0.3.0-tools1.3 (2026-10-18)

- Real standard six-string manual/automatic guitar tuning from the existing Analyzer, actual-target cents, ambiguity/out-of-range handling and separate reference controls.
- Cancel stale reference requests and stop old tones on target/mode changes; retain capture through minimal-mode changes.
- Native sample-clock metronome with 20–300 quarter-note BPM, four signatures (real 6/8 3+3), accent/subdivision, Tap, output ownership, focus/route/background cleanup.
- Approved OpenTuner display name/icon; same applicationId/signing identity; canceled seven/twelve-string scope.
- 74 Flutter tests, 3 C++ groups, three-ABI Debug build and signature/16KB static checks. Device checks unperformed, not a development gate per user instruction.
- versionCode8; code5–7 were intermediate candidates before selection/branding/privacy finalization, not final delivery. Prior code3/code4 preserved.


## 0.2.5-stage25-ux1 (2026-10-18)

- Keep the accepted pitch detector, native audio libraries and 140/50ms tracker unchanged.
- Add short automatic-reference confirmation, invisible coordinate changes with needle/note fades, and a session-only reference lock.
- Preserve real off-scale cents/direction and invalid-signal behavior; distinguish reference from detected note.
- Add a 120ms current-page entrance; remove the outgoing subtree immediately and respect reduced motion. No glass effects or new dependencies.
- Pass 60 Flutter tests and the original two C++ groups; compare 57,330 output rows to baseline with no non-timing changes.
- versionCode4, unique APK/evidence paths and overwrite refusal; code3 baseline and isolated prior candidates preserved.
- New device UX, actual upgrade, microphone routing and latency remain pending. No phase3 or publication.

## 0.2.5-stage25 (2026-10-18)

- Fix reproducible Explore ExpansionTile/scroll PageStorage type collision without suppressing errors.
- Extract signal/spectral features and add gated adaptive log-pitch state tracking, weak-tone support and separate display interpolation.
- Preserve frozen Stage2 baseline, compare raw/fixed/adaptive on identical synthetic inputs, publish rejection/error/jitter/lag and failure iteration.
- Add mutually exclusive Oboe sine references for standard six-string guitar and C4–C5 white keys, envelopes and lifecycle/focus cleanup.
- Add course algorithm documents, YIN/pYIN attribution, bilingual Algorithm/Acknowledgements drafts and release checklist.
- versionCode3, same applicationId/debug certificate, three-ABI build and static 16KB checks.
- New device regression/listening/upgrade/latency remain pending; glide lag and low-SNR rejection are documented.

## 0.2.0-stage2 (2026-10-18)

- Integrate pinned Oboe, bounded PCM queue, worker and production C++ YIN/quality/tracking analysis into Android.
- Connect Explore to real snapshots, permission/lifecycle controls, waveform/spectrum and minimal mode.
- Add reproducible synthetic metrics, bridge/session tests, original WAV generator and device guide.
- versionCode2; preserve package/minSdk/signing; check three ABIs and static16KB alignment.
- Real Android microphone acceptance remains pending; other instrument/audio features remain unavailable.


## 0.1.0-stage1 — local development build (2026-10-18)

- Create the official Flutter Android app and Web UI preview.
- Add system-following English/Simplified Chinese localization and manual language selection.
- Add a shared light theme, five-page navigation, target selection and session preferences.
- Add the semicircular gauge, continuous retargetable animation, minimal mode and explicitly labeled manual demonstration.
- Keep microphone, reference playback, professional piano calibration and metronome audio unavailable.
- Pass 25 automated tests and export eight actual Flutter widget renderings; build and verify a Debug APK.
- Add a pinned baseline CI workflow (not executed remotely) and current runtime license notices.
- No GitHub publication or release signing.

## Unreleased — stage 0 (2026-10-18)

- Record requirements, staged acceptance gates, architecture and audio research decisions.
- Add reproducible Windows environment inspection and native toolchain smoke probe.
- Prepare local Git repository conventions and Apache-2.0 licensing.
- No application, audio algorithms, APK or public release yet.
