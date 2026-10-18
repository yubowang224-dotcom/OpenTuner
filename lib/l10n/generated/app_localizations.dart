import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'OpenTuner'**
  String get appTitle;

  /// No description provided for @guitar.
  ///
  /// In en, this message translates to:
  /// **'Guitar'**
  String get guitar;

  /// No description provided for @piano.
  ///
  /// In en, this message translates to:
  /// **'Piano'**
  String get piano;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @metronome.
  ///
  /// In en, this message translates to:
  /// **'Metronome'**
  String get metronome;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @guitarTitle.
  ///
  /// In en, this message translates to:
  /// **'Find your balance.'**
  String get guitarTitle;

  /// No description provided for @guitarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A quieter space for a better tuning experience.'**
  String get guitarSubtitle;

  /// No description provided for @pianoTitle.
  ///
  /// In en, this message translates to:
  /// **'Every note, considered.'**
  String get pianoTitle;

  /// No description provided for @pianoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A clear starting point for your piano.'**
  String get pianoSubtitle;

  /// No description provided for @exploreTitle.
  ///
  /// In en, this message translates to:
  /// **'Get to know your sound.'**
  String get exploreTitle;

  /// No description provided for @exploreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hum, sing, or explore a steady note.'**
  String get exploreSubtitle;

  /// No description provided for @metronomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Make room for rhythm.'**
  String get metronomeTitle;

  /// No description provided for @metronomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your practice, one beat at a time.'**
  String get metronomeSubtitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Just the essentials.'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Make OpenTuner feel like your instrument.'**
  String get settingsSubtitle;

  /// No description provided for @uiPreview.
  ///
  /// In en, this message translates to:
  /// **'UI preview'**
  String get uiPreview;

  /// No description provided for @audioNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Instrument detection planned'**
  String get audioNotConnected;

  /// No description provided for @audioStageNotice.
  ///
  /// In en, this message translates to:
  /// **'Detection on this instrument page is not implemented yet. Use Explore for live microphone analysis.'**
  String get audioStageNotice;

  /// No description provided for @waitingAudio.
  ///
  /// In en, this message translates to:
  /// **'Waiting for audio'**
  String get waitingAudio;

  /// No description provided for @uncertain.
  ///
  /// In en, this message translates to:
  /// **'No stable pitch'**
  String get uncertain;

  /// No description provided for @flat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get flat;

  /// No description provided for @inTune.
  ///
  /// In en, this message translates to:
  /// **'In tune'**
  String get inTune;

  /// No description provided for @sharp.
  ///
  /// In en, this message translates to:
  /// **'Sharp'**
  String get sharp;

  /// No description provided for @centsUnit.
  ///
  /// In en, this message translates to:
  /// **'cents'**
  String get centsUnit;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @detectedNote.
  ///
  /// In en, this message translates to:
  /// **'Detected note'**
  String get detectedNote;

  /// No description provided for @demoNote.
  ///
  /// In en, this message translates to:
  /// **'Demo note'**
  String get demoNote;

  /// No description provided for @standardTuning.
  ///
  /// In en, this message translates to:
  /// **'Standard tuning'**
  String get standardTuning;

  /// No description provided for @sixStrings.
  ///
  /// In en, this message translates to:
  /// **'6 strings · E A D G B E'**
  String get sixStrings;

  /// No description provided for @targetOnly.
  ///
  /// In en, this message translates to:
  /// **'The guitar page supports seven six-string presets and plucked reference tones.'**
  String get targetOnly;

  /// No description provided for @stringLabel.
  ///
  /// In en, this message translates to:
  /// **'String {number}'**
  String stringLabel(int number);

  /// No description provided for @minimalMode.
  ///
  /// In en, this message translates to:
  /// **'Minimal mode'**
  String get minimalMode;

  /// No description provided for @minimalDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep the note, needle, and essential feedback.'**
  String get minimalDescription;

  /// No description provided for @normalMode.
  ///
  /// In en, this message translates to:
  /// **'Show details'**
  String get normalMode;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Measurement details'**
  String get details;

  /// No description provided for @measuredFrequency.
  ///
  /// In en, this message translates to:
  /// **'Measured frequency'**
  String get measuredFrequency;

  /// No description provided for @targetFrequency.
  ///
  /// In en, this message translates to:
  /// **'Target frequency'**
  String get targetFrequency;

  /// No description provided for @confidence.
  ///
  /// In en, this message translates to:
  /// **'Pitch confidence'**
  String get confidence;

  /// No description provided for @notMeasured.
  ///
  /// In en, this message translates to:
  /// **'Not measured'**
  String get notMeasured;

  /// No description provided for @demoTitle.
  ///
  /// In en, this message translates to:
  /// **'Try the needle'**
  String get demoTitle;

  /// No description provided for @demoDescription.
  ///
  /// In en, this message translates to:
  /// **'Visual demonstration only. No microphone or measured pitch.'**
  String get demoDescription;

  /// No description provided for @demoOn.
  ///
  /// In en, this message translates to:
  /// **'Demo · no audio'**
  String get demoOn;

  /// No description provided for @demoOff.
  ///
  /// In en, this message translates to:
  /// **'Exit demo'**
  String get demoOff;

  /// No description provided for @demoSlider.
  ///
  /// In en, this message translates to:
  /// **'Demonstration pitch offset'**
  String get demoSlider;

  /// No description provided for @demoOffset.
  ///
  /// In en, this message translates to:
  /// **'Demo offset: {value} cents'**
  String demoOffset(String value);

  /// No description provided for @gaugeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Tuning gauge: {note}, {value}, {state}'**
  String gaugeSemantics(String note, String value, String state);

  /// No description provided for @pianoType.
  ///
  /// In en, this message translates to:
  /// **'Piano type'**
  String get pianoType;

  /// No description provided for @digitalPiano.
  ///
  /// In en, this message translates to:
  /// **'Digital piano'**
  String get digitalPiano;

  /// No description provided for @uprightPiano.
  ///
  /// In en, this message translates to:
  /// **'Upright piano'**
  String get uprightPiano;

  /// No description provided for @grandPiano.
  ///
  /// In en, this message translates to:
  /// **'Grand piano'**
  String get grandPiano;

  /// No description provided for @pianoTarget.
  ///
  /// In en, this message translates to:
  /// **'Target note preview'**
  String get pianoTarget;

  /// No description provided for @pianoRangeNotice.
  ///
  /// In en, this message translates to:
  /// **'Select any of the 88 keys from A0 to C8.'**
  String get pianoRangeNotice;

  /// No description provided for @electronicNotice.
  ///
  /// In en, this message translates to:
  /// **'Digital piano mode uses equal-temperament targets. Mechanical stretch is not applied.'**
  String get electronicNotice;

  /// No description provided for @professionalTitle.
  ///
  /// In en, this message translates to:
  /// **'Individual piano calibration'**
  String get professionalTitle;

  /// No description provided for @professionalNotice.
  ///
  /// In en, this message translates to:
  /// **'Not implemented. Partial analysis and a measured stretch curve are planned. Real-piano validation will be required.'**
  String get professionalNotice;

  /// No description provided for @planned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get planned;

  /// No description provided for @microphoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone is not connected'**
  String get microphoneTitle;

  /// No description provided for @microphoneNotice.
  ///
  /// In en, this message translates to:
  /// **'Live pitch, waveform, and spectrum will appear here after real audio capture is added. This screen does not request permission or record audio.'**
  String get microphoneNotice;

  /// No description provided for @captureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Capture not available yet'**
  String get captureUnavailable;

  /// No description provided for @waveform.
  ///
  /// In en, this message translates to:
  /// **'Waveform'**
  String get waveform;

  /// No description provided for @spectrum.
  ///
  /// In en, this message translates to:
  /// **'Spectrum'**
  String get spectrum;

  /// No description provided for @realDataOnly.
  ///
  /// In en, this message translates to:
  /// **'Waiting for real samples'**
  String get realDataOnly;

  /// No description provided for @bpm.
  ///
  /// In en, this message translates to:
  /// **'BPM'**
  String get bpm;

  /// No description provided for @tempo.
  ///
  /// In en, this message translates to:
  /// **'Tempo'**
  String get tempo;

  /// No description provided for @tempoValue.
  ///
  /// In en, this message translates to:
  /// **'{value} beats per minute'**
  String tempoValue(int value);

  /// No description provided for @slower.
  ///
  /// In en, this message translates to:
  /// **'Decrease tempo'**
  String get slower;

  /// No description provided for @faster.
  ///
  /// In en, this message translates to:
  /// **'Increase tempo'**
  String get faster;

  /// No description provided for @timeSignature.
  ///
  /// In en, this message translates to:
  /// **'Time signature'**
  String get timeSignature;

  /// No description provided for @subdivision.
  ///
  /// In en, this message translates to:
  /// **'Subdivision'**
  String get subdivision;

  /// No description provided for @quarter.
  ///
  /// In en, this message translates to:
  /// **'Quarter notes'**
  String get quarter;

  /// No description provided for @eighth.
  ///
  /// In en, this message translates to:
  /// **'Eighth notes'**
  String get eighth;

  /// No description provided for @triplet.
  ///
  /// In en, this message translates to:
  /// **'Triplets'**
  String get triplet;

  /// No description provided for @sixteenth.
  ///
  /// In en, this message translates to:
  /// **'Sixteenth notes'**
  String get sixteenth;

  /// No description provided for @beatPreview.
  ///
  /// In en, this message translates to:
  /// **'Beat layout preview'**
  String get beatPreview;

  /// No description provided for @metronomeNotice.
  ///
  /// In en, this message translates to:
  /// **'Audio-clock playback is available on Android. Start explicitly; leaving the page stops playback.'**
  String get metronomeNotice;

  /// No description provided for @playbackUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Audio playback not connected'**
  String get playbackUnavailable;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get chinese;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light theme'**
  String get lightTheme;

  /// No description provided for @sessionSettings.
  ///
  /// In en, this message translates to:
  /// **'Language and playback settings apply to this session. Theme, focus mode and A4 are saved on Android.'**
  String get sessionSettings;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your sound stays yours.'**
  String get privacyTitle;

  /// No description provided for @privacyDescription.
  ///
  /// In en, this message translates to:
  /// **'Microphone access starts only after you explicitly start measurement. Audio stays on this device without recordings or uploads. Private piano profiles may contain measured partial frequencies, quality, device metadata and modeled tuning targets. No ads or tracking SDKs.'**
  String get privacyDescription;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About OpenTuner'**
  String get about;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version 0.7.0 Beta 2 · Mechanical calibration remains Experimental'**
  String get versionLabel;

  /// No description provided for @licenseLabel.
  ///
  /// In en, this message translates to:
  /// **'Open source · Apache License 2.0'**
  String get licenseLabel;

  /// No description provided for @availability.
  ///
  /// In en, this message translates to:
  /// **'Feature availability'**
  String get availability;

  /// No description provided for @availabilityDescription.
  ///
  /// In en, this message translates to:
  /// **'Explore and guitar retain the accepted general C++ tracker. Piano offers 88-key equal-temperament measurement and optional Experimental mechanical calibration: partial fitting, quality rejection and individually modeled targets within measured support. This is not real-piano or professional validation; outside support uses equal temperament.'**
  String get availabilityDescription;

  /// No description provided for @referencePitch.
  ///
  /// In en, this message translates to:
  /// **'Reference pitch'**
  String get referencePitch;

  /// No description provided for @referencePitchNotice.
  ///
  /// In en, this message translates to:
  /// **'Global A4 reference applies to every target and reference tone.'**
  String get referencePitchNotice;

  /// No description provided for @noPermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission has not been requested'**
  String get noPermission;

  /// No description provided for @targetSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}, {note}'**
  String targetSemantics(String label, String note);

  /// No description provided for @localAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Local audio'**
  String get localAnalysis;

  /// No description provided for @micIdle.
  ///
  /// In en, this message translates to:
  /// **'Microphone stopped · start when ready'**
  String get micIdle;

  /// No description provided for @micStarting.
  ///
  /// In en, this message translates to:
  /// **'Requesting microphone / opening stream…'**
  String get micStarting;

  /// No description provided for @micRunning.
  ///
  /// In en, this message translates to:
  /// **'Microphone active · live analysis'**
  String get micRunning;

  /// No description provided for @micUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Audio capture is not implemented on this platform'**
  String get micUnsupported;

  /// No description provided for @micDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied. You can try again.'**
  String get micDenied;

  /// No description provided for @micSettings.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access in Android app settings.'**
  String get micSettings;

  /// No description provided for @micRevoked.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission was revoked. Capture stopped.'**
  String get micRevoked;

  /// No description provided for @micBackground.
  ///
  /// In en, this message translates to:
  /// **'Capture stopped in background. Tap Start to resume.'**
  String get micBackground;

  /// No description provided for @micDeviceChanged.
  ///
  /// In en, this message translates to:
  /// **'Input device changed. Capture stopped; tap Start to reopen.'**
  String get micDeviceChanged;

  /// No description provided for @micSilenced.
  ///
  /// In en, this message translates to:
  /// **'Microphone muted or silenced by the system. Check privacy settings and other recording apps.'**
  String get micSilenced;

  /// No description provided for @micInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Audio stream interrupted. Tap Start to reopen.'**
  String get micInterrupted;

  /// No description provided for @micStalled.
  ///
  /// In en, this message translates to:
  /// **'No fresh audio arrived. Capture stopped; check the input device.'**
  String get micStalled;

  /// No description provided for @micError.
  ///
  /// In en, this message translates to:
  /// **'Could not start or read audio. Check permissions / competing apps and try again.'**
  String get micError;

  /// No description provided for @startCapture.
  ///
  /// In en, this message translates to:
  /// **'Start microphone'**
  String get startCapture;

  /// No description provided for @stopCapture.
  ///
  /// In en, this message translates to:
  /// **'Stop microphone'**
  String get stopCapture;

  /// No description provided for @openAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get openAppSettings;

  /// No description provided for @capturePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Audio is processed locally, without uploading or saving raw recordings. Single-source estimate: start with a steady hum, about 50–2000 Hz. Complex sound may have no clear pitch.'**
  String get capturePrivacy;

  /// No description provided for @signalLevel.
  ///
  /// In en, this message translates to:
  /// **'Digital level'**
  String get signalLevel;

  /// No description provided for @algorithmScore.
  ///
  /// In en, this message translates to:
  /// **'Periodicity score'**
  String get algorithmScore;

  /// No description provided for @scoreNotice.
  ///
  /// In en, this message translates to:
  /// **'0–1 periodicity score, not correctness probability. Cents use the selected reference. Automatic reference uses ±55 cents hysteresis and brief boundary confirmation; raw/tracked Hz stay unchanged.'**
  String get scoreNotice;

  /// No description provided for @clippingWarning.
  ///
  /// In en, this message translates to:
  /// **'Clipping detected · move farther from the microphone'**
  String get clippingWarning;

  /// No description provided for @liveDetails.
  ///
  /// In en, this message translates to:
  /// **'Live waveform, spectrum & diagnostics'**
  String get liveDetails;

  /// No description provided for @audioConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Actual stream'**
  String get audioConfiguration;

  /// No description provided for @rawFrequency.
  ///
  /// In en, this message translates to:
  /// **'Raw candidate'**
  String get rawFrequency;

  /// No description provided for @bufferInfo.
  ///
  /// In en, this message translates to:
  /// **'Burst / capacity'**
  String get bufferInfo;

  /// No description provided for @framesUnit.
  ///
  /// In en, this message translates to:
  /// **'frames'**
  String get framesUnit;

  /// No description provided for @droppedSamples.
  ///
  /// In en, this message translates to:
  /// **'Dropped samples'**
  String get droppedSamples;

  /// No description provided for @inputPreset.
  ///
  /// In en, this message translates to:
  /// **'Input preset'**
  String get inputPreset;

  /// No description provided for @processingUnknown.
  ///
  /// In en, this message translates to:
  /// **'Device AGC / noise suppression / echo processing: unknown. A requested input preset does not prove that all processing is disabled.'**
  String get processingUnknown;

  /// No description provided for @normalizedPcm.
  ///
  /// In en, this message translates to:
  /// **'PCM amplitude −1…+1'**
  String get normalizedPcm;

  /// No description provided for @spectrumNotice.
  ///
  /// In en, this message translates to:
  /// **'Hann window · one-sided peak amplitude per FFT bin in dBFS; not calibrated sound pressure. Off-bin peaks leak into adjacent bins.'**
  String get spectrumNotice;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get openSourceLicenses;

  /// No description provided for @noClearPitch.
  ///
  /// In en, this message translates to:
  /// **'No clear pitch'**
  String get noClearPitch;

  /// No description provided for @playReference.
  ///
  /// In en, this message translates to:
  /// **'Play reference · 3 s'**
  String get playReference;

  /// No description provided for @stopReference.
  ///
  /// In en, this message translates to:
  /// **'Stop reference'**
  String get stopReference;

  /// No description provided for @referenceUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Reference playback is not implemented on this platform.'**
  String get referenceUnsupported;

  /// No description provided for @referenceError.
  ///
  /// In en, this message translates to:
  /// **'Playback unavailable. Check audio output / competing apps.'**
  String get referenceError;

  /// No description provided for @referenceSafety.
  ///
  /// In en, this message translates to:
  /// **'Reference playback stops microphone measurement. After playback, start tuning or Explore manually; use low media volume.'**
  String get referenceSafety;

  /// No description provided for @trackedFrequency.
  ///
  /// In en, this message translates to:
  /// **'Tracked frequency'**
  String get trackedFrequency;

  /// No description provided for @noiseFloor.
  ///
  /// In en, this message translates to:
  /// **'Noise floor / level margin'**
  String get noiseFloor;

  /// No description provided for @spectralFeatures.
  ///
  /// In en, this message translates to:
  /// **'Centroid / harmonic consistency'**
  String get spectralFeatures;

  /// No description provided for @trackingFeatures.
  ///
  /// In en, this message translates to:
  /// **'Candidates / tracker state'**
  String get trackingFeatures;

  /// No description provided for @referenceAudio.
  ///
  /// In en, this message translates to:
  /// **'Reference tone'**
  String get referenceAudio;

  /// No description provided for @automaticReference.
  ///
  /// In en, this message translates to:
  /// **'Automatic reference'**
  String get automaticReference;

  /// No description provided for @lockedReference.
  ///
  /// In en, this message translates to:
  /// **'Locked reference'**
  String get lockedReference;

  /// No description provided for @lockReference.
  ///
  /// In en, this message translates to:
  /// **'Lock {note}'**
  String lockReference(String note);

  /// No description provided for @unlockReference.
  ///
  /// In en, this message translates to:
  /// **'Unlock {note}'**
  String unlockReference(String note);

  /// No description provided for @lockReferenceNotice.
  ///
  /// In en, this message translates to:
  /// **'Locks the reference, never the measured pitch. Silence stays invalid. Stop, background or leaving Explore resets to automatic.'**
  String get lockReferenceNotice;

  /// No description provided for @switchingReference.
  ///
  /// In en, this message translates to:
  /// **'Changing reference…'**
  String get switchingReference;

  /// No description provided for @flatOutsideRange.
  ///
  /// In en, this message translates to:
  /// **'← Flat · outside dial range'**
  String get flatOutsideRange;

  /// No description provided for @sharpOutsideRange.
  ///
  /// In en, this message translates to:
  /// **'Sharp · outside dial range →'**
  String get sharpOutsideRange;

  /// No description provided for @referenceGaugeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Reference {reference}, detected {detected}, {cents}, {state}'**
  String referenceGaugeSemantics(
    String reference,
    String detected,
    String cents,
    String state,
  );

  /// No description provided for @guitarLiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Seven six-string presets · live microphone tuning.'**
  String get guitarLiveSubtitle;

  /// No description provided for @manualTarget.
  ///
  /// In en, this message translates to:
  /// **'Manual string'**
  String get manualTarget;

  /// No description provided for @autoTarget.
  ///
  /// In en, this message translates to:
  /// **'Auto match'**
  String get autoTarget;

  /// No description provided for @guitarAmbiguous.
  ///
  /// In en, this message translates to:
  /// **'Ambiguous target: select a string manually.'**
  String get guitarAmbiguous;

  /// No description provided for @guitarOutside.
  ///
  /// In en, this message translates to:
  /// **'Outside the auto range. Select a string manually.'**
  String get guitarOutside;

  /// No description provided for @guitarReferenceSafety.
  ///
  /// In en, this message translates to:
  /// **'Reference playback stops measurement. After it ends, wait briefly and start the microphone manually. Use a separate source to check tuning.'**
  String get guitarReferenceSafety;

  /// No description provided for @guitarAutoNotice.
  ///
  /// In en, this message translates to:
  /// **'Auto matches absolute pitch within ±150 cents of the selected preset; distances within 25 cents are ambiguous. A new string needs two fresh results. Harmonics may match another string; select manually when needed.'**
  String get guitarAutoNotice;

  /// No description provided for @metronomeLiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sample-clock rhythm, with clear accents.'**
  String get metronomeLiveSubtitle;

  /// No description provided for @metronomeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Audio playback is not implemented on this platform.'**
  String get metronomeUnsupported;

  /// No description provided for @metronomePlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing · native audio clock'**
  String get metronomePlaying;

  /// No description provided for @metronomeStarting.
  ///
  /// In en, this message translates to:
  /// **'Opening audio output…'**
  String get metronomeStarting;

  /// No description provided for @metronomeStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get metronomeStopped;

  /// No description provided for @metronomeInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Playback interrupted or failed. Check audio output, then start again.'**
  String get metronomeInterrupted;

  /// No description provided for @quarterBpm.
  ///
  /// In en, this message translates to:
  /// **'Quarter-note BPM'**
  String get quarterBpm;

  /// No description provided for @metroAccent.
  ///
  /// In en, this message translates to:
  /// **'Accents (6/8: 3+3)'**
  String get metroAccent;

  /// No description provided for @metronomePending.
  ///
  /// In en, this message translates to:
  /// **'Change applies at the next subdivision; bar restarts.'**
  String get metronomePending;

  /// No description provided for @startMetronome.
  ///
  /// In en, this message translates to:
  /// **'Start metronome'**
  String get startMetronome;

  /// No description provided for @stopMetronome.
  ///
  /// In en, this message translates to:
  /// **'Stop metronome'**
  String get stopMetronome;

  /// No description provided for @tapQuarter.
  ///
  /// In en, this message translates to:
  /// **'Tap quarter-note tempo'**
  String get tapQuarter;

  /// No description provided for @subdivisionsPerPulse.
  ///
  /// In en, this message translates to:
  /// **'Subdivisions per notated beat'**
  String get subdivisionsPerPulse;

  /// No description provided for @metronomeClockNotice.
  ///
  /// In en, this message translates to:
  /// **'BPM and Tap always count quarter notes. 6/8 has six eighth-note pulses, grouped 3+3 (two pulses per quarter). Subdivisions split each pulse. Changes apply on the next subdivision and restart the bar. Visuals show submitted audio samples, with polling and unknown speaker latency. Leaving this page, backgrounding or audio interruption stops playback; restart manually.'**
  String get metronomeClockNotice;

  /// No description provided for @metroBeat.
  ///
  /// In en, this message translates to:
  /// **'Beat {beat}'**
  String metroBeat(int beat);

  /// No description provided for @completionNoDevice.
  ///
  /// In en, this message translates to:
  /// **'Device checks not performed; development continues.'**
  String get completionNoDevice;

  /// No description provided for @nativeAudio.
  ///
  /// In en, this message translates to:
  /// **'Native audio'**
  String get nativeAudio;

  /// No description provided for @guitarConfirming.
  ///
  /// In en, this message translates to:
  /// **'Confirming guitar target…'**
  String get guitarConfirming;

  /// No description provided for @startGuitar.
  ///
  /// In en, this message translates to:
  /// **'Start tuning'**
  String get startGuitar;

  /// No description provided for @stopGuitar.
  ///
  /// In en, this message translates to:
  /// **'Stop tuning'**
  String get stopGuitar;

  /// No description provided for @switchTool.
  ///
  /// In en, this message translates to:
  /// **'Switch tool'**
  String get switchTool;

  /// No description provided for @exitMinimal.
  ///
  /// In en, this message translates to:
  /// **'Exit focus'**
  String get exitMinimal;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @preferencesFailed.
  ///
  /// In en, this message translates to:
  /// **'Appearance could not be loaded or saved. Changes apply for this session; retry by choosing again.'**
  String get preferencesFailed;

  /// No description provided for @preferencesSessionOnly.
  ///
  /// In en, this message translates to:
  /// **'This preview keeps preferences for this session only. Android saves theme, focus mode and A4 locally.'**
  String get preferencesSessionOnly;

  /// No description provided for @preferencesSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving appearance on this device…'**
  String get preferencesSaving;

  /// No description provided for @preferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Theme, focus mode and A4 reference are saved on this device. Language and playback settings are session-only.'**
  String get preferencesSaved;

  /// No description provided for @sampledPcm.
  ///
  /// In en, this message translates to:
  /// **'Display-filtered PCM · amplitude FS · time ms (auto vertical scale)'**
  String get sampledPcm;

  /// No description provided for @envelopePcm.
  ///
  /// In en, this message translates to:
  /// **'Legacy min/max envelope · FS'**
  String get envelopePcm;

  /// No description provided for @waveTriggered.
  ///
  /// In en, this message translates to:
  /// **'Aligned to an actual rising crossing; not a synthesized waveform.'**
  String get waveTriggered;

  /// No description provided for @waveFree.
  ///
  /// In en, this message translates to:
  /// **'Free-running PCM window; no reliable trigger.'**
  String get waveFree;

  /// No description provided for @waveTiming.
  ///
  /// In en, this message translates to:
  /// **'Audio sample clock · start/end and interval'**
  String get waveTiming;

  /// No description provided for @guitarPreset.
  ///
  /// In en, this message translates to:
  /// **'Tuning preset'**
  String get guitarPreset;

  /// No description provided for @presetDropD.
  ///
  /// In en, this message translates to:
  /// **'Drop D · DADGBE'**
  String get presetDropD;

  /// No description provided for @presetDStandard.
  ///
  /// In en, this message translates to:
  /// **'D Standard · DGCFAD'**
  String get presetDStandard;

  /// No description provided for @presetHalfDown.
  ///
  /// In en, this message translates to:
  /// **'Half-Step Down · Eb Ab Db Gb Bb Eb'**
  String get presetHalfDown;

  /// No description provided for @presetDadgad.
  ///
  /// In en, this message translates to:
  /// **'DADGAD'**
  String get presetDadgad;

  /// No description provided for @presetOpenD.
  ///
  /// In en, this message translates to:
  /// **'Open D · DADF#AD'**
  String get presetOpenD;

  /// No description provided for @presetOpenG.
  ///
  /// In en, this message translates to:
  /// **'Open G · DGDGBD'**
  String get presetOpenG;

  /// No description provided for @presetRestart.
  ///
  /// In en, this message translates to:
  /// **'Preset changed. Measurement stopped; start again for a fresh reading.'**
  String get presetRestart;

  /// No description provided for @guitarVoice.
  ///
  /// In en, this message translates to:
  /// **'Plucked guitar · original synthesis'**
  String get guitarVoice;

  /// No description provided for @synthVolume.
  ///
  /// In en, this message translates to:
  /// **'Synth volume {percent}%'**
  String synthVolume(int percent);

  /// No description provided for @synthVolumeNotice.
  ///
  /// In en, this message translates to:
  /// **'App synth level only; changing it stops the tone. Tap play again. System media volume is separate.'**
  String get synthVolumeNotice;

  /// No description provided for @metroVolumeNotice.
  ///
  /// In en, this message translates to:
  /// **'Adjust App click volume during playback without restarting the beat. System media volume is separate.'**
  String get metroVolumeNotice;

  /// No description provided for @acknowledgements.
  ///
  /// In en, this message translates to:
  /// **'Acknowledgements'**
  String get acknowledgements;

  /// No description provided for @acknowledgementsBody.
  ///
  /// In en, this message translates to:
  /// **'OpenTuner began as an open-source course project for Data Analysis and Feature Extraction at Harbin Institute of Technology. Inspired by teacher Zhang Miao’s “顶级原则” and the idea of open-source sharing, the author created OpenTuner. This software is free to use, with a commitment to releasing all source code. Guided by the communist ideal of serving everyone, the author hopes to make a modest contribution.'**
  String get acknowledgementsBody;

  /// No description provided for @acknowledgementsAttribution.
  ///
  /// In en, this message translates to:
  /// **'This is a personal course project, not an official publication or endorsement by the university or teacher. These statements reflect the author’s views.'**
  String get acknowledgementsAttribution;

  /// No description provided for @sourcePublicationPending.
  ///
  /// In en, this message translates to:
  /// **'Source repository:\nhttps://github.com/yubowang224-dotcom/OpenTuner'**
  String get sourcePublicationPending;

  /// No description provided for @referenceSetting.
  ///
  /// In en, this message translates to:
  /// **'Global reference pitch'**
  String get referenceSetting;

  /// No description provided for @referenceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter A4 from 400 to 480 Hz.'**
  String get referenceInvalid;

  /// No description provided for @applyReference.
  ///
  /// In en, this message translates to:
  /// **'Apply A4'**
  String get applyReference;

  /// No description provided for @referenceCalibrationNotice.
  ///
  /// In en, this message translates to:
  /// **'Changing A4 stops old measurement and reference playback. This sets musical pitch, not microphone sample-clock calibration.'**
  String get referenceCalibrationNotice;

  /// No description provided for @pianoProfiles.
  ///
  /// In en, this message translates to:
  /// **'Local piano profiles'**
  String get pianoProfiles;

  /// No description provided for @profileReady.
  ///
  /// In en, this message translates to:
  /// **'Local profiles ready.'**
  String get profileReady;

  /// No description provided for @profileUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Profile storage is not implemented on this platform.'**
  String get profileUnsupported;

  /// No description provided for @profileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Profile storage failed. Reload to retry; existing files are not overwritten.'**
  String get profileUnavailable;

  /// No description provided for @profileCorrupt.
  ///
  /// In en, this message translates to:
  /// **'Profile data is damaged and no usable backup was read. Writes are blocked.'**
  String get profileCorrupt;

  /// No description provided for @profileSchema.
  ///
  /// In en, this message translates to:
  /// **'This profile version is unsupported. No downgrade or overwrite is allowed.'**
  String get profileSchema;

  /// No description provided for @profileConflict.
  ///
  /// In en, this message translates to:
  /// **'Profile changed elsewhere or overwrite was not confirmed. Reload first.'**
  String get profileConflict;

  /// No description provided for @profileInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the name and fields; duplicate names are not allowed.'**
  String get profileInvalid;

  /// No description provided for @profileRecovered.
  ///
  /// In en, this message translates to:
  /// **'A valid older backup was read. Restore it before editing; recent changes may be missing.'**
  String get profileRecovered;

  /// No description provided for @profileDataNotice.
  ///
  /// In en, this message translates to:
  /// **'Stores only name, piano type, A4, selected key and UTC dates on this device. No raw audio or professional stretch data.'**
  String get profileDataNotice;

  /// No description provided for @profileMatches.
  ///
  /// In en, this message translates to:
  /// **'Current settings match the selected profile.'**
  String get profileMatches;

  /// No description provided for @profileModified.
  ///
  /// In en, this message translates to:
  /// **'Current settings differ from the selected profile; changes are not saved.'**
  String get profileModified;

  /// No description provided for @profileBusy.
  ///
  /// In en, this message translates to:
  /// **'Reading or saving local profiles…'**
  String get profileBusy;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Piano name'**
  String get profileName;

  /// No description provided for @profileCreate.
  ///
  /// In en, this message translates to:
  /// **'Save as new profile'**
  String get profileCreate;

  /// No description provided for @profileReload.
  ///
  /// In en, this message translates to:
  /// **'Reload profiles'**
  String get profileReload;

  /// No description provided for @profileRecover.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get profileRecover;

  /// No description provided for @profileConfirmUpdate.
  ///
  /// In en, this message translates to:
  /// **'Allow replacing the selected profile with current settings'**
  String get profileConfirmUpdate;

  /// No description provided for @profileUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update selected profile'**
  String get profileUpdate;

  /// No description provided for @pianoLiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'88 keys · equal-temperament pitch measurement.'**
  String get pianoLiveSubtitle;

  /// No description provided for @pianoMechanicalNotice.
  ///
  /// In en, this message translates to:
  /// **'Current mode is basic equal temperament, not individualized tuning. Experimental measured calibration is available below; no real-piano validation.'**
  String get pianoMechanicalNotice;

  /// No description provided for @pianoManualNotice.
  ///
  /// In en, this message translates to:
  /// **'Select the actual key manually. Automatic key switching is not enabled.'**
  String get pianoManualNotice;

  /// No description provided for @pianoLowest.
  ///
  /// In en, this message translates to:
  /// **'Lowest · A0'**
  String get pianoLowest;

  /// No description provided for @pianoHighest.
  ///
  /// In en, this message translates to:
  /// **'Highest · C8'**
  String get pianoHighest;

  /// No description provided for @pianoReferenceSafety.
  ///
  /// In en, this message translates to:
  /// **'Sine reference · microphone paused. Restart measurement manually after playback.'**
  String get pianoReferenceSafety;

  /// No description provided for @pianoAnalysisNotice.
  ///
  /// In en, this message translates to:
  /// **'Piano mode observes about 180 ms of audio and needs an input rate of at least 16 kHz. Weak/mixed/inharmonic sounds may remain uncertain. Raw and tracked frequency are separate; the score is not a correctness probability.'**
  String get pianoAnalysisNotice;

  /// No description provided for @pianoKeyNumber.
  ///
  /// In en, this message translates to:
  /// **'Key {number} / 88'**
  String pianoKeyNumber(int number);

  /// No description provided for @pianoOctave.
  ///
  /// In en, this message translates to:
  /// **'Octave {number}'**
  String pianoOctave(int number);

  /// No description provided for @profileCapacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity reached: up to 64 profiles and 1 MiB total. Existing data is intact; reduce saved measurements.'**
  String get profileCapacity;

  /// No description provided for @calTitle.
  ///
  /// In en, this message translates to:
  /// **'Mechanical piano · Experimental'**
  String get calTitle;

  /// No description provided for @calSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Measure stable partials, review quality and model a bounded stretch range.'**
  String get calSubtitle;

  /// No description provided for @calExperimental.
  ///
  /// In en, this message translates to:
  /// **'Experimental, synthetic validation only. No real-piano/professional tuning certification. Mechanical work requires an experienced person.'**
  String get calExperimental;

  /// No description provided for @calNeedProfile.
  ///
  /// In en, this message translates to:
  /// **'Save/select a mechanical-piano profile matching the current type and A4 first.'**
  String get calNeedProfile;

  /// No description provided for @calOpen.
  ///
  /// In en, this message translates to:
  /// **'Measure partials / manage calibration'**
  String get calOpen;

  /// No description provided for @calTake.
  ///
  /// In en, this message translates to:
  /// **'Accept this stable sample'**
  String get calTake;

  /// No description provided for @calRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove this key’s sample'**
  String get calRemove;

  /// No description provided for @calUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo sample change'**
  String get calUndo;

  /// No description provided for @calSave.
  ///
  /// In en, this message translates to:
  /// **'Save draft (replaces this profile’s calibration)'**
  String get calSave;

  /// No description provided for @calSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device.'**
  String get calSaved;

  /// No description provided for @calUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Draft changes are not saved.'**
  String get calUnsaved;

  /// No description provided for @calGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate stretch targets'**
  String get calGenerate;

  /// No description provided for @calApply.
  ///
  /// In en, this message translates to:
  /// **'Apply saved stretch targets'**
  String get calApply;

  /// No description provided for @calDisable.
  ///
  /// In en, this message translates to:
  /// **'Return to equal temperament'**
  String get calDisable;

  /// No description provided for @calInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Need at least 5 valid keys including A4, both sides of A4, a span of 36 semitones and gaps no greater than an octave. No extrapolation.'**
  String get calInsufficient;

  /// No description provided for @calAssociationChanged.
  ///
  /// In en, this message translates to:
  /// **'Profile, A4, type or page changed. Sampling stopped; close and reopen this workflow.'**
  String get calAssociationChanged;

  /// No description provided for @calDataNotice.
  ///
  /// In en, this message translates to:
  /// **'Stores measured partial frequencies, fit/quality, source metadata and modeled targets locally, without raw recordings. Save explicitly before leaving; changing samples invalidates the curve.'**
  String get calDataNotice;

  /// No description provided for @calSamplingNotice.
  ///
  /// In en, this message translates to:
  /// **'Play one selected key and let it settle. 750 ms windows / 100 ms steps; four consistent frames are required. Weak/ambiguous/unresolved multi-string sounds may not be reliable.'**
  String get calSamplingNotice;

  /// No description provided for @calFirstObserved.
  ///
  /// In en, this message translates to:
  /// **'Order 1 observed; actual peak Hz is used for the live deviation.'**
  String get calFirstObserved;

  /// No description provided for @calFirstInferred.
  ///
  /// In en, this message translates to:
  /// **'Order 1 not observed. First-partial Hz is inferred by the string model, not directly measured.'**
  String get calFirstInferred;

  /// No description provided for @calIdeal.
  ///
  /// In en, this message translates to:
  /// **'Ideal-string parameter'**
  String get calIdeal;

  /// No description provided for @calModelFirst.
  ///
  /// In en, this message translates to:
  /// **'Fitted first partial'**
  String get calModelFirst;

  /// No description provided for @calObservedFirst.
  ///
  /// In en, this message translates to:
  /// **'Observed first partial'**
  String get calObservedFirst;

  /// No description provided for @calBFit.
  ///
  /// In en, this message translates to:
  /// **'Inharmonicity B'**
  String get calBFit;

  /// No description provided for @calResidual.
  ///
  /// In en, this message translates to:
  /// **'Fit RMS residual (cents)'**
  String get calResidual;

  /// No description provided for @calSensitivity.
  ///
  /// In en, this message translates to:
  /// **'B sensitivity proxy'**
  String get calSensitivity;

  /// No description provided for @calExplained.
  ///
  /// In en, this message translates to:
  /// **'Explained peak-power fraction'**
  String get calExplained;

  /// No description provided for @calStable.
  ///
  /// In en, this message translates to:
  /// **'Consistent frame count'**
  String get calStable;

  /// No description provided for @calPartialOrders.
  ///
  /// In en, this message translates to:
  /// **'Observed orders'**
  String get calPartialOrders;

  /// No description provided for @calCurveRange.
  ///
  /// In en, this message translates to:
  /// **'Supported modeled range: {low}–{high}. Outside this range uses ET.'**
  String calCurveRange(String low, String high);

  /// No description provided for @calBMeasured.
  ///
  /// In en, this message translates to:
  /// **'B measured'**
  String get calBMeasured;

  /// No description provided for @calBInterpolated.
  ///
  /// In en, this message translates to:
  /// **'B interpolated'**
  String get calBInterpolated;

  /// No description provided for @calTargetModel.
  ///
  /// In en, this message translates to:
  /// **'Target is modeled, not a direct measurement.'**
  String get calTargetModel;

  /// No description provided for @calOutside.
  ///
  /// In en, this message translates to:
  /// **'Outside the calibrated range · ET target / ET analyzer'**
  String get calOutside;

  /// No description provided for @calActive.
  ///
  /// In en, this message translates to:
  /// **'Experimental stretch targets active'**
  String get calActive;

  /// No description provided for @calTargets.
  ///
  /// In en, this message translates to:
  /// **'Inspect target frequencies'**
  String get calTargets;

  /// No description provided for @calModelNotice.
  ///
  /// In en, this message translates to:
  /// **'Weighted 2:1 / 4:2 octave and 4:1 double-octave partial matching, with weak ET/neighbor regularization. A4 anchors the first partial. Weights are engineering assumptions, not a verified auditory optimum.'**
  String get calModelNotice;

  /// No description provided for @calError.
  ///
  /// In en, this message translates to:
  /// **'Cannot generate/apply these targets. Review samples, support range and saved profile.'**
  String get calError;

  /// No description provided for @calStoredIncompatible.
  ///
  /// In en, this message translates to:
  /// **'An older calibration is retained but incompatible with current A4/type. It is inactive; saving a new draft replaces it.'**
  String get calStoredIncompatible;

  /// No description provided for @calSourceMic.
  ///
  /// In en, this message translates to:
  /// **'Android microphone entry (not authenticated acoustic proof)'**
  String get calSourceMic;

  /// No description provided for @calSourceSynthetic.
  ///
  /// In en, this message translates to:
  /// **'Synthetic host test fixture · not phone'**
  String get calSourceSynthetic;

  /// No description provided for @calReason0.
  ///
  /// In en, this message translates to:
  /// **'Stable partial sample is ready.'**
  String get calReason0;

  /// No description provided for @calReason1.
  ///
  /// In en, this message translates to:
  /// **'Confirming several consistent frames…'**
  String get calReason1;

  /// No description provided for @calReason2.
  ///
  /// In en, this message translates to:
  /// **'No measurable signal.'**
  String get calReason2;

  /// No description provided for @calReason3.
  ///
  /// In en, this message translates to:
  /// **'Clipping · reduce level / move farther away.'**
  String get calReason3;

  /// No description provided for @calReason4.
  ///
  /// In en, this message translates to:
  /// **'Too few reliable partials (at least four required).'**
  String get calReason4;

  /// No description provided for @calReason5.
  ///
  /// In en, this message translates to:
  /// **'Peaks do not support the selected key/string model.'**
  String get calReason5;

  /// No description provided for @calReason6.
  ///
  /// In en, this message translates to:
  /// **'Partial orders or model are ambiguous. Remeasure.'**
  String get calReason6;

  /// No description provided for @calReason7.
  ///
  /// In en, this message translates to:
  /// **'Multiple strong peaks near a partial · possible multi-string interference.'**
  String get calReason7;

  /// No description provided for @calReason8.
  ///
  /// In en, this message translates to:
  /// **'Sound is not stable yet.'**
  String get calReason8;

  /// No description provided for @calReason9.
  ///
  /// In en, this message translates to:
  /// **'Available input bandwidth cannot support enough partials.'**
  String get calReason9;

  /// No description provided for @calReason10.
  ///
  /// In en, this message translates to:
  /// **'B is not identifiable with sufficient sensitivity.'**
  String get calReason10;

  /// No description provided for @calCurveCaption.
  ///
  /// In en, this message translates to:
  /// **'ET offset (cents) · dots: measured B; line: modeled targets'**
  String get calCurveCaption;

  /// No description provided for @calFitScore.
  ///
  /// In en, this message translates to:
  /// **'Heuristic partial-fit score'**
  String get calFitScore;

  /// No description provided for @calFitScoreNotice.
  ///
  /// In en, this message translates to:
  /// **'Explained peak power × exp(−RMS residual / 2). This is not a calibrated correctness probability.'**
  String get calFitScoreNotice;

  /// No description provided for @calLiveNotice.
  ///
  /// In en, this message translates to:
  /// **'Experimental first-partial measurement: 750 ms windows / 100 ms steps, four consistent frames; slower than ET mode.'**
  String get calLiveNotice;

  /// No description provided for @calSelectedKey.
  ///
  /// In en, this message translates to:
  /// **'Selected target key'**
  String get calSelectedKey;

  /// No description provided for @calNearestEt.
  ///
  /// In en, this message translates to:
  /// **'Nearest ET note (measured)'**
  String get calNearestEt;

  /// No description provided for @calIdentityNotice.
  ///
  /// In en, this message translates to:
  /// **'The selected key is a user choice; the nearest ET note may differ for a stretched target. Frequency alone cannot prove physical key identity.'**
  String get calIdentityNotice;

  /// No description provided for @calPianoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Individual modeled stretch · Experimental'**
  String get calPianoSubtitle;

  /// No description provided for @calUseHints.
  ///
  /// In en, this message translates to:
  /// **'Use historical model search centers'**
  String get calUseHints;

  /// No description provided for @calHintsNotice.
  ///
  /// In en, this message translates to:
  /// **'Search hints only, not valid tuning targets. Choose this explicitly to remeasure an already stretched key. New samples invalidate the old curve; regenerate before applying.'**
  String get calHintsNotice;

  /// No description provided for @calHintUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No historical center for this key; sampling uses the ET association window.'**
  String get calHintUnavailable;

  /// No description provided for @calAssociationCenter.
  ///
  /// In en, this message translates to:
  /// **'Current association center'**
  String get calAssociationCenter;

  /// No description provided for @pauseMetronome.
  ///
  /// In en, this message translates to:
  /// **'Pause metronome'**
  String get pauseMetronome;

  /// No description provided for @resumeMetronome.
  ///
  /// In en, this message translates to:
  /// **'Resume metronome'**
  String get resumeMetronome;

  /// No description provided for @metronomePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused · position retained'**
  String get metronomePaused;

  /// No description provided for @metronomeTransition.
  ///
  /// In en, this message translates to:
  /// **'Changing playback state…'**
  String get metronomeTransition;

  /// No description provided for @metronomeTransportNotice.
  ///
  /// In en, this message translates to:
  /// **'Pause retains the beat and remaining interval after a short fade. Resume continues there. Stop resets the position; Start begins on beat 1. Paused playback stays exclusive; leaving or backgrounding stops it.'**
  String get metronomeTransportNotice;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
