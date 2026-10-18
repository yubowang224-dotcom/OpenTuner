import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';
import 'audio/reference_player.dart';
import 'model/app_state.dart';
import 'model/gauge_reading.dart';
import 'widgets/common.dart';
import 'widgets/tuning_gauge.dart';
import 'widgets/reference_settings.dart';

// Structured target preview only. Full tuning presets belong to stage 3.
const guitarTargets = [
  (6, 'E2'),
  (5, 'A2'),
  (4, 'D3'),
  (3, 'G3'),
  (2, 'B3'),
  (1, 'E4'),
];
const pianoPreviewNotes = ['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5'];

class TunerPage extends StatelessWidget {
  const TunerPage({
    super.key,
    required this.state,
    required this.piano,
    required this.reference,
  });
  final AppState state;
  final bool piano;
  final ReferencePlayer reference;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final target = piano
        ? state.pianoNote
        : guitarTargets[state.guitarString].$2;
    final reading = state.demo
        ? GaugeReading.demonstration(note: target, cents: state.demoCents)
        : const GaugeReading.waiting();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!state.minimal)
          PageHeading(
            title: piano ? s.pianoTitle : s.guitarTitle,
            subtitle: piano ? s.pianoSubtitle : s.guitarSubtitle,
          ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Text(
              piano ? s.pianoTarget : s.standardTuning,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            StatusPill(
              label: state.demo ? s.demoOn : s.audioNotConnected,
              highlight: state.demo,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TuningGauge(
          reading: reading,
          targetNote: target,
          minimal: state.minimal,
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: reference,
          builder: (context, _) => Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                '${reference.active ? reference.note : target} · ${(reference.active ? reference.hz! : noteFrequency(target, state.referenceHz)).toStringAsFixed(2)} Hz',
              ),
              OutlinedButton.icon(
                key: const ValueKey('reference-toggle'),
                onPressed: !reference.bridge.supported
                    ? null
                    : reference.active
                    ? reference.stop
                    : () => reference.play(
                        target,
                        noteFrequency(target, state.referenceHz),
                      ),
                icon: Icon(
                  reference.active
                      ? Icons.stop_rounded
                      : Icons.volume_up_outlined,
                ),
                label: Text(
                  reference.active ? s.stopReference : s.playReference,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (piano)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pianoPreviewNotes
                .map(
                  (note) => ChoiceChip(
                    key: ValueKey('piano-target-$note'),
                    label: Text(note),
                    selected: state.pianoNote == note,
                    onSelected: (_) {
                      state.selectPianoNote(note);
                      reference.play(
                        note,
                        noteFrequency(note, state.referenceHz),
                      );
                    },
                  ),
                )
                .toList(),
          )
        else
          LayoutBuilder(
            builder: (context, box) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(guitarTargets.length, (i) {
                final (number, note) = guitarTargets[i];
                return SizedBox(
                  width: (box.maxWidth - 16) / 3,
                  child: Semantics(
                    label: s.targetSemantics(s.stringLabel(number), note),
                    selected: i == state.guitarString,
                    child: ChoiceChip(
                      key: ValueKey('guitar-target-$i'),
                      label: SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            Text(
                              note,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              s.stringLabel(number),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      selected: i == state.guitarString,
                      onSelected: (_) {
                        state.selectString(i);
                        reference.play(
                          note,
                          noteFrequency(note, state.referenceHz),
                        );
                      },
                    ),
                  ),
                );
              }),
            ),
          ),
        if (!state.minimal) ...[
          const SizedBox(height: 10),
          Text(
            piano ? s.pianoRangeNotice : s.targetOnly,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: reference,
          builder: (context, _) => Text(
            !reference.bridge.supported
                ? s.referenceUnsupported
                : reference.state == ReferenceStatus.error
                ? s.referenceError
                : s.referenceSafety,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 20),
        if (state.minimal) ...[
          Text(
            s.audioStageNotice,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (state.demo)
            TextButton(
              onPressed: () => state.setDemo(false),
              child: Text(s.demoOff),
            ),
        ] else ...[
          DemoControls(state: state),
          const SizedBox(height: 16),
          Card(
            key: const ValueKey('measurement-details'),
            child: ExpansionTile(
              key: PageStorageKey('details-${piano ? 'piano' : 'guitar'}'),
              title: Text(s.details),
              shape: const Border(),
              collapsedShape: const Border(),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                DetailRow(label: s.measuredFrequency, value: s.notMeasured),
                DetailRow(label: s.target, value: target),
                DetailRow(
                  label: s.referencePitch,
                  value: 'A4 = ${state.referenceHz.toStringAsFixed(1)} Hz',
                ),
                DetailRow(label: s.confidence, value: s.notMeasured),
                Text(
                  s.audioStageNotice,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (piano) ...[
            const SizedBox(height: 20),
            DropdownButtonFormField<PianoKind>(
              key: const ValueKey('piano-kind'),
              initialValue: state.pianoKind,
              decoration: InputDecoration(labelText: s.pianoType),
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: PianoKind.digital,
                  child: Text(s.digitalPiano),
                ),
                DropdownMenuItem(
                  value: PianoKind.upright,
                  child: Text(s.uprightPiano),
                ),
                DropdownMenuItem(
                  value: PianoKind.grand,
                  child: Text(s.grandPiano),
                ),
              ],
              onChanged: (value) {
                if (value != null) state.setPianoKind(value);
              },
            ),
            const SizedBox(height: 16),
            if (state.pianoKind == PianoKind.digital)
              Text(
                s.electronicNotice,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            InfoCard(
              icon: Icons.piano_outlined,
              title: s.professionalTitle,
              body: s.professionalNotice,
              trailing: StatusPill(label: s.planned),
            ),
          ],
        ],
      ],
    );
  }
}

class DemoControls extends StatelessWidget {
  const DemoControls({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const ValueKey('demo-toggle'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                s.demoTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(s.demoDescription),
              value: state.demo,
              onChanged: state.setDemo,
            ),
            if (state.demo) ...[
              const SizedBox(height: 8),
              Text(s.demoOffset(state.demoCents.toStringAsFixed(1))),
              Slider(
                key: const ValueKey('demo-slider'),
                min: -50,
                max: 50,
                value: state.demoCents,
                label: s.demoOffset(state.demoCents.toStringAsFixed(1)),
                semanticFormatterCallback: (value) =>
                    s.demoOffset(value.toStringAsFixed(1)),
                onChanged: state.setDemoCents,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading(title: s.settingsTitle, subtitle: s.settingsSubtitle),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'language-${state.locale?.languageCode ?? 'system'}',
                  ),
                  initialValue: state.locale?.languageCode ?? 'system',
                  decoration: InputDecoration(labelText: s.language),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: 'system',
                      child: Text(s.followSystem),
                    ),
                    DropdownMenuItem(value: 'zh', child: Text(s.chinese)),
                    DropdownMenuItem(value: 'en', child: Text(s.english)),
                  ],
                  onChanged: (v) =>
                      state.setLocale(v == 'system' ? null : Locale(v!)),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  key: const ValueKey('settings-minimal'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.minimalMode),
                  subtitle: Text(s.minimalDescription),
                  value: state.minimal,
                  onChanged: state.setMinimal,
                ),
                const Divider(),
                DropdownButtonFormField<ThemeMode>(
                  key: ValueKey('theme-${state.themeMode.name}'),
                  initialValue: state.themeMode,
                  decoration: InputDecoration(labelText: s.appearance),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text(s.followSystem),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text(s.lightTheme),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text(s.darkTheme),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) state.setThemeMode(v);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  state.preferencesError
                      ? s.preferencesFailed
                      : !state.preferencesPersistent
                      ? s.preferencesSessionOnly
                      : state.preferencesSaving
                      ? s.preferencesSaving
                      : s.preferencesSaved,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ReferenceSettings(state: state),
        const SizedBox(height: 16),
        InfoCard(
          icon: Icons.lock_outline_rounded,
          title: s.privacyTitle,
          body: s.privacyDescription,
        ),
        const SizedBox(height: 16),
        InfoCard(
          icon: Icons.construction_outlined,
          title: s.availability,
          body: s.availabilityDescription,
        ),
        const SizedBox(height: 16),
        InfoCard(
          icon: Icons.info_outline_rounded,
          title: s.about,
          body:
              '${s.versionLabel}\n${s.licenseLabel}\n\n${s.referencePitchNotice}',
        ),
        TextButton.icon(
          key: const ValueKey('acknowledgements-link'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AcknowledgementsPage(),
            ),
          ),
          icon: const Icon(Icons.favorite_border_rounded),
          label: Text(s.acknowledgements),
        ),
        TextButton.icon(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: s.appTitle,
            applicationVersion: s.versionLabel,
          ),
          icon: const Icon(Icons.article_outlined),
          label: Text(s.openSourceLicenses),
        ),
      ],
    );
  }
}

class AcknowledgementsPage extends StatelessWidget {
  const AcknowledgementsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.acknowledgements)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              s.acknowledgementsBody,
              key: const ValueKey('acknowledgements-body'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              s.acknowledgementsAttribution,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            SelectableText(
              s.sourcePublicationPending,
              key: const ValueKey('source-repository'),
            ),
          ],
        ),
      ),
    );
  }
}
