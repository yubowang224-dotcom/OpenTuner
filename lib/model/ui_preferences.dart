import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Only versioned appearance scalars cross this boundary. No audio/session data.
abstract interface class UiPreferences {
  bool get supported;
  Future<Map<Object?, Object?>> read();
  Future<void> write(Map<String, Object> values);
}

class AndroidUiPreferences implements UiPreferences {
  const AndroidUiPreferences();
  static const channel = MethodChannel('org.opentune/preferences');
  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  Future<Map<Object?, Object?>> read() async =>
      await channel.invokeMapMethod<Object?, Object?>('read') ?? {};
  @override
  Future<void> write(Map<String, Object> values) =>
      channel.invokeMethod<void>('write', values);
}
