import '../models.dart';

const _systemNames = {
  'one ui home',
  'system ui',
  'launcher',
  'home',
  'settings',
  'pixel launcher',
  'samsung experience home',
  'android system',
};

/// Launchers and Android's own UI are technically foreground apps, but counting
/// them as screen time shows rows like "One UI Home · 2h", which tells nobody
/// anything and inflates the wasted total.
///
/// The native query drops them too; this is the second line of defence so an
/// older payload or a differently-named launcher never reaches the screens.
bool isSystemApp(String packageId, String name) {
  if (packageId.isEmpty || packageId == 'android') return true;
  final id = packageId.toLowerCase();
  if (id.contains('launcher') ||
      id.contains('systemui') ||
      id.contains('system.ui') ||
      id.contains('setupwizard') ||
      id.contains('permissioncontroller') ||
      id.contains('packageinstaller') ||
      id == 'com.android.settings' ||
      id.endsWith('.settings')) {
    return true;
  }
  return _systemNames.contains(name.toLowerCase().trim());
}

/// Drops system rows from apps, daily totals, opens and hourly buckets.
UsageData stripSystemApps(UsageData data) {
  bool drop(String id, String? name) => name == null
      ? isSystemApp(id, '')
      : isSystemApp(id, name);

  final removed = <String>{
    for (final entry in data.apps.entries)
      if (drop(entry.key, entry.value.name)) entry.key,
  };
  void consider(String id) {
    if (drop(id, null)) removed.add(id);
  }

  // Apps outside the top-N never appear in [apps], but their minutes still sit
  // in the daily rows. Check those ids against the package-name rules too.
  for (final row in data.daily.values) {
    row.keys.forEach(consider);
  }
  data.opensToday.keys.forEach(consider);
  data.hourlyToday.keys.forEach(consider);
  if (removed.isEmpty) return data;

  final apps = <String, AppMeta>{
    for (final entry in data.apps.entries)
      if (!removed.contains(entry.key)) entry.key: entry.value,
  };
  final daily = <int, Map<String, int>>{};
  data.daily.forEach((key, row) {
    final kept = <String, int>{
      for (final entry in row.entries)
        if (!removed.contains(entry.key)) entry.key: entry.value,
    };
    if (kept.isNotEmpty) daily[key] = kept;
  });
  final opens = <String, int>{
    for (final entry in data.opensToday.entries)
      if (!removed.contains(entry.key)) entry.key: entry.value,
  };
  final hourly = <String, List<int>>{
    for (final entry in data.hourlyToday.entries)
      if (!removed.contains(entry.key)) entry.key: entry.value,
  };

  return UsageData(
    apps: apps,
    daily: daily,
    opensToday: opens,
    hourlyToday: hourly,
    sample: data.sample,
  );
}
