import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// The tappable list of tracked apps used both in onboarding and in Settings.
class ClassifyList extends StatelessWidget {
  const ClassifyList({super.key, this.maxRows});

  final int? maxRows;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final entries = state.usage.apps.values.toList()
      ..sort(
        (a, b) => state.usage
            .weekMinutes(b.id, state.today)
            .compareTo(state.usage.weekMinutes(a.id, state.today)),
      );

    final rows = maxRows == null ? entries : entries.take(maxRows!).toList();

    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: C.hairline),
            _ClassifyRow(meta: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _ClassifyRow extends StatelessWidget {
  const _ClassifyRow({required this.meta});

  final AppMeta meta;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tag = state.tagFor(meta);
    final week = state.usage.weekMinutes(meta.id, state.today);
    final perDay = (week / 7).round();

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          AppAvatar(meta.initials),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.name,
                  style: display(15, weight: 600, tracking: -0.01),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text('${dur(perDay)} / day', style: mono(11, tracking: 0.02)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => state.cycleTag(meta.id),
            child: Container(
              height: 44,
              constraints: const BoxConstraints(minWidth: 104),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: switch (tag) {
                  AppTag.wasted => C.orangeWash,
                  AppTag.productive => C.limeWash,
                  AppTag.neutral => C.surface2,
                },
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: switch (tag) {
                    AppTag.wasted => const Color(0x8CFF6B3D),
                    AppTag.productive => const Color(0x73B7F34D),
                    AppTag.neutral => C.border,
                  },
                  width: 1.5,
                ),
              ),
              child: Text(
                tag.label,
                style: display(13, weight: 700, color: tagColor(tag)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary line: "3 wasted · 2 neutral · 3 productive · daily average, last 7 days"
class ClassifySummary extends StatelessWidget {
  const ClassifySummary({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tags = state.effectiveTags;
    var w = 0, n = 0, p = 0;
    for (final id in state.usage.apps.keys) {
      switch (tags[id] ?? AppTag.neutral) {
        case AppTag.wasted:
          w++;
        case AppTag.neutral:
          n++;
        case AppTag.productive:
          p++;
      }
    }
    return Text(
      '$w wasted · $n neutral · $p productive · daily average, last 7 days',
      style: mono(11, tracking: 0.04),
    );
  }
}

/// Full-screen version, opened from Settings.
class ClassifyScreen extends StatelessWidget {
  const ClassifyScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const ClassifyScreen());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kScreenPad, 8, kScreenPad, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(),
              const SizedBox(height: 8),
              Text(
                'Which of these are a waste?',
                style: display(30, weight: 800, tracking: -0.035, height: 1.05),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap a tag to change it. This keeps the verdicts fair.',
                style: display(15, weight: 500, color: C.muted, height: 1.45),
              ),
              const SizedBox(height: 14),
              const ClassifySummary(),
              const SizedBox(height: 10),
              const Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 16),
                  child: ClassifyList(),
                ),
              ),
              Container(
                color: C.bg,
                padding: const EdgeInsets.only(top: 14),
                child: PrimaryButton(
                  label: 'Save',
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
