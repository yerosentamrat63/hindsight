import 'package:flutter_test/flutter_test.dart';
import 'package:hindsight/ai/local_verdict.dart';
import 'package:hindsight/ai/milestones.dart';
import 'package:hindsight/ai/verdict_context.dart';
import 'package:hindsight/data/system_apps.dart';
import 'package:hindsight/format.dart';
import 'package:hindsight/models.dart';

VerdictContext _context() => const VerdictContext(
      tone: Tone.roast,
      goal: 'UI/UX designer',
      paceMinutes: 60,
      wastedToday: 273,
      neutralToday: 52,
      productiveToday: 47,
      wastedWeek: 2079,
      wastedPrevWeek: 2292,
      limitMinutes: 240,
      opensToday: 142,
      topApps: [
        AppLine(name: 'TikTok', minutes: 160, tag: AppTag.wasted),
        AppLine(name: 'Instagram', minutes: 65, tag: AppTag.wasted),
      ],
    );

void main() {
  test('milestones scale the real week, not 365 days', () {
    final plan = planFor(goal: 'UI/UX designer', wastedWeek: 2079);

    expect(plan.items.length, 2);
    expect(plan.twoWeeks.horizon, 'In 2 weeks');
    expect(plan.twoWeeks.weeks, 2);
    expect(plan.fourMonths.weeks, 17);
    // 34h 39m a week -> 69h in two weeks.
    expect(plan.hoursOf(plan.twoWeeks), 69);
    expect(plan.hoursOf(plan.fourMonths), 589);
    expect(plan.twoWeeks.text, contains('case study'));
    expect(plan.fourMonths.text, contains('portfolio'));
    // 34h 39m a week is 69 hours per fortnight, not "1h 9m".
    expect(plan.labelOf(plan.twoWeeks), 'In 2 weeks · 69h');
  });

  test('a software developer goal gets developer milestones', () {
    final plan = planFor(
      goal: 'Make it into bloomberg as Software developer',
      wastedWeek: 3300,
    );
    expect(plan.twoWeeks.text, contains('CV'));
    expect(plan.fourMonths.text, contains('interview'));
    expect(plan.labelOf(plan.fourMonths), 'In 4 months · 935h');
  });

  test('an unknown goal is described in the user\'s own words', () {
    final plan = planFor(goal: 'sourdough baker', wastedWeek: 600);
    expect(plan.twoWeeks.text, contains('sourdough baker'));
  });

  test('the offline roast stays inside the weekly pace', () {
    final verdict = localVerdict(_context(), dayKey: 20261029);

    expect(verdict.body, contains('4h 33m'));
    expect(verdict.headline, contains('designer'));
    expect(verdict.body.toLowerCase(), isNot(contains('a year')));
    expect(verdict.body, contains('2 weeks'));
    expect(verdict.body, contains('case study'));
  });

  test('launchers and system UI are not screen time', () {
    expect(isSystemApp('com.sec.android.app.launcher', 'One UI Home'), isTrue);
    expect(isSystemApp('com.android.systemui', 'System UI'), isTrue);
    expect(isSystemApp('com.miui.home', 'Home'), isTrue);
    expect(isSystemApp('com.instagram.android', 'Instagram'), isFalse);
    expect(isSystemApp('com.android.chrome', 'Chrome'), isFalse);
  });

  test('stripping system apps clears every map', () {
    const day = 20261029;
    final data = UsageData(
      apps: const {
        'com.instagram.android': AppMeta(
          id: 'com.instagram.android',
          name: 'Instagram',
          initials: 'In',
        ),
        'com.sec.android.app.launcher': AppMeta(
          id: 'com.sec.android.app.launcher',
          name: 'One UI Home',
          initials: 'On',
        ),
        'com.android.systemui': AppMeta(
          id: 'com.android.systemui',
          name: 'System UI',
          initials: 'Sy',
        ),
      },
      daily: const {
        day: {
          'com.instagram.android': 90,
          'com.sec.android.app.launcher': 25,
          'com.android.systemui': 5,
        },
      },
      opensToday: const {
        'com.instagram.android': 8,
        'com.sec.android.app.launcher': 40,
      },
      hourlyToday: const {
        'com.instagram.android': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      },
    );

    final clean = stripSystemApps(data);

    expect(clean.apps.keys, ['com.instagram.android']);
    expect(clean.daily[day]!.keys, ['com.instagram.android']);
    expect(clean.daily[day]!['com.instagram.android'], 90);
    expect(clean.opensToday.keys, ['com.instagram.android']);
    expect(clean.hourlyToday.keys, ['com.instagram.android']);
  });
}
