# Mechanical piano calibration — Experimental

This is a working single-key measurement and model pipeline, **not a professional tuning certification**. No mechanical piano or Android microphone was available for M3 validation. Digital piano mode continues to use equal temperament (ET). Host tests, UI fixtures and airborne synthetic playback are different evidence classes.

## Measurement and identifiability

A stiff-string approximation is `f_n = n f_ideal sqrt(1+B n²)` with dimensionless nonnegative B. The actual first partial is `f1 = f_ideal sqrt(1+B)`; these are never interchangeable. A4 and all playable targets refer to **first-partial frequency**. When order 1 is observed, live cents use that actual interpolated peak; otherwise live cents use the explicitly labeled fitted first partial. Stored samples retain both, plus every accepted peak/order/residual. A missing fundamental is therefore model inference, not a measured spectral peak.

`native/src/partial_analyzer.cpp` is the exact production implementation used by Android and host tests. It is independent of the accepted general and ET piano analyzers. Actual input rate must be 16–96 kHz. A 750 ms DC-removed Hann window, 100 ms hop and zero-padded radix-2 FFT provide peak estimates; zero padding interpolates the sampled spectrum and **does not create resolving power**. Peaks are local log-magnitude parabolic interpolations, at most 64, above both 2.5% maximum amplitude and four times median spectral amplitude, below min(18 kHz, 0.42 sample rate). Digital FS/RMS are not sound pressure level. Clipping rejects measurement.

An explicit selected key supplies an association center, initially ET ±60 cents. B grid seeds are 0 and 80 logarithmic values 1e-6…1e-2, used only to associate at most 16 observed orders. Weighted regression of `(f_n/n)² = a+b n²` estimates `f_ideal=sqrt(a)` and `B=b/a`, followed by reassociation within 5 cents. No selected target is substituted for observed frequencies. Weights are clamped square roots of relative peak power. Tiny negative regression slope may be projected to B=0 with ideal frequency refit; this is an explicit constrained approximation, not evidence that B is physically zero.

Acceptance requires at least four orders, gcd=1, residual RMS ≤1.5 cents, every residual ≤3 cents, ≥80% explained retained peak power, no detected competing resolved peak and B≤0.01. Sensitivity proxy is `max(0.2, residual_RMS)/sqrt(sum((d_n-mean(d))²))`, where `d_n = (600/ln2)n²/(1+B n²)`. It must be ≤max(2e-6,0.4B). This derivative-based proxy is **not a statistical confidence interval**. Quality `explained * exp(-RMS/2)` is a heuristic score, not a probability. Four consecutive fits must agree within 2 cents and max(20% B,2e-6). All rejected/warming reasons remain visible.

The algorithm cannot prove which physical key was played if a neighboring key falls inside the frequency association gate. The user must isolate a single key. Unresolved coupled strings, bridges, longitudinal modes, decay, low SNR and room/device processing can violate this model. A0/C8 test points are exploratory; C8 at low B failed identifiability and is correctly rejected. It is not an 88-key reliable mechanical calibration claim.

## Individual target model

Production pure-Dart `StretchCurve.solve` runs only on explicit Generate, independently of audio callback/UI drawing. This small non-realtime calculation avoids another JNI model representation; tests and the app use the same solver. Define `g(n,B)=n sqrt((1+B n²)/(1+B))`, so `f_n=f1*g(n,B)`. Positive B spreads upper partials; exact ET octaves cannot align all relevant partial pairs. Different measured B values imply different compromises.

For each supported MIDI key let x be cents from ET. Minimize

`sum_edges w [x_j-x_i - {1200 log2(g(n_i,B_i)/g(n_j,B_j))-100(j-i)}]² + .002 sum x² + .05 sum (x_(k+1)-x_k)²`, with `x_69=0`.

Edges: octave 2:1 weight 1, octave 4:2 weight .25, double octave 4:1 weight .1, multiplied by sample/interpolation quality. Positive-definite regularized least squares is solved by Cholesky. These weights, ET prior and continuity penalty are documented engineering assumptions, not a validated auditory optimum or a complete beat/discomfort model. B is treated as constant for small tuning changes; significant tension changes require new measurements.

At least five valid samples including A4, spanning ≥36 semitones with support on both sides of A4 (at/below57 and at/above81), and no adjacent gap >12 semitones are required. Interpolate log(B+1e-6) only **inside** measured support. Default six A keys give A1–A6, 61 targets, **not 88 calibrated keys**. Each B is marked measured/interpolated; **every target first-partial frequency is modeled**, including measured keys. No extrapolation: outside the support, UI explicitly falls back to ET. Zero B yields ET and A4 remains exactly the chosen reference.

## Workflow, storage and resampling

Create/select a matching mechanical profile → enter Experimental → select a key → explicitly start microphone → inspect quality/reason/partial orders → accept a fresh ready sample, retry/remove/undo if needed → Save draft → Generate when enough data → inspect curve/table → explicitly Apply saved targets. Permission is requested only after Start. Entering calibration stops preceding capture/reference; route return never silently resumes them. Reference playback uses the active target first-partial frequency and keeps the existing capture/output mutual exclusion.

Changing samples clears any generated/active curve. A4/type/profile/target/page changes invalidate ongoing acquisition; backgrounding stops resources. Saving after background completion can finish the file operation but cannot revive capture/apply. Every save checks the profile archive revision. Active curve selection is transient and requires explicit application; loading a file does not enable it.

An already stretched key may lie >60 cents from ET. Compatible historical model targets may therefore be explicitly chosen as **search hints**, each bounded within ET ±150 cents; the original ±60 association window still applies around that center. Every accepted such sample records associationHz and the known model version. Dirty drafts retain hints for further resampling, but hints cannot drive the gauge target/reference or masquerade as an active curve. After reload without an active curve, hints default off. A4/type mismatch starts a new compatible calibration, retaining old history without applying it.

Archive schema2 reads legacy schema1 metadata without rewriting until Save. Calibration stores source (`android_microphone` entry or clearly isolated `synthetic_test` fixtures), UTC, session/sequence/time, actual rate/backend/preset, partials/fit, algorithm versions, curve and historical association provenance. This is not an acoustic authenticity signature. Unknown nested algorithms are read-only schema errors and cannot be downgraded through a backup. Stored targets are recomputed and compared on read; malformed/altered data is rejected. UTF-8 encoded archive limit is 1 MiB, max64 profiles. Oversized saves leave the existing file intact. See [profile storage](piano-profiles.md).

## Audio/ABI boundary

The real-time callback remains unchanged: bounded preallocated SPSC PCM copy and counters only. Worker-only FFT/regression uses the new analyzer; stop closes input then joins worker before analyzer release. Discontinuities reset temporal consistency. No FFT, allocation, locks, JNI or UI calls were added to callbacks.

`nativePartialStart(JZDID)` carries session/unprocessed request/A4/MIDI/association center in an immutable admitted Android request. Existing `nativeStart(JZDZ)` stays compatible. ABI4 shares metadata0…47 with ABI3; field48 reason,49 idealHz,50 fitted firstHz,51 B,52 RMS cents,53 sensitivity,54 explained power,55 stable frames,56 peak count,57 partial count,58 window seconds,59 selected MIDI,60 observed firstHz (0 if absent),61 algorithm1,62/63 reserved0. Then exactly `4*count` scalars: order,observedHz,relativePower,residualCents. Array length≤128. No waveform/spectrum transfer in this mode. Parsing validates finite values, ranges, count/order consistency, model agreement, source key and session/sequence/age. Invalid 0Hz never enters a logarithm.

The first window needs750ms and first stable four-frame result about1050ms. Partial startup timeout is1500ms, not the general500ms. Queue gaps may permit **one bounded1200ms refill interval** only for known empty warming snapshots; repeated gaps cannot extend it. A valid old snapshot still expires at250ms. This deliberately slower calibration mode does not retune Explore/Guitar's accepted tracker or their display behavior.

## References and authorship

- Rigaud, David & Daudet, [A Parametric Model of Piano Tuning, DAFx2011](https://www.dafx.de/paper-archive/2011/Papers/53_e.pdf).
- Rigaud, David & Daudet, [JASA2013 author manuscript, DOI10.1121/1.4799806](https://www.institut-langevin.espci.fr/IMG/pdf/2013_a_parametric_model_and_estimation_techniques_for_the_inharmonicity_and_tuning_of_the_piano.pdf).
- Gràcia & Sanz-Perela, [The wave equation for stiff strings and piano tuning](https://arxiv.org/abs/1603.05516).

Stiff-string theory, partial matching, least squares and the prior YIN/pYIN algorithms are existing research, not project inventions. This implementation combines them with explicit rejection, provenance, bounded realtime integration and reproducible tests. No paper code, NMF implementation, copyrighted piano recording or soundfont was copied. [Preregistered protocol](m3-protocol.md) · [Validation results](validation.md).
