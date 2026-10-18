import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../model/app_state.dart';
import '../model/gauge_reading.dart';
import '../model/guitar_tuning.dart';
import '../widgets/common.dart';
import '../widgets/tuning_gauge.dart';
import 'audio_capture.dart';
import 'capture_status.dart';
import 'reference_player.dart';

class GuitarPage extends StatefulWidget {
  const GuitarPage({
    super.key,
    required this.state,
    required this.reference,
    this.capture,
  });
  final AppState state;
  final ReferencePlayer reference;
  final AudioCapture? capture;
  @override
  State<GuitarPage> createState() => _GuitarPageState();
}

class _GuitarPageState extends State<GuitarPage> with WidgetsBindingObserver {
  late final capture =
      widget.capture ?? AudioCapture(referenceHz: widget.state.referenceHz);
  late final tuner = GuitarTuner(
    capture: capture,
    selected: widget.state.guitarString,
    preset: widget.state.selectedGuitarPreset,
  );
  bool _cooldown = false, _wasPlaying = false;
  Timer? _tail;
  int _intent = 0, _presetGeneration = 0;
  final _presetMenu = ExpansibleController();
  bool _changingPreset = false;
  bool _presetChanged = false;
  Future<void> _changePreset(String id) async {
    if (id == tuner.preset.id) return;
    ++_intent;
    final token = ++_presetGeneration;
    setState(() {
      _changingPreset = true;
      _presetChanged = true;
    });
    // stop() invalidates pending polls and clears current synchronously before
    // any new target can render. Wait for native close before allowing restart.
    final stoppedCapture = capture.stop();
    final stoppedTone = widget.reference.stop();
    widget.state.selectGuitarPreset(id);
    tuner.setPreset(widget.state.selectedGuitarPreset);
    await Future.wait([stoppedCapture, stoppedTone]);
    if (mounted && token == _presetGeneration) {
      setState(() => _changingPreset = false);
    }
  }

  void _selectTarget(VoidCallback change) {
    // A target/mode change supersedes pending and currently sounding references.
    ++_intent;
    if (widget.reference.active) unawaited(widget.reference.stop());
    change();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.reference.addListener(_referenceChanged);
  }

  void _referenceChanged() {
    if (!mounted) return;
    if (widget.reference.active) {
      _wasPlaying = true;
      _tail?.cancel();
      _cooldown = true;
      if (capture.active) unawaited(capture.stop());
    } else if (_wasPlaying) {
      _wasPlaying = false;
      _tail?.cancel();
      _tail = Timer(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => _cooldown = false);
      });
    }
    setState(() {});
  }

  Future<void> _play() async {
    final token = ++_intent;
    if (widget.reference.active) {
      await widget.reference.stop();
      return;
    }
    final target = tuner.target;
    if (target == null) return;
    await capture.stop();
    if (!mounted || token != _intent) return;
    await widget.reference.play(
      target.note,
      target.frequency(widget.state.referenceHz),
      timbre: ReferenceTimbre.guitar,
      gain: widget.state.guitarGain,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ].contains(state)) {
      ++_intent;
      unawaited(capture.stop(CaptureStatus.background));
    }
  }

  @override
  void dispose() {
    ++_intent;
    _tail?.cancel();
    _presetMenu.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.reference.removeListener(_referenceChanged);
    tuner.dispose();
    if (widget.capture == null) {
      capture.dispose();
    } else {
      unawaited(capture.stop());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: tuner,
    builder: (context, _) {
      final s = AppLocalizations.of(context), state = widget.state;
      final r = capture.current, target = tuner.target, cents = tuner.cents;
      final reading = cents != null
          ? GaugeReading.tracked(
              note: r!.note!.replaceAll('♯', '#'),
              cents: cents,
            )
          : r != null && !r.silent
          ? const GaugeReading.uncertain()
          : const GaugeReading.waiting();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!state.minimal)
            PageHeading(title: s.guitarTitle, subtitle: s.guitarLiveSubtitle),
          ExpansionTile(
            key: const PageStorageKey<String>('guitar-preset-selector-v1'),
            controller: _presetMenu,
            title: Text(
              presetLabel(tuner.preset.id, s),
              key: const ValueKey('guitar-preset'),
            ),
            subtitle: Text(s.guitarPreset),
            children: [
              for (final preset in guitarPresets)
                ListTile(
                  key: ValueKey('preset-option-${preset.id}'),
                  selected: tuner.preset.id == preset.id,
                  title: Text(presetLabel(preset.id, s)),
                  onTap: _changingPreset
                      ? null
                      : () {
                          _presetMenu.collapse();
                          unawaited(_changePreset(preset.id));
                        },
                ),
            ],
          ),
          if (_presetChanged)
            Text(s.presetRestart, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: const ValueKey('guitar-manual'),
                label: Text(s.manualTarget),
                selected: !tuner.automatic,
                onSelected: (_) =>
                    _selectTarget(() => tuner.setAutomatic(false)),
              ),
              ChoiceChip(
                key: const ValueKey('guitar-auto'),
                label: Text(s.autoTarget),
                selected: tuner.automatic,
                onSelected: (_) =>
                    _selectTarget(() => tuner.setAutomatic(true)),
              ),
            ],
          ),
          Text(
            captureStatusLabel(capture.status, s),
            key: const ValueKey('capture-status'),
          ),
          TuningGauge(
            key: const ValueKey('guitar-live-gauge'),
            live: true,
            minimal: state.minimal,
            reading: reading,
            targetNote: target?.note ?? '—',
            referenceId: target == null
                ? null
                : '${state.referenceHz}:${tuner.preset.id}:${target.note}',
            referenceCaption: target == null
                ? s.autoTarget
                : s.stringLabel(target.number),
          ),
          if (tuner.automatic && r?.valid == true && cents == null)
            Text(
              tuner.matchState == GuitarMatchState.ambiguous
                  ? s.guitarAmbiguous
                  : tuner.matchState == GuitarMatchState.outside
                  ? s.guitarOutside
                  : s.guitarConfirming,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('capture-toggle'),
            onPressed:
                !capture.bridge.supported ||
                    _changingPreset ||
                    widget.reference.active ||
                    _cooldown
                ? null
                : capture.active
                ? capture.stop
                : () {
                    ++_intent;
                    setState(() => _presetChanged = false);
                    capture.start();
                  },
            icon: Icon(
              capture.active ? Icons.stop_rounded : Icons.mic_outlined,
            ),
            label: Text(capture.active ? s.stopGuitar : s.startGuitar),
          ),
          if (capture.status == CaptureStatus.permissionSettings ||
              capture.status == CaptureStatus.permissionRevoked)
            TextButton(
              onPressed: capture.openSettings,
              child: Text(s.openAppSettings),
            ),
          const SizedBox(height: 12),
          if (state.minimal)
            DropdownButton<int>(
              key: const ValueKey('guitar-focus-target'),
              value: tuner.selected,
              isExpanded: true,
              hint: Text(s.target),
              items: List.generate(
                6,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(
                    '${tuner.preset.strings[i].note} · ${s.stringLabel(tuner.preset.strings[i].number)}',
                  ),
                ),
              ),
              onChanged: (i) {
                if (i != null) {
                  _selectTarget(() {
                    state.selectString(i);
                    tuner.manual(i);
                  });
                }
              },
            )
          else
            LayoutBuilder(
              builder: (context, box) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(6, (i) {
                  final t = tuner.preset.strings[i];
                  return SizedBox(
                    width: (box.maxWidth - 16) / 3,
                    child: ChoiceChip(
                      key: ValueKey('guitar-target-$i'),
                      label: Text(
                        '${t.note}\n${s.stringLabel(t.number)}',
                        textAlign: TextAlign.center,
                      ),
                      selected: tuner.selected == i,
                      onSelected: (_) {
                        _selectTarget(() {
                          state.selectString(i);
                          tuner.manual(i);
                        });
                      },
                    ),
                  );
                }),
              ),
            ),
          const SizedBox(height: 12),
          if (!state.minimal || widget.reference.active) ...[
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${target?.note ?? '—'} · ${tuner.targetHz?.toStringAsFixed(2) ?? '—'} Hz',
                ),
                OutlinedButton.icon(
                  key: const ValueKey('reference-toggle'),
                  onPressed:
                      !widget.reference.bridge.supported ||
                          target == null ||
                          _changingPreset
                      ? null
                      : _play,
                  icon: Icon(
                    widget.reference.active
                        ? Icons.stop_rounded
                        : Icons.volume_up_outlined,
                  ),
                  label: Text(
                    widget.reference.active ? s.stopReference : s.playReference,
                  ),
                ),
              ],
            ),
            Text(
              !widget.reference.bridge.supported
                  ? s.referenceUnsupported
                  : widget.reference.state == ReferenceStatus.error
                  ? s.referenceError
                  : s.guitarReferenceSafety,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(s.guitarVoice),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    key: const ValueKey('guitar-reference-gain'),
                    value: state.guitarGain,
                    divisions: 20,
                    label: '${(state.guitarGain * 100).round()}%',
                    semanticFormatterCallback: (v) =>
                        s.synthVolume((v * 100).round()),
                    onChanged: _changingPreset
                        ? null
                        : (value) =>
                              _selectTarget(() => state.setGuitarGain(value)),
                  ),
                ),
                Text('${(state.guitarGain * 100).round()}%'),
              ],
            ),
            Text(
              s.synthVolumeNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (!state.minimal) ...[
            const SizedBox(height: 12),
            Card(
              key: const ValueKey('measurement-details'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DetailRow(
                      label: s.detectedNote,
                      value: r?.valid == true
                          ? r!.note!.replaceAll('♯', '#')
                          : '—',
                    ),
                    DetailRow(
                      label: s.measuredFrequency,
                      value: capture.displayHz == null
                          ? '—'
                          : '${capture.displayHz!.toStringAsFixed(1)} Hz',
                    ),
                    DetailRow(
                      label: s.target,
                      value:
                          '${target?.note ?? '—'} · ${tuner.targetHz?.toStringAsFixed(2) ?? '—'} Hz',
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
                    if (r?.clipped == true) Text(s.clippingWarning),
                    Text(
                      s.scoreNotice,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Text(
              s.guitarAutoNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      );
    },
  );
}

String presetLabel(String id, AppLocalizations s) => switch (id) {
  'standard' => s.standardTuning,
  'dropD' => s.presetDropD,
  'dStandard' => s.presetDStandard,
  'halfDown' => s.presetHalfDown,
  'dadgad' => s.presetDadgad,
  'openD' => s.presetOpenD,
  'openG' => s.presetOpenG,
  _ => throw ArgumentError.value(id),
};
