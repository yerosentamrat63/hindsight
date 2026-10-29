import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.onOpenApp});

  final void Function(AppMeta meta) onOpenApp;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  /// 0 = today by the hour, 1 = the last seven days, 2 = the last 28 days.
  int _span = 1;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tags = state.effectiveTags;
    final limit = state.limitMinutes;
    final isDay = _span == 0;
    final isWeek = _span == 1;
    final days = isDay ? 1 : (isWeek ? 7 : 28);

    final keys = state.usage.lastDays(state.today, days);
    final summaries = [
      for (final k in keys)
        state.usage.summaryOn(k, dateFromKey(k), tags),
    ];
    final wasted = summaries.fold<int>(0, (a, b) => a + b.wasted);

    // Android's event log can be patchy for the older parts of the day, which
    // made an hourly chart disagree with the day total. The day's app
    // breakdown always adds up to the number above it.
    final daySlices = isDay
        ? state.usage
            .slicesOn(state.todayKey, tags)
            .where((s) => s.tag == AppTag.wasted)
            .toList()
        : const <DaySlice>[];

    final bars = <_Bar>[];
    if (isDay) {
      final slices = daySlices.take(8).toList();
      for (final slice in slices) {
        bars.add(_Bar(
          label: slice.meta.initials,
          value: dur(slice.minutes),
          minutes: slice.minutes,
          highlight: slice == slices.first,
        ));
      }
    } else if (isWeek) {
      for (final s in summaries) {
        bars.add(_Bar(
          label: weekdayShort(s.date),
          value: hmmColon(s.wasted),
          minutes: s.wasted,
          highlight: s.date == state.today,
        ));
      }
    } else {
      for (var i = 0; i < summaries.length; i += 7) {
        final group = summaries.sublist(i, math.min(i + 7, summaries.length));
        final minutes = group.fold<int>(0, (a, b) => a + b.wasted);
        bars.add(_Bar(
          label: '${group.first.date.day}',
          value: '${minutes ~/ 60}h',
          minutes: minutes,
          highlight: i + 7 >= summaries.length,
        ));
      }
    }

    // A day bar covers three hours, so its limit line is a share of the day.
    final bucketLimit =
        isDay ? null : (isWeek ? limit : limit * 7);
    final best = isDay
        ? null
        : summaries.reduce((a, b) => a.wasted <= b.wasted ? a : b);
    final underLimit = summaries.where((s) => s.wasted <= limit).length;
    final yesterdayWasted = state.usage
        .summaryOn(dayKeyOf(state.today.subtract(const Duration(days: 1))),
            state.today.subtract(const Duration(days: 1)), tags)
        .wasted;
    final dayShare = summaries.first.total <= 0
        ? 0
        : (summaries.first.wasted * 100 / summaries.first.total).round();

    final appTotals = <String, int>{};
    for (final id in state.usage.apps.keys) {
      if (tags[id] != AppTag.wasted) continue;
      var total = 0;
      for (final k in keys) {
        total += state.usage.minutesOn(k, id);
      }
      if (total > 0) appTotals[id] = total;
    }
    final worstEntry = appTotals.entries.isEmpty
        ? null
        : appTotals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final worst = worstEntry == null ? null : state.usage.apps[worstEntry.key];
    final worstMinutes = worstEntry?.value ?? 0;

    final delta = isDay ? wasted - yesterdayWasted : wasted - state.wastedPrevWeek;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(kScreenPad, 8, kScreenPad, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 40,
                    child: Text('History',
                        style: display(28, weight: 800, tracking: -0.03)),
                  ),
                  const SizedBox(height: 14),
                  _Segments(
                    value: _span,
                    onChange: (v) => setState(() => _span = v),
                  ),
                  const SizedBox(height: 20),
                  MonoLabel(
                    isDay
                        ? 'Wasted · today by app'
                        : isWeek
                            ? 'Wasted · ${weekSpan(summaries.map((s) => s.date).toList())}'
                            : 'Wasted · last ${summaries.length} days',
                  ),
                  const SizedBox(height: 4),
                  Text(durLong(wasted),
                      style: display(56,
                          weight: 800, tracking: -0.045, height: 0.95, color: C.orange)),
                  const SizedBox(height: 8),
                  if (isDay && yesterdayWasted > 0)
                    Row(
                      children: [
                        Icon(
                          delta <= 0 ? Icons.south_east : Icons.north_east,
                          size: 14,
                          color: delta <= 0 ? C.lime : C.orange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          delta == 0
                              ? 'Same as yesterday'
                              : '${dur(delta.abs())} ${delta < 0 ? 'less' : 'more'} than yesterday',
                          style: mono(13,
                              color: delta <= 0 ? C.lime : C.orange),
                        ),
                      ],
                    )
                  else if (isWeek && state.wastedPrevWeek > 0)
                    Row(
                      children: [
                        Icon(
                          delta <= 0 ? Icons.south_east : Icons.north_east,
                          size: 14,
                          color: delta <= 0 ? C.lime : C.orange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          delta == 0
                              ? 'Same as last week'
                              : '${dur(delta.abs())} ${delta < 0 ? 'less' : 'more'} than last week',
                          style: mono(13,
                              color: delta <= 0 ? C.lime : C.orange),
                        ),
                      ],
                    )
                  else
                    Text('Daily limit ${dur(limit)}', style: mono(13)),
                  const SizedBox(height: 22),
                  _Chart(bars: bars, limitMinutes: bucketLimit),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniCard(
                          label: isDay ? 'Biggest app' : 'Best day',
                          value: isDay
                              ? (daySlices.isEmpty
                                  ? 'Nothing wasted'
                                  : daySlices.first.meta.name)
                              : '${weekdayName(best!.date)} · ${dur(best.wasted)}',
                          compact: isDay,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniCard(
                          label: isDay ? 'Wasted share' : 'Under limit',
                          value: isDay
                              ? '$dayShare% of screen time'
                              : '$underLimit of ${summaries.length} days',
                          compact: isDay,
                        ),
                      ),
                    ],
                  ),
                  if (worst != null) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => widget.onOpenApp(worst),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 60),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: cardDecoration(radius: 18),
                        child: Row(
                          children: [
                            AppAvatar(worst.initials),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Most wasted app: ${worst.name}',
                                      style: display(15, weight: 600, tracking: -0.01)),
                                  const SizedBox(height: 2),
                                  Text('${dur(worstMinutes)} in this period',
                                      style: mono(12, tracking: 0.02)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 20, color: C.muted),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar {
  const _Bar({
    required this.label,
    required this.value,
    required this.minutes,
    required this.highlight,
  });

  final String label;
  final String value;
  final int minutes;
  final bool highlight;
}

class _Segments extends StatelessWidget {
  const _Segments({required this.value, required this.onChange});

  final int value;
  final ValueChanged<int> onChange;

  static const _labels = ['Day', 'Week', 'Month'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: C.border, width: 1.5),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChange(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == value ? C.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _labels[i],
                    style: display(14,
                        weight: i == value ? 700 : 600,
                        color: i == value ? C.bg : C.muted),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.bars, required this.limitMinutes});

  final List<_Bar> bars;
  final int? limitMinutes;

  @override
  Widget build(BuildContext context) {
    const height = 182.0;
    const labelSpace = 26.0;
    final barArea = height - labelSpace;
    final line = limitMinutes;
    final maxValue = math.max(
      line ?? 0,
      bars.fold<int>(1, (m, b) => math.max(m, b.minutes)),
    );

    return Column(
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final bar in bars)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(bar.value,
                                style: mono(11, color: C.inkDim, tracking: 0)),
                            const SizedBox(height: 6),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 320),
                              height: math.max(4.0, barArea * bar.minutes / maxValue),
                              decoration: BoxDecoration(
                                color: line == null || bar.minutes <= line
                                    ? C.lime
                                    : C.orange,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                  bottomLeft: Radius.circular(3),
                                  bottomRight: Radius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (line != null) ...[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: labelSpace + barArea * line / maxValue,
                  child: const IgnorePointer(
                    child: SizedBox(
                      height: 2,
                      child: CustomPaint(painter: DashedLinePainter()),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: labelSpace + 4 + barArea * line / maxValue,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    color: C.bg,
                    child: Text('${dur(line)} limit',
                        style: mono(11, tracking: 0)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final bar in bars)
              Expanded(
                child: Center(
                  child: Text(
                    bar.label,
                    style: mono(11,
                        color: bar.highlight ? C.ink : C.muted,
                        weight: bar.highlight ? 700 : 400,
                        tracking: 0),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: cardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(label, size: 11, tracking: 0.06),
          const SizedBox(height: 4),
          Text(value,
              style: display(compact ? 16 : 20,
                  weight: 700, tracking: -0.02),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
