# Contributing

OpenTuner is a Flutter/C++ Android tuner. Read the architecture, algorithms and validation documentation in docs/ before changing audio behavior. Use the pinned toolchain and lockfile described in README and docs/windows-setup.zh-CN.md.

Run dependency resolution, localization generation, Dart formatting, Flutter analysis/tests, CMake/CTest and an Android build for relevant changes. Record commands, tool versions, input conditions, coverage, rejected frames, errors and timing. Do not remove difficult conditions or relax criteria after observing a failure. Host timing and synthetic accuracy are not phone acoustic measurements.

Keep real-time audio callbacks bounded and free of allocation, locks, I/O, FFT and JNI/UI calls. Test actual production analyzers, not alternate test-only implementations. Handle lifecycle, stale sessions, no-signal states, small screens and both centralized language resources.

Use small reviewable changes. New dependencies need source, version, license and compatibility review. Recordings require documented redistribution rights. Never commit user recordings/profiles, credentials, signing material, machine configuration or build binaries. Screenshot tools may use an installed font locally; do not redistribute that font.

Mechanical-piano calibration remains Experimental until independent real-piano validation. Preserve distinctions between observations, interpolation and model predictions. When reporting a bug, provide version/device/actual sample rate and reproducible steps, with personal names and device serial numbers removed.
