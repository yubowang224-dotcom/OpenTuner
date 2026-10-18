import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../model/app_state.dart';
import '../model/gauge_reading.dart';
import '../widgets/common.dart';
import '../widgets/tuning_gauge.dart';
import 'audio_capture.dart';
import 'capture_status.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, required this.state, this.capture});
  final AppState state;

  /// Explicit test seam; the production app never injects synthesized audio.
  final AudioCapture? capture;
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> with WidgetsBindingObserver {
  late final AudioCapture capture =
      widget.capture ?? AudioCapture(referenceHz: widget.state.referenceHz);
  bool _minimal = false;
  final _detailsController = ExpansibleController();
  @override
  void initState() {
    super.initState();
    _minimal = widget.state.minimal;
    _detailsController.addListener(_restoreDetails);
    WidgetsBinding.instance.addObserver(this);
  }

  void _restoreDetails() {
    // Expansible can restore its bool during build. Synchronize the transport
    // after that frame, including navigation restores, without notifying during
    // a descendant's initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !widget.state.minimal &&
          capture.details != _detailsController.isExpanded) {
        capture.setDetails(_detailsController.isExpanded);
      }
    });
  }

  @override
  void didUpdateWidget(ExplorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.minimal != _minimal) {
      _minimal = widget.state.minimal;
      if (_minimal) {
        _detailsController.collapse();
        capture.setDetails(false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      capture.stop(CaptureStatus.background);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detailsController.dispose();
    if (widget.capture == null) {
      capture.dispose();
    } else {
      capture.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: capture,
    builder: (context, _) {
      final s = AppLocalizations.of(context);
      final r = capture.current;
      final reading = r?.valid == true
          ? GaugeReading.tracked(note: r!.note!, cents: capture.displayCents!)
          : r != null && !r.silent
          ? const GaugeReading.uncertain()
          : const GaugeReading.waiting();
      final status = captureStatusLabel(capture.status, s);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.state.minimal)
            PageHeading(title: s.exploreTitle, subtitle: s.exploreSubtitle),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                status,
                key: const ValueKey('capture-status'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Tooltip(
                message: s.lockReferenceNotice,
                child: TextButton.icon(
                  key: const ValueKey('reference-lock'),
                  onPressed: capture.referenceLocked
                      ? capture.unlockReference
                      : r?.valid == true
                      ? () => capture.lockReference()
                      : null,
                  icon: Icon(
                    capture.referenceLocked
                        ? Icons.lock_open_rounded
                        : Icons.lock_outline_rounded,
                  ),
                  label: Text(
                    capture.referenceLocked
                        ? s.unlockReference(capture.referenceNote ?? '—')
                        : s.lockReference(capture.referenceNote ?? '—'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TuningGauge(
            key: const ValueKey('live-gauge'),
            minimal: widget.state.minimal,
            visualCents: capture.visualCents,
            reading: reading,
            targetNote: capture.referenceNote ?? '—',
            referenceId: capture.referenceMidi == null
                ? null
                : '${capture.referenceHz}:${capture.referenceMidi}',
            referenceCaption: capture.referenceLocked
                ? s.lockedReference
                : s.automaticReference,
            live: true,
          ),
          const SizedBox(height: 12),
          if (widget.state.minimal)
            Text(
              '${capture.displayHz?.toStringAsFixed(1) ?? '—'} Hz',
              key: const ValueKey('focus-frequency'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          FilledButton.icon(
            key: const ValueKey('capture-toggle'),
            onPressed: !capture.bridge.supported
                ? null
                : capture.active
                ? capture.stop
                : capture.start,
            icon: Icon(
              capture.active ? Icons.stop_rounded : Icons.mic_outlined,
            ),
            label: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                capture.active ? s.stopCapture : s.startCapture,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (capture.status == CaptureStatus.permissionSettings ||
              capture.status == CaptureStatus.permissionRevoked)
            TextButton(
              onPressed: capture.openSettings,
              child: Text(s.openAppSettings),
            ),
          if (!widget.state.minimal) ...[
            const SizedBox(height: 12),
            Text(
              s.capturePrivacy,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DetailRow(
                      label: s.measuredFrequency,
                      value: capture.displayHz == null
                          ? '—'
                          : '${capture.displayHz!.toStringAsFixed(1)} Hz',
                    ),
                    DetailRow(
                      label: s.signalLevel,
                      value: r == null
                          ? '—'
                          : '${r.dbfs.toStringAsFixed(1)} dBFS',
                    ),
                    DetailRow(
                      label: s.algorithmScore,
                      value: r == null ? '—' : r.score.toStringAsFixed(3),
                    ),
                    if (r?.clipped == true)
                      Text(
                        s.clippingWarning,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Text(
                      s.scoreNotice,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ExpansionTile(
                // Separate bool expansion storage from the ancestor ListView's
                // double scroll offset. Never remove this PageStorageKey.
                key: const PageStorageKey<String>('explore-live-details-v25'),
                controller: _detailsController,
                title: Text(s.liveDetails),
                onExpansionChanged: capture.setDetails,
                childrenPadding: const EdgeInsets.all(16),
                children: capture.details
                    ? [
                        const SizedBox(height: 12),
                        Text(s.waveform),
                        SizedBox(
                          width: double.infinity,
                          height: 120,
                          child: CustomPaint(
                            key: const ValueKey('live-waveform'),
                            painter: SignalPainter(
                              r?.wave ?? const [],
                              false,
                              colors: Theme.of(context).colorScheme,
                              sampled: r?.sampledWave ?? false,
                              xMaximum: r?.waveMs ?? 20,
                            ),
                          ),
                        ),
                        Text(
                          r == null || r.wave.isEmpty
                              ? s.realDataOnly
                              : '${r.sampledWave ? s.sampledPcm : s.envelopePcm} · 0–${r.waveMs.toStringAsFixed(2)} ms',
                        ),
                        if (r?.sampledWave == true && r!.wave.isNotEmpty)
                          DetailRow(
                            label: s.waveTiming,
                            value:
                                '${r.waveStartMs.toStringAsFixed(1)}–${r.waveEndMs.toStringAsFixed(1)} ms · Δt ${r.waveStepMs.toStringAsFixed(4)} ms',
                          ),
                        if (r?.sampledWave == true && r!.wave.isNotEmpty)
                          Text(
                            r.waveTriggered ? s.waveTriggered : s.waveFree,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        const SizedBox(height: 20),
                        Text(s.spectrum),
                        SizedBox(
                          width: double.infinity,
                          height: 130,
                          child: CustomPaint(
                            key: const ValueKey('live-spectrum'),
                            painter: SignalPainter(
                              r?.spectrum ?? const [],
                              true,
                              colors: Theme.of(context).colorScheme,
                              xMaximum: r == null || r.spectrum.isEmpty
                                  ? 0
                                  : (r.spectrum.length - 1) * r.binHz,
                            ),
                          ),
                        ),
                        Text(
                          r == null || r.spectrum.isEmpty
                              ? s.realDataOnly
                              : '0–${((r.spectrum.length - 1) * r.binHz).toStringAsFixed(0)} Hz · −120–0 dBFS',
                        ),
                        Text(
                          s.spectrumNotice,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (r != null) ...[
                          DetailRow(
                            label: s.audioConfiguration,
                            value:
                                '${r.sampleRate} Hz · mono · float32 · ${r.backend}',
                          ),
                          DetailRow(
                            label: s.trackedFrequency,
                            value: r.trackedHz == null
                                ? '—'
                                : '${r.trackedHz!.toStringAsFixed(3)} Hz',
                          ),
                          DetailRow(
                            label: s.noiseFloor,
                            value: r.noiseKnown
                                ? '${r.noiseFloorDb!.toStringAsFixed(1)} dBFS / ${r.levelMarginDb!.toStringAsFixed(1)} dB'
                                : '—',
                          ),
                          DetailRow(
                            label: s.spectralFeatures,
                            value: r.centroidHz == null
                                ? '—'
                                : '${r.centroidHz!.toStringAsFixed(0)} Hz / ${r.harmonicRatio!.toStringAsFixed(3)}',
                          ),
                          DetailRow(
                            label: s.trackingFeatures,
                            value:
                                '${r.candidateCount ?? '—'} / ${r.trackerState}',
                          ),
                          DetailRow(
                            label: s.rawFrequency,
                            value: r.rawHz == null
                                ? '—'
                                : '${r.rawHz!.toStringAsFixed(2)} Hz',
                          ),
                          DetailRow(
                            label: s.bufferInfo,
                            value:
                                '${r.values[18].toInt()} / ${r.values[19].toInt()} ${s.framesUnit}',
                          ),
                          DetailRow(
                            label: s.droppedSamples,
                            value: '${r.dropped}',
                          ),
                          DetailRow(
                            label: s.inputPreset,
                            value: r.values[28] == 9
                                ? 'UNPROCESSED'
                                : 'VOICE_RECOGNITION',
                          ),
                          Text(
                            s.processingUnknown,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ]
                    : const [],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class SignalPainter extends CustomPainter {
  const SignalPainter(
    this.data,
    this.spectrum, {
    this.colors,
    this.sampled = false,
    this.xMaximum = 0,
  });
  final ColorScheme? colors;
  final List<double> data;
  final bool spectrum, sampled;
  final double xMaximum;
  double get amplitude =>
      data.fold<double>(.01, (a, b) => a > b.abs() ? a : b.abs()) * 1.15;
  @override
  void paint(Canvas canvas, Size size) {
    final scheme = colors ?? const ColorScheme.light();
    final plot = Rect.fromLTRB(42, 12, size.width - 12, size.height - 24);
    void label(String text, Offset point, {bool center = false}) {
      final p = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'Roboto',
            color: scheme.onSurfaceVariant,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, point - Offset(center ? p.width / 2 : 0, 0));
    }

    final grid = Paint()
      ..color = scheme.outlineVariant
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      canvas.drawLine(
        Offset(plot.left, plot.top + plot.height * i / 4),
        Offset(plot.right, plot.top + plot.height * i / 4),
        grid,
      );
      canvas.drawLine(
        Offset(plot.left + plot.width * i / 4, plot.top),
        Offset(plot.left + plot.width * i / 4, plot.bottom),
        grid,
      );
      if (i.isEven) {
        label(
          (xMaximum * i / 4).toStringAsFixed(spectrum ? 0 : 1),
          Offset(plot.left + plot.width * i / 4, plot.bottom + 5),
          center: true,
        );
      }
    }
    label(
      spectrum ? '0' : '+${amplitude.toStringAsPrecision(2)}',
      Offset(0, plot.top),
    );
    label(spectrum ? '−60' : '0', Offset(0, plot.center.dy - 5));
    label(
      spectrum ? '−120' : '−${amplitude.toStringAsPrecision(2)}',
      Offset(0, plot.bottom - 8),
    );
    if (!spectrum) {
      canvas.drawLine(
        Offset(plot.left, plot.center.dy),
        Offset(plot.right, plot.center.dy),
        Paint()..color = scheme.outline,
      );
    }
    if (data.isEmpty) return;
    final pen = Paint()
      ..color = scheme.primary
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    if (spectrum || sampled) {
      if (data.length < 2) return;
      final path = Path();
      for (var i = 0; i < data.length; i++) {
        final x = plot.left + i * plot.width / (data.length - 1);
        final y = spectrum
            ? plot.top - data[i].clamp(-120, 0) / 120 * plot.height
            : plot.center.dy - data[i] / amplitude * plot.height / 2;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, pen);
    } else {
      // Legacy ABI1/2 contains min/max pairs, never reinterpret them as PCM.
      final bins = data.length ~/ 2;
      for (var i = 0; i < bins; i++) {
        final x = plot.left + (i + .5) * plot.width / bins;
        canvas.drawLine(
          Offset(x, plot.center.dy - data[i * 2] / amplitude * plot.height / 2),
          Offset(
            x,
            plot.center.dy - data[i * 2 + 1] / amplitude * plot.height / 2,
          ),
          pen,
        );
      }
    }
  }

  @override
  bool shouldRepaint(SignalPainter old) =>
      old.data != data ||
      old.spectrum != spectrum ||
      old.colors != colors ||
      old.sampled != sampled ||
      old.xMaximum != xMaximum;
}
