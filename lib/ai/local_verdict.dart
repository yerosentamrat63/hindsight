import '../format.dart';
import '../models.dart';
import 'milestones.dart';
import 'verdict_context.dart';

/// "in 2 weeks that is 18h" — falls back to the horizon when there is no week
/// of data to extrapolate from.
String _trade(MilestonePlan plan, Milestone milestone) => plan.hasTime
    ? '${milestone.horizon.toLowerCase()} that is '
        '${durLong(plan.hoursOf(milestone))}'
    : milestone.horizon.toLowerCase();

/// Deterministic fallback so the verdict never comes back empty.
Verdict localVerdict(VerdictContext ctx, {required int dayKey}) {
  final profile = profileForGoal(ctx.goal);
  final plan = ctx.plan;
  final app = ctx.biggest;
  final wasted = ctx.wastedToday;
  final avgPerOpen =
      ctx.opensToday > 0 ? ctx.totalToday ~/ ctx.opensToday : 0;

  if (wasted <= 20) {
    final headline = switch (ctx.tone) {
      Tone.roast => 'Almost nothing to roast. Annoying.',
      Tone.coach => 'That is the kind of day to repeat.',
      Tone.future => 'I remember a day like this. Thank you.',
    };
    final body = switch (ctx.tone) {
      Tone.roast =>
        '${dur(wasted)} wasted and ${dur(ctx.productiveToday)} put towards your '
            'goal. I would call it a fluke, but keep going and I will have to be '
            'nice.',
      Tone.coach =>
        'Only ${dur(wasted)} went to the apps that take and '
            '${dur(ctx.productiveToday)} went to your goal. Keep the '
            '${dur(ctx.paceMinutes)} a day and ${plan.twoWeeks.text} stops being '
            'a wish.',
      Tone.future =>
        'Only ${dur(wasted)} went missing today. I remember this one, because it '
            'is the day the ${profile.role} thing started to look possible.',
    };
    return Verdict(
      headline: headline,
      body: body,
      oneLiner: switch (ctx.tone) {
        Tone.roast => '${dur(wasted)} wasted. Suspicious.',
        Tone.coach => '${dur(ctx.productiveToday)} toward the goal.',
        Tone.future => 'This is the day I remember.',
      },
      dayKey: dayKey,
      source: 'local',
    );
  }

  final headline = switch (ctx.tone) {
    Tone.roast => app == null
        ? '${dur(wasted)} gone and nothing to show for it.'
        : '${dur(wasted)} to ${app.name}, nothing to ${profile.role}.',
    Tone.coach => '${dur(wasted)} that belonged to the ${profile.role} plan.',
    Tone.future => 'I remember this day. I did not build it.',
  };

  final body = switch (ctx.tone) {
    Tone.roast =>
      '${app?.name ?? 'Your top apps'} took ${dur(app?.minutes ?? wasted)} today '
          'and the waste came to ${dur(wasted)}. At this week\'s pace, '
          '${_trade(plan, plan.twoWeeks)} — enough for ${profile.twoWeeks}. You '
          'traded it for ${thousands(ctx.opensToday)} opens, ${dur(avgPerOpen)} '
          'each. The ${profile.role} plan is still a folder.',
    Tone.coach =>
      'You gave ${dur(wasted)} to apps you called wasted and '
          '${dur(ctx.productiveToday)} to your goal. Reclaim the same hours '
          'daily and ${_trade(plan, plan.fourMonths)}: ${profile.fourMonths}. '
          'That is the whole distance between now and ${ctx.goal}.',
    Tone.future =>
      'I am you in five years. ${app?.name ?? 'That app'} took '
          '${dur(app?.minutes ?? wasted)} that day and I told myself it was a '
          'break. The same pace became ${_trade(plan, plan.fourMonths)} of my '
          'life: I could have had ${profile.fourMonths}. I kept the scrolling '
          'and lost the ${profile.role}. You still have today.',
  };

  return Verdict(
    headline: headline,
    body: body,
    oneLiner: switch (ctx.tone) {
      Tone.roast => '${dur(wasted)} gone. Your ${profile.role} plan noticed.',
      Tone.coach => '${dur(wasted)} back if you want it.',
      Tone.future => 'I remember this one.',
    },
    dayKey: dayKey,
    source: 'local',
  );
}
