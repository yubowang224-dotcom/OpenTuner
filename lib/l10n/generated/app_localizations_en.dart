// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OpenTuner';

  @override
  String get guitar => 'Guitar';

  @override
  String get piano => 'Piano';

  @override
  String get explore => 'Explore';

  @override
  String get metronome => 'Metronome';

  @override
  String get settings => 'Settings';

  @override
  String get guitarTitle => 'Find your balance.';

  @override
  String get guitarSubtitle =>
      'A quieter space for a better tuning experience.';

  @override
  String get pianoTitle => 'Every note, considered.';

  @override
  String get pianoSubtitle => 'A clear starting point for your piano.';

  @override
  String get exploreTitle => 'Get to know your sound.';

  @override
  String get exploreSubtitle => 'Hum, sing, or explore a steady note.';

  @override
  String get metronomeTitle => 'Make room for rhythm.';

  @override
  String get metronomeSubtitle => 'Set up your practice, one beat at a time.';

  @override
  String get settingsTitle => 'Just the essentials.';

  @override
  String get settingsSubtitle => 'Make OpenTuner feel like your instrument.';

  @override
  String get uiPreview => 'UI preview';

  @override
  String get audioNotConnected => 'Instrument detection planned';

  @override
  String get audioStageNotice =>
      'Detection on this instrument page is not implemented yet. Use Explore for live microphone analysis.';

  @override
  String get waitingAudio => 'Waiting for audio';

  @override
  String get uncertain => 'No stable pitch';

  @override
  String get flat => 'Flat';

  @override
  String get inTune => 'In tune';

  @override
  String get sharp => 'Sharp';

  @override
  String get centsUnit => 'cents';

  @override
  String get target => 'Target';

  @override
  String get detectedNote => 'Detected note';

  @override
  String get demoNote => 'Demo note';

  @override
  String get standardTuning => 'Standard tuning';

  @override
  String get sixStrings => '6 strings · E A D G B E';

  @override
  String get targetOnly =>
      'The guitar page supports seven six-string presets and plucked reference tones.';

  @override
  String stringLabel(int number) {
    return 'String $number';
  }

  @override
  String get minimalMode => 'Minimal mode';

  @override
  String get minimalDescription =>
      'Keep the note, needle, and essential feedback.';

  @override
  String get normalMode => 'Show details';

  @override
  String get details => 'Measurement details';

  @override
  String get measuredFrequency => 'Measured frequency';

  @override
  String get targetFrequency => 'Target frequency';

  @override
  String get confidence => 'Pitch confidence';

  @override
  String get notMeasured => 'Not measured';

  @override
  String get demoTitle => 'Try the needle';

  @override
  String get demoDescription =>
      'Visual demonstration only. No microphone or measured pitch.';

  @override
  String get demoOn => 'Demo · no audio';

  @override
  String get demoOff => 'Exit demo';

  @override
  String get demoSlider => 'Demonstration pitch offset';

  @override
  String demoOffset(String value) {
    return 'Demo offset: $value cents';
  }

  @override
  String gaugeSemantics(String note, String value, String state) {
    return 'Tuning gauge: $note, $value, $state';
  }

  @override
  String get pianoType => 'Piano type';

  @override
  String get digitalPiano => 'Digital piano';

  @override
  String get uprightPiano => 'Upright piano';

  @override
  String get grandPiano => 'Grand piano';

  @override
  String get pianoTarget => 'Target note preview';

  @override
  String get pianoRangeNotice => 'Select any of the 88 keys from A0 to C8.';

  @override
  String get electronicNotice =>
      'Digital piano mode uses equal-temperament targets. Mechanical stretch is not applied.';

  @override
  String get professionalTitle => 'Individual piano calibration';

  @override
  String get professionalNotice =>
      'Not implemented. Partial analysis and a measured stretch curve are planned. Real-piano validation will be required.';

  @override
  String get planned => 'Planned';

  @override
  String get microphoneTitle => 'Microphone is not connected';

  @override
  String get microphoneNotice =>
      'Live pitch, waveform, and spectrum will appear here after real audio capture is added. This screen does not request permission or record audio.';

  @override
  String get captureUnavailable => 'Capture not available yet';

  @override
  String get waveform => 'Waveform';

  @override
  String get spectrum => 'Spectrum';

  @override
  String get realDataOnly => 'Waiting for real samples';

  @override
  String get bpm => 'BPM';

  @override
  String get tempo => 'Tempo';

  @override
  String tempoValue(int value) {
    return '$value beats per minute';
  }

  @override
  String get slower => 'Decrease tempo';

  @override
  String get faster => 'Increase tempo';

  @override
  String get timeSignature => 'Time signature';

  @override
  String get subdivision => 'Subdivision';

  @override
  String get quarter => 'Quarter notes';

  @override
  String get eighth => 'Eighth notes';

  @override
  String get triplet => 'Triplets';

  @override
  String get sixteenth => 'Sixteenth notes';

  @override
  String get beatPreview => 'Beat layout preview';

  @override
  String get metronomeNotice =>
      'Audio-clock playback is available on Android. Start explicitly; leaving the page stops playback.';

  @override
  String get playbackUnavailable => 'Audio playback not connected';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'Follow system';

  @override
  String get english => 'English';

  @override
  String get chinese => '简体中文';

  @override
  String get appearance => 'Appearance';

  @override
  String get lightTheme => 'Light theme';

  @override
  String get sessionSettings =>
      'Language and playback settings apply to this session. Theme, focus mode and A4 are saved on Android.';

  @override
  String get privacyTitle => 'Your sound stays yours.';

  @override
  String get privacyDescription =>
      'Microphone access starts only after you explicitly start measurement. Audio stays on this device without recordings or uploads. Private piano profiles may contain measured partial frequencies, quality, device metadata and modeled tuning targets. No ads or tracking SDKs.';

  @override
  String get about => 'About OpenTuner';

  @override
  String get versionLabel =>
      'Version 0.7.0 Beta 2 · Mechanical calibration remains Experimental';

  @override
  String get licenseLabel => 'Open source · Apache License 2.0';

  @override
  String get availability => 'Feature availability';

  @override
  String get availabilityDescription =>
      'Explore and guitar retain the accepted general C++ tracker. Piano offers 88-key equal-temperament measurement and optional Experimental mechanical calibration: partial fitting, quality rejection and individually modeled targets within measured support. This is not real-piano or professional validation; outside support uses equal temperament.';

  @override
  String get referencePitch => 'Reference pitch';

  @override
  String get referencePitchNotice =>
      'Global A4 reference applies to every target and reference tone.';

  @override
  String get noPermission => 'Microphone permission has not been requested';

  @override
  String targetSemantics(String label, String note) {
    return '$label, $note';
  }

  @override
  String get localAnalysis => 'Local audio';

  @override
  String get micIdle => 'Microphone stopped · start when ready';

  @override
  String get micStarting => 'Requesting microphone / opening stream…';

  @override
  String get micRunning => 'Microphone active · live analysis';

  @override
  String get micUnsupported =>
      'Audio capture is not implemented on this platform';

  @override
  String get micDenied => 'Microphone permission denied. You can try again.';

  @override
  String get micSettings => 'Allow microphone access in Android app settings.';

  @override
  String get micRevoked =>
      'Microphone permission was revoked. Capture stopped.';

  @override
  String get micBackground =>
      'Capture stopped in background. Tap Start to resume.';

  @override
  String get micDeviceChanged =>
      'Input device changed. Capture stopped; tap Start to reopen.';

  @override
  String get micSilenced =>
      'Microphone muted or silenced by the system. Check privacy settings and other recording apps.';

  @override
  String get micInterrupted => 'Audio stream interrupted. Tap Start to reopen.';

  @override
  String get micStalled =>
      'No fresh audio arrived. Capture stopped; check the input device.';

  @override
  String get micError =>
      'Could not start or read audio. Check permissions / competing apps and try again.';

  @override
  String get startCapture => 'Start microphone';

  @override
  String get stopCapture => 'Stop microphone';

  @override
  String get openAppSettings => 'Open app settings';

  @override
  String get capturePrivacy =>
      'Audio is processed locally, without uploading or saving raw recordings. Single-source estimate: start with a steady hum, about 50–2000 Hz. Complex sound may have no clear pitch.';

  @override
  String get signalLevel => 'Digital level';

  @override
  String get algorithmScore => 'Periodicity score';

  @override
  String get scoreNotice =>
      '0–1 periodicity score, not correctness probability. Cents use the selected reference. Automatic reference uses ±55 cents hysteresis and brief boundary confirmation; raw/tracked Hz stay unchanged.';

  @override
  String get clippingWarning =>
      'Clipping detected · move farther from the microphone';

  @override
  String get liveDetails => 'Live waveform, spectrum & diagnostics';

  @override
  String get audioConfiguration => 'Actual stream';

  @override
  String get rawFrequency => 'Raw candidate';

  @override
  String get bufferInfo => 'Burst / capacity';

  @override
  String get framesUnit => 'frames';

  @override
  String get droppedSamples => 'Dropped samples';

  @override
  String get inputPreset => 'Input preset';

  @override
  String get processingUnknown =>
      'Device AGC / noise suppression / echo processing: unknown. A requested input preset does not prove that all processing is disabled.';

  @override
  String get normalizedPcm => 'PCM amplitude −1…+1';

  @override
  String get spectrumNotice =>
      'Hann window · one-sided peak amplitude per FFT bin in dBFS; not calibrated sound pressure. Off-bin peaks leak into adjacent bins.';

  @override
  String get openSourceLicenses => 'Open-source licenses';

  @override
  String get noClearPitch => 'No clear pitch';

  @override
  String get playReference => 'Play reference · 3 s';

  @override
  String get stopReference => 'Stop reference';

  @override
  String get referenceUnsupported =>
      'Reference playback is not implemented on this platform.';

  @override
  String get referenceError =>
      'Playback unavailable. Check audio output / competing apps.';

  @override
  String get referenceSafety =>
      'Reference playback stops microphone measurement. After playback, start tuning or Explore manually; use low media volume.';

  @override
  String get trackedFrequency => 'Tracked frequency';

  @override
  String get noiseFloor => 'Noise floor / level margin';

  @override
  String get spectralFeatures => 'Centroid / harmonic consistency';

  @override
  String get trackingFeatures => 'Candidates / tracker state';

  @override
  String get referenceAudio => 'Reference tone';

  @override
  String get automaticReference => 'Automatic reference';

  @override
  String get lockedReference => 'Locked reference';

  @override
  String lockReference(String note) {
    return 'Lock $note';
  }

  @override
  String unlockReference(String note) {
    return 'Unlock $note';
  }

  @override
  String get lockReferenceNotice =>
      'Locks the reference, never the measured pitch. Silence stays invalid. Stop, background or leaving Explore resets to automatic.';

  @override
  String get switchingReference => 'Changing reference…';

  @override
  String get flatOutsideRange => '← Flat · outside dial range';

  @override
  String get sharpOutsideRange => 'Sharp · outside dial range →';

  @override
  String referenceGaugeSemantics(
    String reference,
    String detected,
    String cents,
    String state,
  ) {
    return 'Reference $reference, detected $detected, $cents, $state';
  }

  @override
  String get guitarLiveSubtitle =>
      'Seven six-string presets · live microphone tuning.';

  @override
  String get manualTarget => 'Manual string';

  @override
  String get autoTarget => 'Auto match';

  @override
  String get guitarAmbiguous => 'Ambiguous target: select a string manually.';

  @override
  String get guitarOutside =>
      'Outside the auto range. Select a string manually.';

  @override
  String get guitarReferenceSafety =>
      'Reference playback stops measurement. After it ends, wait briefly and start the microphone manually. Use a separate source to check tuning.';

  @override
  String get guitarAutoNotice =>
      'Auto matches absolute pitch within ±150 cents of the selected preset; distances within 25 cents are ambiguous. A new string needs two fresh results. Harmonics may match another string; select manually when needed.';

  @override
  String get metronomeLiveSubtitle =>
      'Sample-clock rhythm, with clear accents.';

  @override
  String get metronomeUnsupported =>
      'Audio playback is not implemented on this platform.';

  @override
  String get metronomePlaying => 'Playing · native audio clock';

  @override
  String get metronomeStarting => 'Opening audio output…';

  @override
  String get metronomeStopped => 'Stopped';

  @override
  String get metronomeInterrupted =>
      'Playback interrupted or failed. Check audio output, then start again.';

  @override
  String get quarterBpm => 'Quarter-note BPM';

  @override
  String get metroAccent => 'Accents (6/8: 3+3)';

  @override
  String get metronomePending =>
      'Change applies at the next subdivision; bar restarts.';

  @override
  String get startMetronome => 'Start metronome';

  @override
  String get stopMetronome => 'Stop metronome';

  @override
  String get tapQuarter => 'Tap quarter-note tempo';

  @override
  String get subdivisionsPerPulse => 'Subdivisions per notated beat';

  @override
  String get metronomeClockNotice =>
      'BPM and Tap always count quarter notes. 6/8 has six eighth-note pulses, grouped 3+3 (two pulses per quarter). Subdivisions split each pulse. Changes apply on the next subdivision and restart the bar. Visuals show submitted audio samples, with polling and unknown speaker latency. Leaving this page, backgrounding or audio interruption stops playback; restart manually.';

  @override
  String metroBeat(int beat) {
    return 'Beat $beat';
  }

  @override
  String get completionNoDevice =>
      'Device checks not performed; development continues.';

  @override
  String get nativeAudio => 'Native audio';

  @override
  String get guitarConfirming => 'Confirming guitar target…';

  @override
  String get startGuitar => 'Start tuning';

  @override
  String get stopGuitar => 'Stop tuning';

  @override
  String get switchTool => 'Switch tool';

  @override
  String get exitMinimal => 'Exit focus';

  @override
  String get darkTheme => 'Dark';

  @override
  String get preferencesFailed =>
      'Appearance could not be loaded or saved. Changes apply for this session; retry by choosing again.';

  @override
  String get preferencesSessionOnly =>
      'This preview keeps preferences for this session only. Android saves theme, focus mode and A4 locally.';

  @override
  String get preferencesSaving => 'Saving appearance on this device…';

  @override
  String get preferencesSaved =>
      'Theme, focus mode and A4 reference are saved on this device. Language and playback settings are session-only.';

  @override
  String get sampledPcm =>
      'Display-filtered PCM · amplitude FS · time ms (auto vertical scale)';

  @override
  String get envelopePcm => 'Legacy min/max envelope · FS';

  @override
  String get waveTriggered =>
      'Aligned to an actual rising crossing; not a synthesized waveform.';

  @override
  String get waveFree => 'Free-running PCM window; no reliable trigger.';

  @override
  String get waveTiming => 'Audio sample clock · start/end and interval';

  @override
  String get guitarPreset => 'Tuning preset';

  @override
  String get presetDropD => 'Drop D · DADGBE';

  @override
  String get presetDStandard => 'D Standard · DGCFAD';

  @override
  String get presetHalfDown => 'Half-Step Down · Eb Ab Db Gb Bb Eb';

  @override
  String get presetDadgad => 'DADGAD';

  @override
  String get presetOpenD => 'Open D · DADF#AD';

  @override
  String get presetOpenG => 'Open G · DGDGBD';

  @override
  String get presetRestart =>
      'Preset changed. Measurement stopped; start again for a fresh reading.';

  @override
  String get guitarVoice => 'Plucked guitar · original synthesis';

  @override
  String synthVolume(int percent) {
    return 'Synth volume $percent%';
  }

  @override
  String get synthVolumeNotice =>
      'App synth level only; changing it stops the tone. Tap play again. System media volume is separate.';

  @override
  String get metroVolumeNotice =>
      'Adjust App click volume during playback without restarting the beat. System media volume is separate.';

  @override
  String get acknowledgements => 'Acknowledgements';

  @override
  String get acknowledgementsBody =>
      'OpenTuner began as an open-source course project for Data Analysis and Feature Extraction at Harbin Institute of Technology. Inspired by teacher Zhang Miao’s “顶级原则” and the idea of open-source sharing, the author created OpenTuner. This software is free to use, with a commitment to releasing all source code. Guided by the communist ideal of serving everyone, the author hopes to make a modest contribution.';

  @override
  String get acknowledgementsAttribution =>
      'This is a personal course project, not an official publication or endorsement by the university or teacher. These statements reflect the author’s views.';

  @override
  String get sourcePublicationPending =>
      'Source repository:\nhttps://github.com/yubowang224-dotcom/OpenTuner';

  @override
  String get referenceSetting => 'Global reference pitch';

  @override
  String get referenceInvalid => 'Enter A4 from 400 to 480 Hz.';

  @override
  String get applyReference => 'Apply A4';

  @override
  String get referenceCalibrationNotice =>
      'Changing A4 stops old measurement and reference playback. This sets musical pitch, not microphone sample-clock calibration.';

  @override
  String get pianoProfiles => 'Local piano profiles';

  @override
  String get profileReady => 'Local profiles ready.';

  @override
  String get profileUnsupported =>
      'Profile storage is not implemented on this platform.';

  @override
  String get profileUnavailable =>
      'Profile storage failed. Reload to retry; existing files are not overwritten.';

  @override
  String get profileCorrupt =>
      'Profile data is damaged and no usable backup was read. Writes are blocked.';

  @override
  String get profileSchema =>
      'This profile version is unsupported. No downgrade or overwrite is allowed.';

  @override
  String get profileConflict =>
      'Profile changed elsewhere or overwrite was not confirmed. Reload first.';

  @override
  String get profileInvalid =>
      'Check the name and fields; duplicate names are not allowed.';

  @override
  String get profileRecovered =>
      'A valid older backup was read. Restore it before editing; recent changes may be missing.';

  @override
  String get profileDataNotice =>
      'Stores only name, piano type, A4, selected key and UTC dates on this device. No raw audio or professional stretch data.';

  @override
  String get profileMatches => 'Current settings match the selected profile.';

  @override
  String get profileModified =>
      'Current settings differ from the selected profile; changes are not saved.';

  @override
  String get profileBusy => 'Reading or saving local profiles…';

  @override
  String get profileName => 'Piano name';

  @override
  String get profileCreate => 'Save as new profile';

  @override
  String get profileReload => 'Reload profiles';

  @override
  String get profileRecover => 'Restore backup';

  @override
  String get profileConfirmUpdate =>
      'Allow replacing the selected profile with current settings';

  @override
  String get profileUpdate => 'Update selected profile';

  @override
  String get pianoLiveSubtitle =>
      '88 keys · equal-temperament pitch measurement.';

  @override
  String get pianoMechanicalNotice =>
      'Current mode is basic equal temperament, not individualized tuning. Experimental measured calibration is available below; no real-piano validation.';

  @override
  String get pianoManualNotice =>
      'Select the actual key manually. Automatic key switching is not enabled.';

  @override
  String get pianoLowest => 'Lowest · A0';

  @override
  String get pianoHighest => 'Highest · C8';

  @override
  String get pianoReferenceSafety =>
      'Sine reference · microphone paused. Restart measurement manually after playback.';

  @override
  String get pianoAnalysisNotice =>
      'Piano mode observes about 180 ms of audio and needs an input rate of at least 16 kHz. Weak/mixed/inharmonic sounds may remain uncertain. Raw and tracked frequency are separate; the score is not a correctness probability.';

  @override
  String pianoKeyNumber(int number) {
    return 'Key $number / 88';
  }

  @override
  String pianoOctave(int number) {
    return 'Octave $number';
  }

  @override
  String get profileCapacity =>
      'Capacity reached: up to 64 profiles and 1 MiB total. Existing data is intact; reduce saved measurements.';

  @override
  String get calTitle => 'Mechanical piano · Experimental';

  @override
  String get calSubtitle =>
      'Measure stable partials, review quality and model a bounded stretch range.';

  @override
  String get calExperimental =>
      'Experimental, synthetic validation only. No real-piano/professional tuning certification. Mechanical work requires an experienced person.';

  @override
  String get calNeedProfile =>
      'Save/select a mechanical-piano profile matching the current type and A4 first.';

  @override
  String get calOpen => 'Measure partials / manage calibration';

  @override
  String get calTake => 'Accept this stable sample';

  @override
  String get calRemove => 'Remove this key’s sample';

  @override
  String get calUndo => 'Undo sample change';

  @override
  String get calSave => 'Save draft (replaces this profile’s calibration)';

  @override
  String get calSaved => 'Saved on this device.';

  @override
  String get calUnsaved => 'Draft changes are not saved.';

  @override
  String get calGenerate => 'Generate stretch targets';

  @override
  String get calApply => 'Apply saved stretch targets';

  @override
  String get calDisable => 'Return to equal temperament';

  @override
  String get calInsufficient =>
      'Need at least 5 valid keys including A4, both sides of A4, a span of 36 semitones and gaps no greater than an octave. No extrapolation.';

  @override
  String get calAssociationChanged =>
      'Profile, A4, type or page changed. Sampling stopped; close and reopen this workflow.';

  @override
  String get calDataNotice =>
      'Stores measured partial frequencies, fit/quality, source metadata and modeled targets locally, without raw recordings. Save explicitly before leaving; changing samples invalidates the curve.';

  @override
  String get calSamplingNotice =>
      'Play one selected key and let it settle. 750 ms windows / 100 ms steps; four consistent frames are required. Weak/ambiguous/unresolved multi-string sounds may not be reliable.';

  @override
  String get calFirstObserved =>
      'Order 1 observed; actual peak Hz is used for the live deviation.';

  @override
  String get calFirstInferred =>
      'Order 1 not observed. First-partial Hz is inferred by the string model, not directly measured.';

  @override
  String get calIdeal => 'Ideal-string parameter';

  @override
  String get calModelFirst => 'Fitted first partial';

  @override
  String get calObservedFirst => 'Observed first partial';

  @override
  String get calBFit => 'Inharmonicity B';

  @override
  String get calResidual => 'Fit RMS residual (cents)';

  @override
  String get calSensitivity => 'B sensitivity proxy';

  @override
  String get calExplained => 'Explained peak-power fraction';

  @override
  String get calStable => 'Consistent frame count';

  @override
  String get calPartialOrders => 'Observed orders';

  @override
  String calCurveRange(String low, String high) {
    return 'Supported modeled range: $low–$high. Outside this range uses ET.';
  }

  @override
  String get calBMeasured => 'B measured';

  @override
  String get calBInterpolated => 'B interpolated';

  @override
  String get calTargetModel => 'Target is modeled, not a direct measurement.';

  @override
  String get calOutside =>
      'Outside the calibrated range · ET target / ET analyzer';

  @override
  String get calActive => 'Experimental stretch targets active';

  @override
  String get calTargets => 'Inspect target frequencies';

  @override
  String get calModelNotice =>
      'Weighted 2:1 / 4:2 octave and 4:1 double-octave partial matching, with weak ET/neighbor regularization. A4 anchors the first partial. Weights are engineering assumptions, not a verified auditory optimum.';

  @override
  String get calError =>
      'Cannot generate/apply these targets. Review samples, support range and saved profile.';

  @override
  String get calStoredIncompatible =>
      'An older calibration is retained but incompatible with current A4/type. It is inactive; saving a new draft replaces it.';

  @override
  String get calSourceMic =>
      'Android microphone entry (not authenticated acoustic proof)';

  @override
  String get calSourceSynthetic => 'Synthetic host test fixture · not phone';

  @override
  String get calReason0 => 'Stable partial sample is ready.';

  @override
  String get calReason1 => 'Confirming several consistent frames…';

  @override
  String get calReason2 => 'No measurable signal.';

  @override
  String get calReason3 => 'Clipping · reduce level / move farther away.';

  @override
  String get calReason4 =>
      'Too few reliable partials (at least four required).';

  @override
  String get calReason5 =>
      'Peaks do not support the selected key/string model.';

  @override
  String get calReason6 => 'Partial orders or model are ambiguous. Remeasure.';

  @override
  String get calReason7 =>
      'Multiple strong peaks near a partial · possible multi-string interference.';

  @override
  String get calReason8 => 'Sound is not stable yet.';

  @override
  String get calReason9 =>
      'Available input bandwidth cannot support enough partials.';

  @override
  String get calReason10 =>
      'B is not identifiable with sufficient sensitivity.';

  @override
  String get calCurveCaption =>
      'ET offset (cents) · dots: measured B; line: modeled targets';

  @override
  String get calFitScore => 'Heuristic partial-fit score';

  @override
  String get calFitScoreNotice =>
      'Explained peak power × exp(−RMS residual / 2). This is not a calibrated correctness probability.';

  @override
  String get calLiveNotice =>
      'Experimental first-partial measurement: 750 ms windows / 100 ms steps, four consistent frames; slower than ET mode.';

  @override
  String get calSelectedKey => 'Selected target key';

  @override
  String get calNearestEt => 'Nearest ET note (measured)';

  @override
  String get calIdentityNotice =>
      'The selected key is a user choice; the nearest ET note may differ for a stretched target. Frequency alone cannot prove physical key identity.';

  @override
  String get calPianoSubtitle => 'Individual modeled stretch · Experimental';

  @override
  String get calUseHints => 'Use historical model search centers';

  @override
  String get calHintsNotice =>
      'Search hints only, not valid tuning targets. Choose this explicitly to remeasure an already stretched key. New samples invalidate the old curve; regenerate before applying.';

  @override
  String get calHintUnavailable =>
      'No historical center for this key; sampling uses the ET association window.';

  @override
  String get calAssociationCenter => 'Current association center';

  @override
  String get pauseMetronome => 'Pause metronome';

  @override
  String get resumeMetronome => 'Resume metronome';

  @override
  String get metronomePaused => 'Paused · position retained';

  @override
  String get metronomeTransition => 'Changing playback state…';

  @override
  String get metronomeTransportNotice =>
      'Pause retains the beat and remaining interval after a short fade. Resume continues there. Stop resets the position; Start begins on beat 1. Paused playback stays exclusive; leaving or backgrounding stops it.';
}
