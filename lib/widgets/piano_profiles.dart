import 'package:flutter/material.dart';

import '../model/app_state.dart';
import '../model/piano_model.dart';
import '../model/profile_store.dart';
import '../l10n/generated/app_localizations.dart';

String pianoKindText(PianoKind kind, AppLocalizations s) => switch (kind) {
  PianoKind.digital => s.digitalPiano,
  PianoKind.upright => s.uprightPiano,
  PianoKind.grand => s.grandPiano,
};
String profileIssueText(ProfileIssue? issue, AppLocalizations s) =>
    switch (issue) {
      null => s.profileReady,
      ProfileIssue.unsupported => s.profileUnsupported,
      ProfileIssue.unavailable => s.profileUnavailable,
      ProfileIssue.corrupt => s.profileCorrupt,
      ProfileIssue.schema => s.profileSchema,
      ProfileIssue.conflict => s.profileConflict,
      ProfileIssue.invalid => s.profileInvalid,
      ProfileIssue.recovered => s.profileRecovered,
      ProfileIssue.capacity => s.profileCapacity,
    };

class PianoProfiles extends StatefulWidget {
  const PianoProfiles({super.key, required this.state});
  final AppState state;
  @override
  State<PianoProfiles> createState() => _PianoProfilesState();
}

class _PianoProfilesState extends State<PianoProfiles> {
  final name = TextEditingController();
  String? confirmedFor;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context),
        state = widget.state,
        manager = state.profiles;
    final selected = manager.selected;
    String token() =>
        '${manager.selected?.id}:${manager.archive.revision}:${manager.operation}';
    final confirmed = confirmedFor == token();
    final matches =
        selected != null &&
        selected.a4 == state.referenceHz &&
        selected.kind == state.pianoKind &&
        PianoKey(selected.midi).note == state.pianoNote;
    return ExpansionTile(
      key: const PageStorageKey<String>('piano-profile-list-v1'),
      title: Text(s.pianoProfiles),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        Text(s.profileDataNotice),
        Text(
          manager.busy
              ? s.profileBusy
              : profileIssueText(
                  manager.store.supported
                      ? manager.issue
                      : ProfileIssue.unsupported,
                  s,
                ),
          key: const ValueKey('profile-status'),
        ),
        if (selected != null)
          Text(matches ? s.profileMatches : s.profileModified),
        if (manager.store.supported) ...[
          TextField(
            // EditableText's internal Scrollable must not read this tile's bool.
            key: const PageStorageKey<String>('profile-name'),
            controller: name,
            enabled: !manager.busy,
            decoration: InputDecoration(labelText: s.profileName),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                key: const ValueKey('profile-create'),
                onPressed: manager.writable
                    ? () async {
                        final ok = await manager.create(
                          name.text,
                          state.pianoKind,
                          state.referenceHz,
                          pianoKey(state.pianoNote).midi,
                        );
                        if (ok && mounted) name.clear();
                      }
                    : null,
                child: Text(s.profileCreate),
              ),
              TextButton(
                key: const ValueKey('profile-reload'),
                onPressed: manager.busy ? null : manager.load,
                child: Text(s.profileReload),
              ),
              if (manager.archive.recovered)
                OutlinedButton(
                  key: const ValueKey('profile-recover'),
                  onPressed: manager.busy ? null : manager.recover,
                  child: Text(s.profileRecover),
                ),
            ],
          ),
          for (final profile in manager.archive.profiles)
            ListTile(
              key: ValueKey('profile-${profile.id}'),
              selected: selected?.id == profile.id,
              title: Text(profile.name),
              subtitle: Text(
                '${pianoKindText(profile.kind, s)} · A4 ${profile.a4} Hz · ${PianoKey(profile.midi).note}',
              ),
              onTap: manager.writable
                  ? () async {
                      await state.loadPianoProfile(profile.id);
                    }
                  : null,
            ),
          if (selected != null) ...[
            CheckboxListTile(
              key: const ValueKey('profile-confirm-update'),
              title: Text(s.profileConfirmUpdate),
              value: confirmed,
              onChanged: manager.writable
                  ? (value) => setState(
                      () => confirmedFor = value == true ? token() : null,
                    )
                  : null,
            ),
            OutlinedButton(
              key: const ValueKey('profile-update'),
              onPressed: manager.writable && confirmed
                  ? () async {
                      if (confirmedFor != token()) return;
                      await manager.update(
                        selected.id,
                        name.text.trim().isEmpty ? selected.name : name.text,
                        state.pianoKind,
                        state.referenceHz,
                        pianoKey(state.pianoNote).midi,
                        confirmed: confirmed,
                      );
                      if (mounted) setState(() => confirmedFor = null);
                    }
                  : null,
              child: Text(s.profileUpdate),
            ),
          ],
        ],
      ],
    );
  }
}
