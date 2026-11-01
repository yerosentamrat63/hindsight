import '../format.dart';
import 'app_meta.dart';
import 'day_slice.dart';
import 'day_summary.dart';

/// Everything we know about the user's usage.
///
/// `daily` is keyed by [dayKeyOf]: day -> appId -> minutes.
class UsageData {
  const UsageData({
    required this.apps,
    required this.daily,
    required this.opensToday,
    required this.hourlyToday,
    this.sample = false,
  });

  final Map<String, AppMeta> apps;
  final Map<int, Map<String, int>> daily;
  final Map<String, int> opensToday;

  /// appId -> 24 buckets of minutes, today only.
  final Map<String, List<int>> hourlyToday;

  /// True when this is generated sample data (desktop/web or no permission).
  final bool sample;

  static UsageData empty() =>
      const UsageData(apps: {}, daily: {}, opensToday: {}, hourlyToday: {});

  int minutesOn(int key, String appId) => daily[key]?[appId] ?? 0;

  int totalOn(int key) {
    final m = daily[key];
    if (m == null) return 0;
    return m.values.fold(0, (a, b) => a + b);
  }

  Iterable<int> get dayKeys => daily.keys;

  /// Sorted list of days, oldest first, with `today` last.
  List<int> lastDays(DateTime today, int count) {
    final out = <int>[];
    for (var i = count - 1; i >= 0; i--) {
      out.add(dayKeyOf(dayOffset(today, -i)));
    }
    return out;
  }

  List<DaySlice> slicesOn(int key, Map<String, AppTag> tags) {
    final m = daily[key] ?? const <String, int>{};
    final out = <DaySlice>[];
    m.forEach((appId, minutes) {
      if (minutes <= 0) return;
      final meta =
          apps[appId] ?? AppMeta(id: appId, name: appId, initials: '?');
      out.add(
        DaySlice(
          meta: meta,
          minutes: minutes,
          tag: tags[appId] ?? AppTag.neutral,
        ),
      );
    });
    out.sort((a, b) => b.minutes.compareTo(a.minutes));
    return out;
  }

  DaySummary summaryOn(int key, DateTime date, Map<String, AppTag> tags) {
    var w = 0, n = 0, p = 0;
    (daily[key] ?? const <String, int>{}).forEach((appId, minutes) {
      switch (tags[appId] ?? AppTag.neutral) {
        case AppTag.wasted:
          w += minutes;
        case AppTag.neutral:
          n += minutes;
        case AppTag.productive:
          p += minutes;
      }
    });
    return DaySummary(date: date, wasted: w, neutral: n, productive: p);
  }

  List<DaySummary> week(DateTime today, Map<String, AppTag> tags) {
    final out = <DaySummary>[];
    for (var i = 6; i >= 0; i--) {
      final d = dayOffset(today, -i);
      out.add(summaryOn(dayKeyOf(d), d, tags));
    }
    return out;
  }

  int weekMinutes(String appId, DateTime today) {
    var total = 0;
    for (var i = 0; i < 7; i++) {
      total += minutesOn(dayKeyOf(dayOffset(today, -i)), appId);
    }
    return total;
  }

  /// Minutes reclaimed for the goal: time spent on productive apps this week.
  int reclaimedWeek(DateTime today, Map<String, AppTag> tags) {
    return week(today, tags).fold<int>(0, (sum, d) => sum + d.productive);
  }

  int wastedWeek(DateTime today, Map<String, AppTag> tags) {
    return week(today, tags).fold<int>(0, (sum, d) => sum + d.wasted);
  }

  int wastedPrevWeek(DateTime today, Map<String, AppTag> tags) {
    var total = 0;
    for (var i = 7; i < 14; i++) {
      final d = dayOffset(today, -i);
      total += summaryOn(dayKeyOf(d), d, tags).wasted;
    }
    return total;
  }
}
