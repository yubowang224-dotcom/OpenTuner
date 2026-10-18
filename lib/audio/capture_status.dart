import '../l10n/generated/app_localizations.dart';
import 'audio_capture.dart';

String captureStatusLabel(CaptureStatus status, AppLocalizations s) =>
    switch (status) {
      CaptureStatus.idle => s.micIdle,
      CaptureStatus.starting => s.micStarting,
      CaptureStatus.running => s.micRunning,
      CaptureStatus.unsupported => s.micUnsupported,
      CaptureStatus.permissionDenied => s.micDenied,
      CaptureStatus.permissionSettings => s.micSettings,
      CaptureStatus.permissionRevoked => s.micRevoked,
      CaptureStatus.background => s.micBackground,
      CaptureStatus.deviceChanged => s.micDeviceChanged,
      CaptureStatus.silenced => s.micSilenced,
      CaptureStatus.interrupted => s.micInterrupted,
      CaptureStatus.stalled => s.micStalled,
      CaptureStatus.error => s.micError,
    };
