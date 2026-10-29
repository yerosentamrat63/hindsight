import 'package:flutter_test/flutter_test.dart';
import 'package:hindsight/ai/local_verdict.dart';
import 'package:hindsight/ai/verdict_context.dart';
import 'package:hindsight/data/sample_usage.dart';
import 'package:hindsight/format.dart';
import 'package:hindsight/models.dart';
import 'package:hindsight/screens/receipt.dart';

VerdictContext _context({Tone tone = Tone.roast, int wasted = 273}) {
  return VerdictContext(
    tone: tone,
    goal: 'UI/UX designer',
    paceMinutes: 60,
    wastedToday: wasted,
    neutralToday: 52,
    productiveToday: 47,
    wastedWeek: 2079,
    wastedPrevWeek: 2292,
    limitMinutes: 240,
    opensToday: 142,
    topApps: const [
      AppLine(name: 'TikTok', minutes: 160, tag: AppTag.wasted),
      AppLine(name: 'Instagram', minutes: 65, tag: AppTag.wasted),
      AppLine(name: 'Telegram', minutes: 37, tag: AppTag.neutral),
    ],
  );
}

void main() {
  test('sample data matches the mockup day', () {
    final now = DateTime(2026, 10, 25, 18);
    final usage = buildSampleUsage(now: now);
    final key = dayKeyOf(dateOnly(now));
    final tags = {
      for (final id in usage.apps.keys) id: _tagOf(id),
    };

    final summary = usage.summaryOn(key, dateOnly(now), tags);
    expect(summary.wasted, 273);
    expect(summary.neutral, 52);
    expect(summary.productive, 47);
    expect(summary.total, 372);

    expect(usage.totalOn(key), 372);
    // 28 days of history for the month view and the goal chart.
    expect(usage.daily.length, 28);
  });

  test('grade for the mockup week is D+', () {
    expect(gradeFor(2079, 240), 'D+');
    expect(gradeFor(0, 240), 'A');
    expect(gradeFor(60 * 24 * 7, 240), 'F');
  });

  test('local verdict fills every voice', () {
    for (final tone in Tone.values) {
      final v = localVerdict(_context(tone: tone), dayKey: 20261025);
      expect(v.headline.trim(), isNotEmpty, reason: '$tone headline');
      expect(v.body.trim(), isNotEmpty, reason: '$tone body');
      expect(v.source, 'local');
      expect(v.oneLiner, isNotNull);
    }
  });

  test('local verdict names the wasted time and the goal', () {
    final v = localVerdict(_context(), dayKey: 20261025);
    expect(v.body, contains('4h 33m'));
    expect('${v.headline} ${v.body}', contains('designer'));
  });
}

AppTag _tagOf(String id) {
  switch (id) {
    case 'tiktok':
    case 'instagram':
    case 'youtube':
    case 'x':
      return AppTag.wasted;
    case 'notion':
    case 'duolingo':
      return AppTag.productive;
    default:
      return AppTag.neutral;
  }
}
