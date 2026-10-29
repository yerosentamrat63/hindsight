import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pushes the numbers the home-screen widgets show into the native
/// AppWidgetProviders.
///
/// Android widgets cannot run Dart, so the app writes a small JSON snapshot and
/// asks the providers to redraw. Failure is ignored: a launcher widget is a
/// nicety and must never break the app.
class HomeWidgets {
  static const _channel = MethodChannel('hindsight/widgets');

  /// Nothing answers this channel under `flutter test`, and a pending platform
  /// call would hang the test binding, so tests skip it entirely.
  static bool get _isTest =>
      !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';

  static Future<void> publish(Map<String, Object?> snapshot) async {
    if (kIsWeb || _isTest || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel
          .invokeMethod<void>('update', jsonEncode(snapshot))
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Native side absent or the launcher is busy; never break the app.
    }
  }
}
