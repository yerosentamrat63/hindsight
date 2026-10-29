import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

void pushAppDetail(BuildContext context, AppMeta meta) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => AppDetailScreen(meta: meta)),
  );
}

class AppDetailScreen extends StatelessWidget {
  const AppDetailScreen({super.key, required this.meta});

  final AppMeta meta;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tag = state.tagFor(meta);
    final today = state.todayMinutesOf(meta.id);
    final week = state.weekMinutesOf(meta.id);
    final opens = state.usage.opensToday[meta.id] ?? 0;
    final hourly = state.usage.hourlyToday[meta.id] ?? List<int>.filled(24, 0);
    final peak = hourly.reduce((a, b) => a > b ? a : b);
    final peakHour = hourly.indexOf(peak);
    final pace = (week / 7).round();
    final yearHours = (pace * 365) ~/ 60;
    final fullDays = (pace * 365) ~/ 1440;
    final perOpenSeconds = opens == 0 ? 0 : (today * 60) ~/ opens;

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kScreenPad, 4, kScreenPad, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          AppAvatar(meta.initials, size: 56),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(meta.name,
                                    style: display(32,
                                        weight: 800, tracking: -0.035, height: 1)),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => state.cycleTag(meta.id),
                                  behavior: HitTestBehavior.opaque,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: TagChip(tag: tag),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _StatCell(label: 'Today', value: dur(today))),
                          const SizedBox(width: 8),
                          Expanded(child: _StatCell(label: 'Week', value: dur(week))),
                          const SizedBox(width: 8),
                          Expanded(child: _StatCell(label: 'Opens', value: '$opens')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: MonoLabel('When you open it · today'),
                                ),
                                Text(
                                  peak <= 0 ? '—' : 'Peak ${clockLabel(peakHour * 60)}',
                                  style: mono(11, color: C.orange, tracking: 0.02),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            HourlyBars(minutes: hourly),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (final label in ['00', '06', '12', '18', '23'])
                                  Text(label, style: mono(11, tracking: 0)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              opens == 0
                                  ? 'Not opened today.'
                                  : '$opens opens, ${perOpenSeconds ~/ 60}m ${perOpenSeconds % 60}s on average each time.',
                              style: display(13, weight: 400, color: C.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MonoLabel('At your 7-day pace of ${dur(pace)} a day'),
                            const SizedBox(height: 6),
                            Text('${thousands(yearHours)} hours',
                                style: display(44,
                                    weight: 800,
                                    tracking: -0.04,
                                    height: 1,
                                    color: C.orange)),
                            const SizedBox(height: 6),
                            Text(
                              'a year, or about $fullDays full days. Calculated on your phone.',
                              style: display(15, weight: 400, color: C.inkDim, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _pickLimit(context, state),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: C.border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 22, color: C.ink),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Daily wasted-time limit',
                            style: display(15, weight: 600)),
                      ),
                      Text(dur(state.limitMinutes),
                          style: mono(12, tracking: 0.02)),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, size: 18, color: C.muted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickLimit(BuildContext context, AppState state) {
    const options = [60, 120, 180, 240, 300];
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daily wasted-time limit',
                  style: display(22, weight: 800, tracking: -0.03)),
              const SizedBox(height: 4),
              Text('The line on your history chart. Verdicts use it too.',
                  style: display(14, weight: 400, color: C.muted)),
              const SizedBox(height: 16),
              for (final minutes in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () {
                      state.setLimit(minutes);
                      Navigator.of(sheetContext).pop();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: minutes == state.limitMinutes ? C.ink : C.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: minutes == state.limitMinutes ? C.ink : C.border,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              minutes == 60 ? '1 hour a day' : '${minutes ~/ 60} hours a day',
                              style: display(15,
                                  weight: 600,
                                  color: minutes == state.limitMinutes ? C.bg : C.ink),
                            ),
                          ),
                          if (minutes == state.limitMinutes)
                            const Icon(Icons.check, size: 18, color: C.bg),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(label, size: 11, tracking: 0.06),
          const SizedBox(height: 4),
          Text(value,
              style: display(20, weight: 700, tracking: -0.02),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
