import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import 'sample_usage.dart';
import 'system_apps.dart';

/// Talks to the Android UsageStats bridge. Everywhere else (web, desktop,
/// emulator without the permission) it hands back the sample dataset so the
/// product can still be used and demoed.
class UsageRepository {
  static const MethodChannel _channel = MethodChannel('hindsight/usage');

  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> hasAccess() async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasAccess') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openAccessSettings() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openAccessSettings');
    } on PlatformException {
      // Nothing sensible to do — the user can still open it manually.
    }
  }

  Future<UsageData> load({int days = 14}) async {
    if (!isAndroid) return buildSampleUsage();
    try {
      if (!await hasAccess()) return buildSampleUsage();
      final data = await read(days: days);
      if (data == null || data.daily.isEmpty) return buildSampleUsage();
      return data;
    } catch (_) {
      return buildSampleUsage();
    }
  }

  Future<UsageData?> read({int days = 14}) async {
    final raw = await _channel.invokeMethod<dynamic>('queryUsage', {
      'days': days,
    });
    if (raw is! Map) return null;

    final apps = <String, AppMeta>{};
    final appsRaw = raw['apps'];
    if (appsRaw is Map) {
      appsRaw.forEach((key, value) {
        if (value is Map) {
          final id = key.toString();
          apps[id] = AppMeta(
            id: id,
            name: (value['name'] ?? id).toString(),
            initials: (value['initials'] ?? '?').toString(),
          );
        }
      });
    }

    final daily = <int, Map<String, int>>{};
    final dailyRaw = raw['daily'];
    if (dailyRaw is Map) {
      dailyRaw.forEach((key, value) {
        final dayKey = int.tryParse(key.toString());
        if (dayKey == null || value is! Map) return;
        final row = <String, int>{};
        value.forEach((appId, minutes) {
          final m = minutes is num ? minutes.toInt() : int.tryParse('$minutes');
          if (m != null && m > 0) row[appId.toString()] = m;
        });
        if (row.isNotEmpty) daily[dayKey] = row;
      });
    }

    final opens = <String, int>{};
    final opensRaw = raw['opens'];
    if (opensRaw is Map) {
      opensRaw.forEach((key, value) {
        final n = value is num ? value.toInt() : int.tryParse('$value');
        if (n != null) opens[key.toString()] = n;
      });
    }

    final hourly = <String, List<int>>{};
    final hourlyRaw = raw['hourly'];
    if (hourlyRaw is Map) {
      hourlyRaw.forEach((key, value) {
        if (value is List) {
          hourly[key.toString()] = value
              .map((e) => e is num ? e.toInt() : int.tryParse('$e') ?? 0)
              .toList();
        }
      });
    }

    return stripSystemApps(UsageData(
      apps: apps,
      daily: daily,
      opensToday: opens,
      hourlyToday: hourly,
    ));
  }
}
