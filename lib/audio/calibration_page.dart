import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../model/app_state.dart';
import '../model/piano_model.dart';
import '../model/piano_calibration.dart';
import '../widgets/common.dart';
import '../widgets/piano_profiles.dart';
import 'audio_capture.dart';
import 'capture_status.dart';

String partialReason(int reason, AppLocalizations s) => switch (reason) {
  0 => s.calReason0,
  1 => s.calReason1,
  2 => s.calReason2,
  3 => s.calReason3,
  4 => s.calReason4,
  5 => s.calReason5,
  6 => s.calReason6,
  7 => s.calReason7,
  8 => s.calReason8,
  9 => s.calReason9,
  _ => s.calReason10,
};

class CalibrationPage extends StatefulWidget {
  const CalibrationPage({
    super.key,
    required this.state,
    required this.profile,
    this.captureFactory,
    this.measurementSource = 'android_microphone',
  });
  final AppState state;
  final PianoProfile profile;
  // Test injection only. Production creates Android continuous PCM capture.
  final AudioCapture Function(int midi, double a4, double? associationHz)?
  captureFactory;
  final String measurementSource;
  @override
  State<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<CalibrationPage>
    with WidgetsBindingObserver {
  late PianoCalibration data;
  late AudioCapture capture;
  late int midi, revision;
  late final String initialRootNote;
  late final Map<int, double> hints;
  bool usingHints = false;
  final undo = <List<PianoMeasurement>>[];
  bool busy = false, saved = false, stale = false, error = false;
  int intent = 0;
  AudioCapture makeCapture(int midi) =>
      widget.captureFactory?.call(
        midi,
        data.a4,
        usingHints ? hints[midi] : null,
      ) ??
      AudioCapture(
        partialMidi: midi,
        referenceHz: data.a4,
        associationHz: usingHints ? hints[midi] : null,
      );
  @override
  void initState() {
    super.initState();
    final p = widget.profile, old = p.calibration, now = DateTime.now().toUtc();
    data = old != null && old.a4 == p.a4 && old.kind == p.kind.name
        ? old
        : PianoCalibration(
            a4: p.a4,
            kind: p.kind.name,
            created: now,
            updated: now,
            samples: [],
          );
    saved = identical(data, old);
    hints = data.searchHints;
    usingHints = hints.isNotEmpty && widget.state.pianoCurve != null;
    initialRootNote = widget.state.pianoNote;
    midi = pianoKey(initialRootNote).midi;
    revision = widget.state.profiles.archive.revision;
    capture = makeCapture(midi);
    widget.state.addListener(configurationChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void configurationChanged() {
    final state = widget.state, p = state.profiles.selected;
    if (!stale &&
        (state.page != 1 ||
            state.pianoNote != initialRootNote ||
            state.referenceHz != data.a4 ||
            state.pianoKind.name != data.kind ||
            p?.id != widget.profile.id ||
            p?.a4 != data.a4 ||
            p?.kind.name != data.kind)) {
      ++intent;
      stale = true;
      unawaited(capture.stop());
      if (mounted) setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if ([
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ].contains(value)) {
      ++intent;
      unawaited(capture.stop(CaptureStatus.background));
    }
  }

  Future<void> select(int value, {bool? enableHints}) async {
    if (busy || stale || value == midi && enableHints == null) return;
    final token = ++intent;
    setState(() => busy = true);
    await capture.stop();
    if (!mounted || token != intent) {
      if (mounted) setState(() => busy = false);
      return;
    }
    capture.dispose();
    setState(() {
      midi = value;
      usingHints = enableHints ?? usingHints;
      capture = makeCapture(value);
      busy = false;
      error = false;
    });
  }

  void change(List<PianoMeasurement> next) {
    widget.state.clearPianoCurve();
    undo.add(data.samples);
    if (undo.length > 16) undo.removeAt(0);
    data = data.withSamples(next);
    saved = false;
    error = false;
  }

  Future<void> accept() async {
    final r = capture.current, p = r?.partialFrame;
    if (stale ||
        busy ||
        r?.valid != true ||
        p?.ready != true ||
        r!.values[59] != midi) {
      return;
    }
    final sample = PianoMeasurement(
      id: PianoProfile.newId(),
      midi: midi,
      captured: DateTime.now().toUtc(),
      source: widget.measurementSource,
      rate: r.sampleRate,
      backend: widget.measurementSource == 'synthetic_test'
          ? 'synthetic'
          : r.backend,
      preset: r.values[28].toInt(),
      session: r.session,
      sequence: r.sequence,
      endSeconds: r.values[3],
      frame: p!,
      associationHz: capture.associationHz,
      associationAlgorithm: capture.associationHz == null
          ? null
          : stretchAlgorithm,
    );
    setState(
      () => change(
        [...data.samples.where((s) => s.midi != midi), sample]
          ..sort((a, b) => a.midi.compareTo(b.midi)),
      ),
    );
    await capture.stop();
  }

  Future<void> save({bool apply = false}) async {
    if (busy || stale) return;
    final token = ++intent;
    setState(() => busy = true);
    await capture.stop();
    if (!mounted || token != intent) {
      if (mounted) setState(() => busy = false);
      return;
    }
    final ok = await widget.state.profiles.saveCalibration(
      widget.profile.id,
      data,
      revision,
    );
    if (!mounted) return;
    if (token != intent) {
      setState(() {
        busy = false;
        saved = ok;
        error = !ok;
        if (ok) revision = widget.state.profiles.archive.revision;
      });
      return;
    }
    setState(() {
      busy = false;
      saved = ok;
      revision = ok ? widget.state.profiles.archive.revision : revision;
      error = !ok;
    });
    if (ok && apply) {
      final applied = widget.state.applyPianoCurve(widget.profile.id);
      if (applied && mounted) {
        Navigator.of(context).pop();
      } else if (mounted) {
        setState(() => error = true);
      }
    }
  }

  bool get enough {
    final samples = [...data.samples]..sort((a, b) => a.midi.compareTo(b.midi));
    return samples.length >= 5 &&
        samples.any((s) => s.midi == 69) &&
        samples.first.midi <= 57 &&
        samples.last.midi >= 81 &&
        samples.last.midi - samples.first.midi >= 36 &&
        List.generate(
          samples.length - 1,
          (i) => samples[i + 1].midi - samples[i].midi,
        ).every((gap) => gap <= 12);
  }

  @override
  void dispose() {
    ++intent;
    widget.state.removeListener(configurationChanged);
    WidgetsBinding.instance.removeObserver(this);
    capture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context), state = widget.state;
    return Scaffold(
      appBar: AppBar(title: Text(s.calTitle)),
      body: ListenableBuilder(
        listenable: capture,
        builder: (context, _) {
          final r = capture.current, frame = r?.partialFrame;
          final sample = data.samples
              .where((sample) => sample.midi == midi)
              .firstOrNull;
          final octave = midi ~/ 12 - 1;
          return ListView(
            key: const PageStorageKey<String>('calibration-workflow-scroll'),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.profile.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '${pianoKindText(widget.profile.kind, s)} · A4 ${data.a4} Hz',
              ),
              Text(s.calExperimental),
              const SizedBox(height: 12),
              Text(s.calDataNotice),
              if (widget.profile.calibration != null &&
                  (widget.profile.calibration!.a4 != data.a4 ||
                      widget.profile.calibration!.kind != data.kind))
                Text(s.calStoredIncompatible),
              if (stale)
                Text(s.calAssociationChanged, key: const ValueKey('cal-stale')),
              const SizedBox(height: 16),
              Text(s.calSubtitle),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final key in [33, 45, 57, 69, 81, 93])
                    ActionChip(
                      key: ValueKey('cal-guide-$key'),
                      label: Text(
                        '${PianoKey(key).note}${data.samples.any((p) => p.midi == key) ? ' ✓' : ''}',
                      ),
                      onPressed: busy || stale ? null : () => select(key),
                    ),
                ],
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (var oct = 0; oct <= 8; oct++)
                    ChoiceChip(
                      key: ValueKey('cal-octave-$oct'),
                      label: Text(s.pianoOctave(oct)),
                      selected: octave == oct,
                      onSelected: busy || stale
                          ? null
                          : (_) => select(
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
                children: [
                  for (final key in pianoKeys.where(
                    (key) => key.midi ~/ 12 - 1 == octave,
                  ))
                    ChoiceChip(
                      key: ValueKey('cal-key-${key.midi}'),
                      label: Text(key.note),
                      selected: key.midi == midi,
                      onSelected: busy || stale
                          ? null
                          : (_) => select(key.midi),
                    ),
                ],
              ),
              SwitchListTile(
                key: const ValueKey('cal-use-hints'),
                title: Text(s.calUseHints),
                subtitle: Text(s.calHintsNotice),
                value: usingHints,
                onChanged: busy || stale || hints.isEmpty
                    ? null
                    : (value) => select(midi, enableHints: value),
              ),
              if (usingHints && !hints.containsKey(midi))
                Text(s.calHintUnavailable),
              Text(
                '${s.calAssociationCenter}: ${(capture.associationHz ?? PianoKey(midi).frequency(data.a4)).toStringAsFixed(3)} Hz',
              ),
              const SizedBox(height: 12),
              Text(
                '${PianoKey(midi).note} · ${PianoKey(midi).frequency(data.a4).toStringAsFixed(3)} Hz',
              ),
              Text(
                captureStatusLabel(capture.status, s),
                key: const ValueKey('cal-capture-status'),
              ),
              Text(
                frame == null
                    ? s.calSamplingNotice
                    : partialReason(frame.reason, s),
                key: const ValueKey('cal-quality-status'),
              ),
              FilledButton.icon(
                key: const ValueKey('cal-capture-toggle'),
                onPressed: busy || stale || !capture.bridge.supported
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
              if (frame != null) ...[
                if (frame.firstHz > 0)
                  Text(
                    frame.observedFirstHz == null
                        ? s.calFirstInferred
                        : s.calFirstObserved,
                    key: const ValueKey('cal-first-source'),
                  ),
                DetailRow(
                  label: s.calIdeal,
                  value: frame.idealHz > 0
                      ? '${frame.idealHz.toStringAsFixed(3)} Hz'
                      : '—',
                ),
                DetailRow(
                  label: s.calModelFirst,
                  value: frame.firstHz > 0
                      ? '${frame.firstHz.toStringAsFixed(3)} Hz'
                      : '—',
                ),
                DetailRow(
                  label: s.calObservedFirst,
                  value: frame.observedFirstHz == null
                      ? '—'
                      : '${frame.observedFirstHz!.toStringAsFixed(3)} Hz',
                ),
                DetailRow(
                  label: s.calBFit,
                  value: frame.b.toStringAsExponential(4),
                ),
                DetailRow(
                  label: s.calResidual,
                  value: frame.residual.toStringAsFixed(3),
                ),
                DetailRow(
                  label: s.calSensitivity,
                  value: frame.sensitivity.toStringAsExponential(2),
                ),
                DetailRow(
                  label: s.calExplained,
                  value: frame.explained.toStringAsFixed(3),
                ),
                DetailRow(label: s.calStable, value: '${frame.stable}'),
                Text(
                  '${s.calPartialOrders}: ${frame.partials.map((p) => p.order).join(', ')}',
                ),
                if (r != null)
                  Text(
                    '${r.sampleRate} Hz · ${r.backend} · ${r.dbfs.toStringAsFixed(1)} dBFS',
                  ),
              ],
              FilledButton(
                key: const ValueKey('cal-accept'),
                onPressed:
                    busy || stale || r?.valid != true || frame?.ready != true
                    ? null
                    : accept,
                child: Text(s.calTake),
              ),
              if (sample != null)
                Text(
                  '${PianoKey(sample.midi).note} · B ${sample.frame.b.toStringAsExponential(4)} · ${sample.captured.toIso8601String()}',
                ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    key: const ValueKey('cal-remove'),
                    onPressed: sample == null || busy || stale
                        ? null
                        : () {
                            unawaited(capture.stop());
                            setState(
                              () => change(
                                data.samples
                                    .where((p) => p.midi != midi)
                                    .toList(),
                              ),
                            );
                          },
                    child: Text(s.calRemove),
                  ),
                  TextButton(
                    key: const ValueKey('cal-undo'),
                    onPressed: undo.isEmpty || busy || stale
                        ? null
                        : () {
                            unawaited(capture.stop());
                            widget.state.clearPianoCurve();
                            setState(() {
                              data = data.withSamples(undo.removeLast());
                              saved = false;
                              error = false;
                            });
                          },
                    child: Text(s.calUndo),
                  ),
                ],
              ),
              for (final p in data.samples)
                ListTile(
                  dense: true,
                  key: ValueKey('cal-sample-${p.midi}'),
                  title: Text(
                    '${PianoKey(p.midi).note} · B ${p.frame.b.toStringAsExponential(4)}',
                  ),
                  subtitle: Text(
                    p.source == 'android_microphone'
                        ? s.calSourceMic
                        : s.calSourceSynthetic,
                  ),
                  trailing: const Icon(Icons.check_circle_outline),
                  onTap: busy || stale ? null : () => select(p.midi),
                ),
              Text(
                saved ? s.calSaved : s.calUnsaved,
                key: const ValueKey('cal-saved-status'),
              ),
              if (error) Text(s.calError),
              if (state.profiles.issue != null)
                Text(profileIssueText(state.profiles.issue, s)),
              OutlinedButton(
                key: const ValueKey('cal-save'),
                onPressed: busy || stale || !state.profiles.writable
                    ? null
                    : save,
                child: Text(s.calSave),
              ),
              if (!enough) Text(s.calInsufficient),
              FilledButton(
                key: const ValueKey('cal-generate'),
                onPressed: busy || stale || !enough
                    ? null
                    : () {
                        unawaited(capture.stop());
                        widget.state.clearPianoCurve();
                        try {
                          setState(() {
                            data = data.generate();
                            saved = false;
                            error = false;
                          });
                        } catch (_) {
                          setState(() => error = true);
                        }
                      },
                child: Text(s.calGenerate),
              ),
              if (data.curve case final curve?) ...[
                Text(
                  s.calCurveRange(
                    PianoKey(curve.low).note,
                    PianoKey(curve.high).note,
                  ),
                ),
                Text(s.calCurveCaption),
                Semantics(
                  label: s.calCurveCaption,
                  child: SizedBox(
                    height: 180,
                    child: CustomPaint(
                      key: const ValueKey('cal-curve-plot'),
                      painter: StretchPainter(
                        curve,
                        Theme.of(context).colorScheme,
                      ),
                    ),
                  ),
                ),
                Text(s.calModelNotice),
                Text(s.calTargetModel),
                ExpansionTile(
                  key: const PageStorageKey<String>('calibration-target-table'),
                  title: Text(s.calTargets),
                  children: [
                    for (final p in curve.points)
                      DetailRow(
                        label:
                            '${PianoKey(p.midi).note} · ${p.measuredB ? s.calBMeasured : s.calBInterpolated}',
                        value:
                            '${p.firstHz.toStringAsFixed(3)} Hz · ${p.cents.toStringAsFixed(2)} c',
                      ),
                  ],
                ),
                FilledButton(
                  key: const ValueKey('cal-apply'),
                  onPressed: busy || stale || !state.profiles.writable
                      ? null
                      : () => save(apply: true),
                  child: Text(s.calApply),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class StretchPainter extends CustomPainter {
  StretchPainter(this.curve, this.colors);
  final StretchCurve curve;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    final extent = math.max(
      5.0,
      curve.points.map((p) => p.cents.abs()).reduce(math.max),
    );
    Offset position(int index, double cents) => Offset(
      12 + (size.width - 24) * index / (curve.points.length - 1),
      size.height / 2 - cents / extent * (size.height / 2 - 16),
    );
    canvas.drawLine(
      position(0, 0),
      position(curve.points.length - 1, 0),
      Paint()..color = colors.outlineVariant,
    );
    final path = Path();
    for (var i = 0; i < curve.points.length; i++) {
      final p = position(i, curve.points[i].cents);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.primary
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < curve.points.length; i++) {
      if (curve.points[i].measuredB) {
        canvas.drawCircle(
          position(i, curve.points[i].cents),
          3,
          Paint()..color = colors.primary,
        );
      }
    }
    final text = TextPainter(
      text: TextSpan(
        text: '±${extent.toStringAsFixed(1)} c',
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, const Offset(0, 0));
  }

  @override
  bool shouldRepaint(StretchPainter old) =>
      old.curve != curve || old.colors != colors;
}
