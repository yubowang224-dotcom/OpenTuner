import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../model/gauge_reading.dart';

/// Display interpolation only. Feed accepted measurements, never raw PCM.
/// Retargets from the current rendered position, including mid-animation.
class TuningGauge extends StatefulWidget {
  const TuningGauge({
    super.key,
    required this.reading,
    required this.targetNote,
    this.live = false,
    this.visualCents,
    this.referenceId,
    this.referenceCaption,
    this.detectedCaption,
    this.minimal = false,
  });
  final GaugeReading reading;
  final String targetNote;
  final bool live;
  final double? visualCents;
  final String? referenceId;

  /// When supplied, the large note is the reference, with measured note below.
  final String? referenceCaption;
  final String? detectedCaption;
  final bool minimal;

  @override
  State<TuningGauge> createState() => _TuningGaugeState();
}

class _TuningGaugeState extends State<TuningGauge>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _referenceFade;
  late final Listenable _dialAnimation;
  late GaugeReading _shownReading;
  late String _shownTarget;
  String? _shownReference, _shownCaption;
  bool _fadingOut = false, _transitioning = false;
  double _begin = 0, _end = 0;
  double get _position =>
      _begin +
      (_end - _begin) * Curves.easeOutCubic.transform(_controller.value);
  String? get _nextReference =>
      widget.referenceId ??
      (widget.targetNote == '—' ? null : widget.targetNote);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.live ? 32 : 160),
    );
    _referenceFade = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 60),
    );
    _dialAnimation = Listenable.merge([_controller, _referenceFade]);
    _referenceFade.addStatusListener(_fadeStatus);
    _sync(jump: true);
  }

  void _sync({required bool jump}) {
    final current = _position;
    _shownReading = widget.reading;
    _shownTarget = widget.targetNote;
    _shownReference = _nextReference;
    _shownCaption = widget.referenceCaption;
    _begin = jump
        ? (widget.reading.cents ?? widget.visualCents ?? 0).clamp(-50, 50)
        : current;
    _end = (widget.reading.cents ?? widget.visualCents ?? 0).clamp(-50, 50);
    if (jump) {
      _controller.stop();
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  void _fadeStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.dismissed && _fadingOut) {
      // Change note AND coordinate only while the needle is invisible. New
      // snapshots replace the pending destination without restarting fade-out.
      setState(() {
        _fadingOut = false;
        _sync(jump: true);
      });
      _referenceFade.forward();
    } else if (status == AnimationStatus.completed && _transitioning) {
      setState(() {
        _transitioning = false;
      });
    }
  }

  void _cancelFade() {
    _fadingOut = false;
    _transitioning = false;
    _referenceFade.stop();
    _referenceFade.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _cancelFade();
      _sync(jump: true);
    }
  }

  @override
  void didUpdateWidget(TuningGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final differentReference = _shownReference != _nextReference;
    final changed =
        oldWidget.reading.cents != widget.reading.cents ||
        oldWidget.reading.validity != widget.reading.validity ||
        oldWidget.visualCents != widget.visualCents;
    if (!widget.reading.isValid || MediaQuery.disableAnimationsOf(context)) {
      final wasTransitioning = _transitioning;
      if (wasTransitioning) _cancelFade();
      if (changed ||
          differentReference ||
          wasTransitioning ||
          MediaQuery.disableAnimationsOf(context)) {
        _sync(
          jump: differentReference || MediaQuery.disableAnimationsOf(context),
        );
      } else {
        _shownReading = widget.reading;
        _shownTarget = widget.targetNote;
        _shownCaption = widget.referenceCaption;
      }
    } else if (widget.live && differentReference && _shownReference != null) {
      if (!_fadingOut) {
        final position = _position;
        _controller.stop();
        _begin = position;
        _end = position;
        _fadingOut = true;
        _transitioning = true;
        _referenceFade.reverse();
      }
    } else {
      if (_fadingOut) {
        _fadingOut = false;
        _referenceFade.forward();
      }
      if (changed || differentReference) {
        _sync(jump: widget.live && differentReference);
      } else {
        _shownReading = widget.reading;
        _shownTarget = widget.targetNote;
        _shownCaption = widget.referenceCaption;
      }
    }
  }

  @override
  void dispose() {
    _referenceFade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context), r = _shownReading;
    final value = r.cents;
    final status = !r.isValid
        ? (r.validity == PitchValidity.uncertain
              ? s.uncertain
              : widget.live
              ? s.noClearPitch
              : s.waitingAudio)
        : _transitioning
        ? s.switchingReference
        : value! < -50
        ? s.flatOutsideRange
        : value > 50
        ? s.sharpOutsideRange
        : value < -3
        ? s.flat
        : value > 3
        ? s.sharp
        : s.inTune;
    final centsText = value == null
        ? '—'
        : '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}';
    final referenceCenter = widget.referenceCaption != null;
    final centerNote = r.isValid && referenceCenter
        ? _shownTarget
        : r.note ?? '—';
    final demo = r.source == ReadingSource.demonstration;
    return Semantics(
      key: const ValueKey('gauge-semantics'),
      label: referenceCenter
          ? s.referenceGaugeSemantics(
              _shownTarget,
              r.note ?? '—',
              '$centsText ${s.centsUnit}',
              status,
            )
          : s.gaugeSemantics(centerNote, '$centsText ${s.centsUnit}', status),
      child: Card(
        color: widget.minimal
            ? Theme.of(context).scaffoldBackgroundColor
            : null,
        shape: widget.minimal ? const RoundedRectangleBorder() : null,
        child: Padding(
          padding: widget.minimal
              ? const EdgeInsets.symmetric(vertical: 12, horizontal: 4)
              : const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            children: [
              Text(
                _shownCaption ?? (demo ? s.demoNote : s.detectedNote),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              FadeTransition(
                opacity: _referenceFade,
                key: const ValueKey('reference-note-fade'),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    centerNote,
                    key: const ValueKey('gauge-note'),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: widget.minimal ? 96 : 64,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                      letterSpacing: -3,
                    ),
                  ),
                ),
              ),
              Text(
                widget.minimal && referenceCenter && !r.isValid
                    ? '${s.target}  $_shownTarget'
                    : referenceCenter
                    ? '${widget.detectedCaption ?? s.detectedNote}  ${r.note ?? '—'}'
                    : '${s.target}  $_shownTarget',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: widget.minimal ? 520 : 420,
                ),
                child: AspectRatio(
                  aspectRatio: 1.8,
                  child: AnimatedBuilder(
                    animation: _dialAnimation,
                    builder: (context, child) => CustomPaint(
                      key: const ValueKey('gauge-dial'),
                      painter: DialPainter(
                        cents: _position,
                        active: r.isValid,
                        needleOpacity: _referenceFade.value,
                        colors: Theme.of(context).colorScheme,
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                '$centsText ${s.centsUnit}',
                key: const ValueKey('gauge-cents'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                status,
                key: const ValueKey('gauge-status'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: r.isValid && !_transitioning
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Public immutable painter allows deterministic animation/geometry tests.
class DialPainter extends CustomPainter {
  const DialPainter({
    required this.cents,
    required this.active,
    this.needleOpacity = 1,
    this.colors,
  });
  final double cents;
  final bool active;
  final double needleOpacity;
  final ColorScheme? colors;

  @override
  void paint(Canvas canvas, Size size) {
    final scheme = colors ?? const ColorScheme.light();
    final center = Offset(size.width / 2, size.height - 12);
    final radius = math.min(size.width / 2 - 20, size.height - 28);
    final circle = Rect.fromCircle(center: center, radius: radius);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = scheme.outline;
    canvas.drawArc(circle, math.pi, math.pi, false, arc);
    canvas.drawArc(
      circle,
      math.pi * 1.47,
      math.pi * .06,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = active ? scheme.primary : scheme.outlineVariant,
    );
    for (var i = -50; i <= 50; i += 5) {
      final angle = math.pi + (i + 50) / 100 * math.pi;
      final major = i % 25 == 0;
      final outer =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 10);
      final inner =
          center +
          Offset(math.cos(angle), math.sin(angle)) *
              (radius - (major ? 24 : 17));
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..strokeWidth = major ? 1.5 : 1
          ..color = i == 0 ? scheme.primary : scheme.onSurfaceVariant,
      );
      if (major) {
        final label = TextPainter(
          text: TextSpan(
            text: i > 0 ? '+$i' : '$i',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Roboto',
              color: scheme.onSurfaceVariant,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final anchor =
            center + Offset(math.cos(angle), math.sin(angle)) * (radius + 12);
        label.paint(canvas, anchor - Offset(label.width / 2, label.height / 2));
      }
    }
    final angle = math.pi + (cents.clamp(-50, 50) + 50) / 100 * math.pi;
    final tip =
        center + Offset(math.cos(angle), math.sin(angle)) * (radius - 36);
    final needleColor = (active ? scheme.primary : scheme.onSurfaceVariant)
        .withValues(alpha: (active ? 1 : .3) * needleOpacity);
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = needleColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 6, Paint()..color = needleColor);
    canvas.drawCircle(
      center,
      2.2,
      Paint()..color = scheme.surface.withValues(alpha: needleOpacity),
    );
  }

  @override
  bool shouldRepaint(DialPainter oldDelegate) =>
      oldDelegate.cents != cents ||
      oldDelegate.active != active ||
      oldDelegate.needleOpacity != needleOpacity ||
      oldDelegate.colors != colors;
}
