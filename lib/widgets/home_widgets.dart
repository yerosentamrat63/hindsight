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
  static bool get isTest =>
      !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';

  static Future<void> publish(Map<String, Object?> snapshot) async {
    if (kIsWeb || isTest || defaultTargetPlatform != TargetPlatform.android) {
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

  /// The size each placed widget's cell actually has, in dp, so the widgets are
  /// drawn at the shape the launcher will show instead of the board's artboard.
  static Future<Map<String, Size>> sizes() async {
    if (kIsWeb || isTest || defaultTargetPlatform != TargetPlatform.android) {
      return const {};
    }
    try {
      final raw = await _channel
          .invokeMethod<String>('sizes')
          .timeout(const Duration(seconds: 2));
      if (raw == null) return const {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          entry.key: Size(
            (entry.value[0] as num).toDouble(),
            (entry.value[1] as num).toDouble(),
          ),
      };
    } catch (_) {
      return const {};
    }
  }

  /// Hands the native providers the PNGs the widgets were drawn into.
  ///
  /// Android widgets cannot load the app's fonts — the launcher inflates them
  /// in its own process, where `@font` quietly falls back to the system face —
  /// so [WidgetPngHost] draws each widget with Flutter and the provider only
  /// shows the file.
  static Future<void> publishImages(Map<String, String> paths) async {
    if (kIsWeb || isTest || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel
          .invokeMethod<void>('updateImages', paths)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Never break the app over a home-screen nicety.
    }
  }
}
