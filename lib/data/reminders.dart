import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Talks to the native daily reminder.
///
/// Android owns the scheduling: the alarm survives the app being killed and is
/// re-armed after a reboot, which a Dart timer cannot do. Everything here is a
/// no-op off Android and under `flutter test`.
class Reminders {
  static const _channel = MethodChannel('hindsight/reminders');

  static bool get _isTest =>
      !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';

  static bool get _onAndroid =>
      !kIsWeb && !_isTest && defaultTargetPlatform == TargetPlatform.android;

  /// Saves the schedule natively and arms the next alarm.
  static Future<void> sync({
    required bool enabled,
    required int atMinutes,
  }) async {
    if (!_onAndroid) return;
    try {
      await _channel.invokeMethod<void>('schedule', {
        'enabled': enabled,
        'atMinutes': atMinutes,
      }).timeout(const Duration(seconds: 3));
    } catch (_) {
      // A reminder is a nicety; never break the app over it.
    }
  }

  /// False when Android (13+) has not granted POST_NOTIFICATIONS.
  static Future<bool> hasPermission() async {
    if (!_onAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Shows the system prompt on Android 13+. The answer arrives later, so the
  /// caller re-checks [hasPermission] when the app resumes.
  static Future<void> requestPermission() async {
    if (!_onAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestPermission');
    } catch (_) {}
  }

  /// Android's own notification settings, for when the prompt was dismissed
  /// with "don't allow" and the app can no longer ask.
  static Future<void> openSettings() async {
    if (!_onAndroid) return;
    try {
      await _channel.invokeMethod<void>('openSettings');
    } catch (_) {}
  }

  /// False on Android 12+ until the user allows "Alarms & reminders". Without
  /// it Android batches the alarm into a ten-minute window.
  static Future<bool> canScheduleExact() async {
    if (!_onAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('canScheduleExact') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the system screen where exact alarms are allowed.
  static Future<void> openExactSettings() async {
    if (!_onAndroid) return;
    try {
      await _channel.invokeMethod<void>('openExactSettings');
    } catch (_) {}
  }
}
