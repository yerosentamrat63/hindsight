import '../format.dart';
import '../models.dart';

/// Deterministic demo data that lines up with the design:
/// today is 6h 12m total — 4h 33m wasted, 52m neutral, 47m productive.
UsageData buildSampleUsage({DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());

  const meta = <String, AppMeta>{
    'tiktok': AppMeta(id: 'tiktok', name: 'TikTok', initials: 'Tk'),
    'instagram': AppMeta(id: 'instagram', name: 'Instagram', initials: 'Ig'),
    'youtube': AppMeta(id: 'youtube', name: 'YouTube', initials: 'Yt'),
    'x': AppMeta(id: 'x', name: 'X', initials: 'X'),
    'telegram': AppMeta(id: 'telegram', name: 'Telegram', initials: 'Tg'),
    'chrome': AppMeta(id: 'chrome', name: 'Chrome', initials: 'Ch'),
    'notion': AppMeta(id: 'notion', name: 'Notion', initials: 'No'),
    'duolingo': AppMeta(id: 'duolingo', name: 'Duolingo', initials: 'Du'),
  };

  // Wasted minutes for the seven days ending today (design history bars).
  const wastedTargets = <int>[306, 264, 348, 234, 276, 378, 273];
  // The week before, so the history screen has something to compare against.
  const wastedPrevWeek = <int>[340, 320, 355, 300, 330, 350, 297];
  // Two older weeks, used by the goal-progress chart.
  const wastedOlder = <List<int>>[
    [312, 298, 341, 289, 305, 366, 260],
    [331, 309, 352, 295, 318, 372, 279],
  ];

  // Oldest first, 28 days ending today.
  final series = <int>[
    ...wastedOlder[0],
    ...wastedOlder[1],
    ...wastedPrevWeek,
    ...wastedTargets,
  ];

  // Share of the wasted pile, per app.
  const wastedSplit = <String, double>{
    'tiktok': 0.586,
    'instagram': 0.238,
    'x': 0.110,
    'youtube': 0.066,
  };
  const neutralSplit = <String, double>{'telegram': 0.712, 'chrome': 0.288};
  const productiveSplit = <String, double>{'notion': 0.617, 'duolingo': 0.383};

  final daily = <int, Map<String, int>>{};
  for (var i = 0; i < series.length; i++) {
    final date = today.subtract(Duration(days: series.length - 1 - i));
    final wasted = series[i];
    final neutral = (wasted * 0.19).round();
    final productive = (wasted * 0.172).round();
    final row = <String, int>{};
    wastedSplit.forEach((id, share) {
      row[id] = (wasted * share).round();
    });
    neutralSplit.forEach((id, share) {
      row[id] = (neutral * share).round();
    });
    productiveSplit.forEach((id, share) {
      row[id] = (productive * share).round();
    });
    // Give the rounding remainder to TikTok so the day totals are exact.
    final rest = row.entries
        .where((e) => wastedSplit.containsKey(e.key) && e.key != 'tiktok')
        .fold<int>(0, (s, e) => s + e.value);
    row['tiktok'] = wasted - rest;
    daily[dayKeyOf(date)] = row;
  }

  // Lock today's numbers to the mockup exactly.
  daily[dayKeyOf(today)] = const {
    'tiktok': 160,
    'instagram': 65,
    'x': 30,
    'youtube': 18,
    'telegram': 37,
    'chrome': 15,
    'notion': 29,
    'duolingo': 18,
  };

  final opens = <String, int>{
    'tiktok': 47,
    'instagram': 22,
    'telegram': 31,
    'x': 14,
    'youtube': 9,
    'chrome': 11,
    'notion': 6,
    'duolingo': 2,
  };

  // Evening-heavy profile, used to fake an hourly distribution.
  const profile = <double>[
    0.01, 0.0, 0.0, 0.0, 0.0, 0.0, 0.01, 0.02, 0.03, 0.03, 0.04, 0.04,
    0.06, 0.05, 0.04, 0.04, 0.05, 0.06, 0.07, 0.09, 0.12, 0.13, 0.04, 0.01,
  ];

  final hourly = <String, List<int>>{
    'tiktok': const [
      10, 4, 0, 0, 0, 0, 2, 6, 4, 2, 3, 3,
      12, 8, 3, 3, 4, 6, 8, 10, 24, 48, 0, 0,
    ],
  };
  meta.forEach((id, _) {
    if (hourly.containsKey(id)) return;
    final minutes = daily[dayKeyOf(today)]![id] ?? 0;
    hourly[id] = profile.map((p) => (minutes * p).round()).toList();
  });

  return UsageData(
    apps: meta,
    daily: daily,
    opensToday: opens,
    hourlyToday: hourly,
    sample: true,
  );
}
