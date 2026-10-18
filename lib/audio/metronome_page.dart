import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../model/app_state.dart';
import '../widgets/common.dart';
import 'metronome_player.dart';

class MetronomePage extends StatefulWidget {
  const MetronomePage({super.key, required this.state, this.player});
  final AppState state;
  final MetronomePlayer? player;
  @override
  State<MetronomePage> createState() => _MetronomePageState();
}

class _MetronomePageState extends State<MetronomePage> {
  late final player = widget.player ?? MetronomePlayer();
  final tap = TapTempo();
  final clock = Stopwatch()..start();
  MetroConfig get config => MetroConfig(
    bpm: widget.state.bpm,
    beats: int.parse(widget.state.meter.split('/')[0]),
    denominator: int.parse(widget.state.meter.split('/')[1]),
    divisions: widget.state.subdivision + 1,
    accent: widget.state.accent,
    gain: widget.state.metroGain,
  );
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_configure);
  }

  void _configure() => player.configure(config);
  @override
  void dispose() {
    widget.state.removeListener(_configure);
    if (widget.player == null) {
      player.dispose();
    } else {
      player.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.state, player]),
    builder: (context, _) {
      final s = AppLocalizations.of(context), state = widget.state;
      final actual = player.current;
      final shown = actual?.config ?? config;
      final status = player.status == 'unsupported'
          ? s.metronomeUnsupported
          : player.status == 'playing'
          ? s.metronomePlaying
          : player.status == 'paused'
          ? s.metronomePaused
          : ['pausing', 'resuming'].contains(player.status)
          ? s.metronomeTransition
          : player.status == 'starting'
          ? s.metronomeStarting
          : player.status == 'idle'
          ? s.metronomeStopped
          : s.metronomeInterrupted;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeading(
            title: s.metronomeTitle,
            subtitle: s.metronomeLiveSubtitle,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(status, key: const ValueKey('metro-status')),
                  Text(
                    '${state.bpm}',
                    key: const ValueKey('bpm-value'),
                    style: const TextStyle(
                      fontSize: 76,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -4,
                    ),
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      const ExcludeSemantics(
                        child: Icon(Icons.music_note_rounded, size: 18),
                      ),
                      Text(s.quarterBpm),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        key: const ValueKey('bpm-decrease'),
                        tooltip: s.slower,
                        onPressed: state.bpm > 20
                            ? () => state.setBpm(state.bpm - 1)
                            : null,
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Expanded(
                        child: Slider(
                          key: const ValueKey('bpm-slider'),
                          min: 20,
                          max: 300,
                          divisions: 280,
                          value: state.bpm.toDouble(),
                          semanticFormatterCallback: (v) =>
                              s.tempoValue(v.round()),
                          onChanged: (v) => state.setBpm(v.round()),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('bpm-increase'),
                        tooltip: s.faster,
                        onPressed: state.bpm < 300
                            ? () => state.setBpm(state.bpm + 1)
                            : null,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(
                      shown.beats,
                      (i) => Semantics(
                        label: s.metroBeat(i + 1),
                        selected: actual?.beat == i,
                        child: Container(
                          key: ValueKey('beat-$i'),
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: actual?.beat == i
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: actual?.beat == i
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    actual == null
                        ? '—'
                        : '${shown.beats}/${shown.denominator} · ${actual.beat + 1} / ${shown.beats} · ${actual.division + 1} / ${shown.divisions}',
                    key: const ValueKey('metro-position'),
                  ),
                  if (actual?.pending == true ||
                      actual != null && actual.config != config)
                    Text(s.metronomePending),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('metro-toggle'),
                    onPressed:
                        !player.bridge.supported ||
                            [
                              'starting',
                              'pausing',
                              'resuming',
                            ].contains(player.status)
                        ? null
                        : player.status == 'playing'
                        ? player.pause
                        : player.status == 'paused'
                        ? player.resume
                        : () => player.start(config),
                    icon: Icon(
                      player.status == 'playing'
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      player.status == 'playing'
                          ? s.pauseMetronome
                          : player.status == 'paused'
                          ? s.resumeMetronome
                          : s.startMetronome,
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('metro-stop'),
                    onPressed: player.active ? player.stop : null,
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(s.stopMetronome),
                  ),
                  Text(
                    s.metronomeTransportNotice,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextButton.icon(
                    key: const ValueKey('tap-tempo'),
                    onPressed: () {
                      final bpm = tap.tap(clock.elapsedMilliseconds);
                      if (bpm != null) state.setBpm(bpm);
                    },
                    icon: const Icon(Icons.touch_app_outlined),
                    label: Text(s.tapQuarter),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(s.synthVolume(state.metroGain)),
          Slider(
            key: const ValueKey('metro-gain'),
            value: state.metroGain.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            semanticFormatterCallback: (value) => s.synthVolume(value.round()),
            onChanged: (value) => state.setMetroGain(value.round()),
          ),
          Text(
            s.metroVolumeNotice,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const ValueKey('meter-select'),
            initialValue: state.meter,
            decoration: InputDecoration(labelText: s.timeSignature),
            items: [
              '2/4',
              '3/4',
              '4/4',
              '6/8',
            ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) {
              if (v != null) state.setMeter(v);
            },
          ),
          SwitchListTile(
            key: const ValueKey('metro-accent'),
            contentPadding: EdgeInsets.zero,
            title: Text(s.metroAccent),
            value: state.accent,
            onChanged: state.setAccent,
          ),
          Text(s.subdivisionsPerPulse),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              4,
              (i) => ChoiceChip(
                key: ValueKey('metro-division-$i'),
                label: Text('${i + 1}'),
                selected: state.subdivision == i,
                onSelected: (_) => state.setSubdivision(i),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.metronomeClockNotice,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (actual != null)
            Text(
              '${actual.rate} Hz · ${actual.frames} samples',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      );
    },
  );
}
