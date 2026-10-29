import '../format.dart';
import '../models.dart';
import 'milestones.dart';

class AppLine {
  const AppLine({required this.name, required this.minutes, required this.tag});

  final String name;
  final int minutes;
  final AppTag tag;
}

/// Everything the verdict generator is allowed to know. Only daily totals and
/// the top apps leave the phone — never a minute-by-minute timeline.
class VerdictContext {
  const VerdictContext({
    required this.tone,
    required this.goal,
    required this.paceMinutes,
    required this.wastedToday,
    required this.neutralToday,
    required this.productiveToday,
    required this.wastedWeek,
    required this.wastedPrevWeek,
    required this.limitMinutes,
    required this.opensToday,
    required this.topApps,
    this.sample = false,
  });

  final Tone tone;
  final String goal;
  final int paceMinutes;
  final int wastedToday;
  final int neutralToday;
  final int productiveToday;
  final int wastedWeek;
  final int wastedPrevWeek;
  final int limitMinutes;
  final int opensToday;
  final List<AppLine> topApps;
  final bool sample;

  int get totalToday => wastedToday + neutralToday + productiveToday;
  int get weekDelta => wastedWeek - wastedPrevWeek;
  int get avgWastedDay => (wastedWeek / 7).round();

  /// Two believable milestones at this week's pace.
  MilestonePlan get plan => planFor(goal: goal, wastedWeek: wastedWeek);

  AppLine? get biggest => topApps.isEmpty ? null : topApps.first;

  /// Human-readable block handed to the model.
  String statsBlock() {
    final milestones = plan.items
        .map((m) => '- ${m.horizon} (~${durLong(plan.hoursOf(m))}): ${m.text}')
        .join('\n');
    final lines = <String>[
      'Goal: $goal (wants to give it ${dur(paceMinutes)} a day)',
      'Wasted today: ${dur(wastedToday)}',
      'Neutral today: ${dur(neutralToday)}',
      'Productive today: ${dur(productiveToday)}',
      'Total screen time today: ${dur(totalToday)}',
      'Wasted this week (last 7 days): ${dur(wastedWeek)} '
          '(the week before: ${dur(wastedPrevWeek)})',
      'Average wasted per day this week: ${dur(avgWastedDay)}',
      'Daily wasted limit: ${dur(limitMinutes)}',
      'App opens today: $opensToday',
      'Top apps today:',
      for (final a in topApps.take(3))
        '- ${a.name}: ${dur(a.minutes)} (${a.tag.label.toLowerCase()})',
      if (plan.hasTime) ...[
        '',
        'What the same weekly pace buys toward the goal:',
        milestones,
      ],
    ];
    return lines.join('\n');
  }
}
