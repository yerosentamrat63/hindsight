import '../format.dart';

/// What the user says they are becoming, translated into a concrete thing the
/// wasted hours could buy.
class GoalProfile {
  const GoalProfile({
    required this.role,
    required this.twoWeeks,
    required this.fourMonths,
  });

  final String role;

  /// Believable result of roughly two weeks of daily practice.
  final String twoWeeks;

  /// Believable result of roughly four months of daily practice.
  final String fourMonths;
}

/// Maps a free-text goal to a plausible ladder. Unknown goals fall back to the
/// user's own words rather than an invented career.
GoalProfile profileForGoal(String goal) {
  final g = goal.toLowerCase();
  if (g.contains('design') || g.contains('ui') || g.contains('ux')) {
    return const GoalProfile(
      role: 'designer',
      twoWeeks: 'one finished case study — research, wireframes and a polished '
          'final screen',
      fourMonths: 'three case studies and a portfolio you can send to studios',
    );
  }
  if (g.contains('backend') || g.contains('server')) {
    return const GoalProfile(
      role: 'backend developer',
      twoWeeks: 'one small API with real auth and a database you understand',
      fourMonths: 'three deployed services and a GitHub that explains them',
    );
  }
  if (g.contains('mobile') || g.contains('android') || g.contains('ios')) {
    return const GoalProfile(
      role: 'mobile developer',
      twoWeeks: 'one app flow shipped end to end, not just the screens',
      fourMonths: 'an app in closed testing with the hard parts finished',
    );
  }
  if (g.contains('developer') ||
      g.contains('engineer') ||
      g.contains('software') ||
      g.contains('programmer') ||
      g.contains('coder')) {
    return const GoalProfile(
      role: 'developer',
      twoWeeks: 'one small project finished end to end and on your CV',
      fourMonths:
          'a portfolio and interview practice that survives a real loop',
    );
  }
  if (g.contains('data') || g.contains('ml') || g.contains('ai')) {
    return const GoalProfile(
      role: 'data scientist',
      twoWeeks: 'one dataset cleaned, modelled and charted end to end',
      fourMonths: 'three real projects and the maths behind them',
    );
  }
  if (g.contains('writ') || g.contains('author') || g.contains('book')) {
    return const GoalProfile(
      role: 'writer',
      twoWeeks: 'ten thousand words of a first draft',
      fourMonths: 'a finished draft you can actually edit',
    );
  }
  if (g.contains('athlet') ||
      g.contains('strong') ||
      g.contains('fit') ||
      g.contains('gym') ||
      g.contains('run')) {
    return const GoalProfile(
      role: 'stronger athlete',
      twoWeeks: 'twelve real sessions and a first measurable gain',
      fourMonths: 'a full training block done and a personal best on the board',
    );
  }
  if (g.contains('music') ||
      g.contains('produc') ||
      g.contains('guitar') ||
      g.contains('piano')) {
    return const GoalProfile(
      role: 'musician',
      twoWeeks: 'two finished tracks instead of two more sketches',
      fourMonths: 'an EP of five finished tracks',
    );
  }
  if (g.contains('language') ||
      g.contains('spanish') ||
      g.contains('japanese') ||
      g.contains('french') ||
      g.contains('german') ||
      g.contains('korean')) {
    return const GoalProfile(
      role: 'speaker',
      twoWeeks: '300 words you can actually use in a sentence',
      fourMonths: 'a conversation without switching back to English',
    );
  }
  final words = goal.trim().toLowerCase();
  return GoalProfile(
    role: words.isEmpty ? 'goal' : words,
    twoWeeks:
        'one real piece of work towards "$words" that you can show someone',
    fourMonths: 'a finished version of it, not another folder of beginnings',
  );
}

class Milestone {
  const Milestone({
    required this.horizon,
    required this.weeks,
    required this.text,
  });

  /// "In 2 weeks", "In 4 months".
  final String horizon;
  final int weeks;
  final String text;
}

/// Two milestones at the pace the user actually kept this week.
///
/// Deliberately not a 365-day projection: one heavy day multiplied by a year is
/// not a prediction, it is a scare tactic nobody believes.
class MilestonePlan {
  const MilestonePlan({required this.weeklyMinutes, required this.items});

  final int weeklyMinutes;
  final List<Milestone> items;

  Milestone get twoWeeks => items.first;
  Milestone get fourMonths => items.last;

  bool get hasTime => weeklyMinutes > 0;

  int hoursOf(Milestone milestone) => (weeklyMinutes * milestone.weeks) ~/ 60;

  /// "In 2 weeks · 18h"
  String labelOf(Milestone milestone) =>
      '${milestone.horizon} · ${thousands(hoursOf(milestone))}h';
}

/// `wastedWeek` is the last seven days of wasted minutes, so 2 weeks really
/// means "two weeks at this week's pace".
MilestonePlan planFor({required String goal, required int wastedWeek}) {
  final profile = profileForGoal(goal);
  return MilestonePlan(
    weeklyMinutes: wastedWeek < 0 ? 0 : wastedWeek,
    items: [
      Milestone(horizon: 'In 2 weeks', weeks: 2, text: profile.twoWeeks),
      Milestone(horizon: 'In 4 months', weeks: 17, text: profile.fourMonths),
    ],
  );
}
