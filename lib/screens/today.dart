import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/coachmark.dart';
import '../widgets/ui.dart';
import 'app_detail.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.onOpenSettings,
    required this.onOpenVerdict,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenVerdict;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final summary = state.todaySummary;
    final slices = state.todaySlices;
    final yesterday = state.usage.totalOn(
      dayKeyOf(dayOffset(state.today, -1)),
    );
    final delta = summary.total - yesterday;
    final top = slices.take(5).toList();
    final maxMinutes = slices.isEmpty ? 1 : slices.first.minutes;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(kScreenPad, 8, kScreenPad, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MonoLabel(dayLabel(state.today)),
                            const SizedBox(height: 2),
                            Text('Today',
                                style: display(28, weight: 800, tracking: -0.03)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: onOpenSettings,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: C.border, width: 1.5),
                          ),
                          child: Text(state.settings.tone.label,
                              style: mono(12, color: C.ink, tracking: 0.02)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const MonoLabel('Screen time'),
                  const SizedBox(height: 4),
                  Text(dur(summary.total),
                      style: display(72, weight: 800, tracking: -0.045, height: 0.95)),
                  const SizedBox(height: 6),
                  _Delta(minutes: delta),
                  const SizedBox(height: 18),
                  SplitBar(
                    wasted: summary.wasted,
                    neutral: summary.neutral,
                    productive: summary.productive,
                  ),
                  const SizedBox(height: 12),
                  SplitLegend(summary: summary),
                  const SizedBox(height: 22),
                  Column(
                    key: CoachKeys.topApps,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(
                        'Top apps',
                        trailing: Text(
                          '${top.length} of ${slices.length}',
                          style: mono(11, tracking: 0.02),
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final slice in top)
                        _AppRow(
                          slice: slice,
                          maxMinutes: maxMinutes,
                          onTap: () => pushAppDetail(context, slice.meta),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kScreenPad, 10, kScreenPad, 14),
            child: KeyedSubtree(
              key: CoachKeys.verdictCard,
              child: _VerdictTeaser(state: state, onTap: onOpenVerdict),
            ),
          ),
        ],
      ),
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    if (minutes == 0) {
      return Text('Same as yesterday', style: mono(13, color: C.muted));
    }
    final up = minutes > 0;
    return Row(
      children: [
        Icon(
          up ? Icons.north_east : Icons.south_east,
          size: 14,
          color: up ? C.orange : C.lime,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '${dur(minutes.abs())} ${up ? 'more' : 'less'} than yesterday',
            style: mono(13, color: up ? C.orange : C.lime),
          ),
        ),
      ],
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.slice,
    required this.maxMinutes,
    required this.onTap,
  });

  final DaySlice slice;
  final int maxMinutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fraction = maxMinutes <= 0 ? 0.0 : slice.minutes / maxMinutes;
    final color = tagColor(slice.tag);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            AppAvatar(slice.meta.initials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Name and tag sit together on the left, the time sits on
                  // the right. Giving the tag the spare width pushed it to the
                  // middle of the row, which read like justified text.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                slice.meta.name,
                                style: display(15, weight: 600, tracking: -0.01),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                slice.tag.label,
                                style: mono(11, color: color, tracking: 0.02),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(dur(slice.minutes),
                          style: mono(14, color: C.ink, tracking: 0)),
                    ],
                  ),
                  const SizedBox(height: 7),
                  // The track is full width and the fill starts at its left
                  // edge. Without the explicit width the whole bar shrank to
                  // the fill and the Column centred it, so short bars floated
                  // towards the middle of the row.
                  SizedBox(
                    height: 6,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: C.surface2),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: fraction.clamp(0.02, 1.0),
                              heightFactor: 1,
                              child: ColoredBox(color: tagBarColor(slice.tag)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerdictTeaser extends StatelessWidget {
  const _VerdictTeaser({required this.state, required this.onTap});

  final AppState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final verdict = state.verdict;
    final wasted = state.todaySummary.wasted;
    final label = state.verdictLoading
        ? "Today's verdict · writing"
        : state.verdictStale
            ? "Today's verdict · out of date"
            : verdict != null
                ? "Today's verdict · ready"
                : "Today's verdict · waiting";
    final line = state.verdictLoading
        ? 'Reading your day. Hold on.'
        : verdict?.oneLiner ??
            (wasted > 0
                ? '${dur(wasted)} gone. ${state.settings.goal} is still waiting.'
                : 'Nothing wasted yet today. Suspicious.');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoLabel(label, color: C.orange),
                  const SizedBox(height: 4),
                  Text(line,
                      style: display(16, weight: 600, height: 1.25, tracking: -0.01),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: C.border, width: 1.5),
              ),
              child: const Icon(Icons.arrow_forward, size: 16, color: C.ink),
            ),
          ],
        ),
      ),
    );
  }
}
