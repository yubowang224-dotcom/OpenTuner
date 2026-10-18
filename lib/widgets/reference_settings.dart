import 'package:flutter/material.dart';

import '../model/app_state.dart';
import '../l10n/generated/app_localizations.dart';

class ReferenceSettings extends StatefulWidget {
  const ReferenceSettings({super.key, required this.state});
  final AppState state;
  @override
  State<ReferenceSettings> createState() => _ReferenceSettingsState();
}

class _ReferenceSettingsState extends State<ReferenceSettings> {
  late double last = widget.state.referenceHz;
  late final text = TextEditingController(text: last.toString());
  // Horizontal text scrolling must not borrow the page vertical offset.
  final inputScroll = ScrollController(keepScrollOffset: false);
  bool invalid = false;
  @override
  void didUpdateWidget(ReferenceSettings old) {
    super.didUpdateWidget(old);
    if (last != widget.state.referenceHz) {
      last = widget.state.referenceHz;
      text.text = last.toString();
      invalid = false;
    }
  }

  @override
  void dispose() {
    text.dispose();
    inputScroll.dispose();
    super.dispose();
  }

  void apply() {
    final value = double.tryParse(text.text.trim());
    if (value == null || !value.isFinite || value < 400 || value > 480) {
      setState(() => invalid = true);
      return;
    }
    setState(() => invalid = false);
    widget.state.setReferenceHz(value);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.referenceSetting,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('reference-a4'),
              scrollController: inputScroll,
              controller: text,
              enabled: !widget.state.profiles.busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'A4 · Hz',
                errorText: invalid ? s.referenceInvalid : null,
              ),
              onSubmitted: (_) => apply(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('reference-apply'),
              onPressed: widget.state.profiles.busy ? null : apply,
              child: Text(s.applyReference),
            ),
            Text(
              s.referenceCalibrationNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
