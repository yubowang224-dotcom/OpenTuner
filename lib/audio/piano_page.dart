import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../model/app_state.dart';
import '../model/piano_model.dart';
import '../model/gauge_reading.dart';
import '../model/guitar_tuning.dart' show targetCents;
import '../widgets/common.dart';
import '../widgets/tuning_gauge.dart';
import '../widgets/piano_profiles.dart';
import 'audio_capture.dart';
import 'capture_status.dart';
import 'reference_player.dart';
import 'calibration_page.dart';

class PianoPage extends StatefulWidget {
  const PianoPage({
    super.key,
    required this.state,
    required this.reference,
    this.capture,
  });
  final AppState state;
  final ReferencePlayer reference;
  final AudioCapture? capture;
  @override
  State<PianoPage> createState() => _PianoPageState();
}

class _PianoPageState extends State<PianoPage> with WidgetsBindingObserver {
  late final capture =
      widget.capture ??
      AudioCapture(
        piano: true,
        partialMidi: widget.state.pianoPartialMeasurement
            ? pianoKey(widget.state.pianoNote).midi
            : null,
        associationHz: widget.state.pianoPartialMeasurement
            ? widget.state.pianoTargetHz
            : null,
        referenceHz: widget.state.referenceHz,
      );
  int intent = 0;
  Timer? tail;
  bool cooldown = false, wasPlaying = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.reference.addListener(referenceChanged);
  }

  void referenceChanged() {
    if (!mounted) return;
    if (widget.reference.active) {
      wasPlaying = true;
      tail?.cancel();
      cooldown = true;
      if (capture.active) unawaited(capture.stop());
    } else if (wasPlaying) {
      wasPlaying = false;
      tail?.cancel();
      tail = Timer(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => cooldown = false);
      });
    }
    setState(() {});
  }

  Future<void> play() async {
    final token = ++intent;
    if (widget.reference.active) {
      await widget.reference.stop();
      return;
    }
    final target = pianoKey(widget.state.pianoNote);
    final frequency = widget.state.pianoTargetHz;
    await capture.stop();
    if (!mounted || token != intent) return;
    await widget.reference.play(target.note, frequency);
  }

  Future<void> openCalibration() async {
    final profile = widget.state.profiles.selected;
    if (profile == null ||
        profile.kind == PianoKind.digital ||
        profile.a4 != widget.state.referenceHz ||
        profile.kind != widget.state.pianoKind) {
      return;
    }
    final token = ++intent;
    await capture.stop();
    await widget.reference.stop();
    if (!mounted || token != intent) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalibrationPage(state: widget.state, profile: profile),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ].contains(state)) {
      ++intent;
      unawaited(capture.stop(CaptureStatus.background));
    }
  }

  @override
  void dispose() {
    ++intent;
    tail?.cancel();
    widget.reference.removeListener(referenceChanged);
    WidgetsBinding.instance.removeObserver(this);
    if (widget.capture == null) {
      capture.dispose();
    } else {
      unawaited(capture.stop());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: capture,
    builder: (context, _) {
      final s = AppLocalizations.of(context),
          state = widget.state,
          key = pianoKey(state.pianoNote),
          r = capture.current;
      final hz = state.pianoTargetHz,
          cents = r?.valid == true ? targetCents(r!.trackedHz!, hz) : null;
      final reading = cents != null
          ? GaugeReading.tracked(
              note: r!.note!.replaceAll('♯', '#'),
              cents: cents,
            )
          : r != null && !r.silent
          ? const GaugeReading.uncertain()
          : const GaugeReading.waiting();
      final octave = key.midi ~/ 12 - 1;
      void choose(int midi) {
        state.selectPianoNote(PianoKey(midi).note);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!state.minimal)
            PageHeading(
              title: s.pianoTitle,
              subtitle: state.pianoCurve != null
                  ? s.calPianoSubtitle
                  : s.pianoLiveSubtitle,
            ),
          Wrap(
            spacing: 8,
            children: [
              for (final kind in PianoKind.values)
                ChoiceChip(
                  key: ValueKey('piano-kind-${kind.name}'),
                  label: Text(pianoKindText(kind, s)),
                  selected: state.pianoKind == kind,
                  onSelected: (_) => state.setPianoKind(kind),
                ),
            ],
          ),
          Text(
            captureStatusLabel(capture.status, s),
            key: const ValueKey('piano-capture-status'),
          ),
          if (state.pianoKind != PianoKind.digital)
            Text(
              state.pianoCurve != null
                  ? s.calExperimental
                  : s.pianoMechanicalNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (state.pianoCurve case final curve?) ...[
            Text(state.pianoPartialMeasurement ? s.calActive : s.calOutside),
            if (!state.minimal)
              Text(
                s.calCurveRange(
                  pianoKeyFromMidi(curve.low),
                  pianoKeyFromMidi(curve.high),
                ),
              ),
            if (!state.minimal && state.pianoCurve?.point(key.midi) != null)
              Text(
                '${s.calTargetModel} ${state.pianoCurve!.point(key.midi)!.measuredB ? s.calBMeasured : s.calBInterpolated}',
              ),
            if (state.profiles.selected?.calibration?.samples.any(
                  (p) => p.source == 'synthetic_test',
                ) ==
                true)
              Text(s.calSourceSynthetic),
            if (r?.partialFrame != null)
              Text(
                r!.partialFrame!.observedFirstHz == null
                    ? s.calFirstInferred
                    : s.calFirstObserved,
              ),
            if (!state.minimal)
              TextButton(
                key: const ValueKey('piano-curve-disable'),
                onPressed: state.clearPianoCurve,
                child: Text(s.calDisable),
              ),
          ],
          TuningGauge(
            key: const ValueKey('piano-live-gauge'),
            detectedCaption: state.pianoPartialMeasurement
                ? s.calNearestEt
                : null,
            reading: reading,
            targetNote: key.note,
            referenceCaption:
                '${s.calSelectedKey} · ${s.pianoKeyNumber(key.number)}',
            referenceId: 'piano:${state.referenceHz}:${key.midi}',
            live: true,
            minimal: state.minimal,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('piano-capture-toggle'),
            onPressed:
                !capture.bridge.supported || widget.reference.active || cooldown
                ? null
                : capture.active
                ? capture.stop
                : capture.start,
            icon: Icon(
              capture.active ? Icons.stop_rounded : Icons.mic_outlined,
            ),
            label: Text(capture.active ? s.stopCapture : s.startCapture),
          ),
          if (capture.status == CaptureStatus.permissionSettings ||
              capture.status == CaptureStatus.permissionRevoked)
            TextButton(
              onPressed: capture.openSettings,
              child: Text(s.openAppSettings),
            ),
          const SizedBox(height: 12),
          Text(s.pianoManualNotice),
          Wrap(
            spacing: 6,
            children: [
              for (int oct = 0; oct <= 8; oct++)
                ChoiceChip(
                  key: ValueKey('piano-octave-$oct'),
                  label: Text(s.pianoOctave(oct)),
                  selected: octave == oct,
                  onSelected: (_) => choose(
                    oct == 0
                        ? 21
                        : oct == 8
                        ? 108
                        : (oct + 1) * 12,
                  ),
                ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final note in pianoKeys.where(
                (n) => n.midi ~/ 12 - 1 == octave,
              ))
                ChoiceChip(
                  key: ValueKey('piano-target-${note.note}'),
                  label: Text(note.note),
                  selected: note.midi == key.midi,
                  onSelected: (_) => choose(note.midi),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                key: const ValueKey('piano-lowest'),
                onPressed: () => choose(21),
                child: Text(s.pianoLowest),
              ),
              TextButton(
                key: const ValueKey('piano-a4'),
                onPressed: () => choose(69),
                child: const Text('A4'),
              ),
              TextButton(
                key: const ValueKey('piano-highest'),
                onPressed: () => choose(108),
                child: Text(s.pianoHighest),
              ),
            ],
          ),
          if (!state.minimal || widget.reference.active) ...[
            Text('${key.note} · ${hz.toStringAsFixed(3)} Hz'),
            OutlinedButton.icon(
              key: const ValueKey('reference-toggle'),
              onPressed: widget.reference.bridge.supported ? play : null,
              icon: Icon(
                widget.reference.active
                    ? Icons.stop_rounded
                    : Icons.volume_up_outlined,
              ),
              label: Text(
                widget.reference.active ? s.stopReference : s.playReference,
              ),
            ),
            Text(
              !widget.reference.bridge.supported
                  ? s.referenceUnsupported
                  : widget.reference.state == ReferenceStatus.error
                  ? s.referenceError
                  : s.pianoReferenceSafety,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (!state.minimal) ...[
            DetailRow(
              label: state.pianoPartialMeasurement
                  ? s.calNearestEt
                  : s.detectedNote,
              value: r?.valid == true ? r!.note!.replaceAll('♯', '#') : '—',
            ),
            DetailRow(
              label: s.measuredFrequency,
              value: capture.displayHz == null
                  ? '—'
                  : '${capture.displayHz!.toStringAsFixed(2)} Hz',
            ),
            DetailRow(
              label: s.target,
              value: '${key.note} · ${hz.toStringAsFixed(3)} Hz',
            ),
            DetailRow(
              label: s.signalLevel,
              value: r == null ? '—' : '${r.dbfs.toStringAsFixed(1)} dBFS',
            ),
            DetailRow(
              label: state.pianoPartialMeasurement
                  ? s.calFitScore
                  : s.algorithmScore,
              value: r == null ? '—' : r.score.toStringAsFixed(3),
            ),
            if (r != null) Text('${r.sampleRate} Hz · ${r.backend}'),
            Text(
              state.pianoPartialMeasurement
                  ? s.calLiveNotice
                  : s.pianoAnalysisNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (state.pianoPartialMeasurement) ...[
              Text(s.calFitScoreNotice),
              Text(s.calIdentityNotice),
            ],
            PianoProfiles(state: state),
            if (state.pianoKind != PianoKind.digital) ...[
              const SizedBox(height: 16),
              Text(s.calExperimental),
              if (state.profiles.selected == null ||
                  state.profiles.selected?.kind != state.pianoKind ||
                  state.profiles.selected?.a4 != state.referenceHz)
                Text(s.calNeedProfile),
              OutlinedButton(
                key: const ValueKey('piano-calibrate'),
                onPressed:
                    state.profiles.writable &&
                        state.profiles.selected?.kind == state.pianoKind &&
                        state.profiles.selected?.a4 == state.referenceHz
                    ? openCalibration
                    : null,
                child: Text(s.calOpen),
              ),
              if (state.profiles.selected?.calibration?.curve != null)
                OutlinedButton(
                  key: const ValueKey('piano-curve-apply'),
                  onPressed:
                      state.profiles.writable &&
                          state.profiles.selected?.calibration?.a4 ==
                              state.referenceHz &&
                          state.profiles.selected?.calibration?.kind ==
                              state.pianoKind.name
                      ? () {
                          state.applyPianoCurve(state.profiles.selected!.id);
                        }
                      : null,
                  child: Text(s.calApply),
                ),
            ],
          ],
        ],
      );
    },
  );
}

String pianoKeyFromMidi(int midi) => PianoKey(midi).note;
