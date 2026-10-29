import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/milestones.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/coachmark.dart';
import '../widgets/ui.dart';
import 'receipt.dart';

class VerdictScreen extends StatefulWidget {
  const VerdictScreen({super.key});

  @override
  State<VerdictScreen> createState() => _VerdictScreenState();
}

class _VerdictScreenState extends State<VerdictScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.verdict == null) state.generateVerdict();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final verdict = state.verdict;
    final summary = state.todaySummary;
    final plan = state.milestonePlan;
    final waiting = verdict == null;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(kScreenPad, 12, kScreenPad, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MonoLabel('Verdict · ${dayLabel(state.today)}'),
                      ),
                      Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: C.border, width: 1.5),
                        ),
                        child: Text(state.settings.tone.label,
                            style: mono(11, color: C.ink, tracking: 0.02)),
                      ),
                      const SizedBox(width: 8),
                      _RefreshButton(
                        busy: state.verdictLoading,
                        onTap: state.verdictLoading
                            ? null
                            : () => state.generateVerdict(force: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const MonoLabel('Wasted today'),
                  const SizedBox(height: 4),
                  Text(
                    dur(summary.wasted),
                    style: display(80,
                        weight: 800, tracking: -0.05, height: 0.95, color: C.orange),
                  ),
                  const SizedBox(height: 16),
                  if (waiting)
                    _Writing()
                  else ...[
                    Text(
                      verdict.headline,
                      style: display(30, weight: 800, tracking: -0.03, height: 1.08),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      verdict.body,
                      style: display(16, weight: 400, color: C.inkDim, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      verdict.fromAi
                          ? 'Words by AI · numbers computed on your phone'
                          : 'Offline verdict · numbers computed on your phone',
                      style: mono(11, tracking: 0.02),
                    ),
                  ],
                  if (state.verdictStale) ...[
                    const SizedBox(height: 14),
                    NoticeBanner(
                      title: 'This verdict is out of date',
                      body: state.staleReason,
                      icon: Icons.sync,
                      action: _BannerAction(
                        label: 'Refresh',
                        onTap: state.verdictLoading
                            ? null
                            : () => state.generateVerdict(force: true),
                      ),
                    ),
                  ],
                  if (state.verdictError != null) ...[
                    const SizedBox(height: 14),
                    NoticeBanner(
                      title: 'AI unreachable',
                      body: state.verdictError!,
                      icon: Icons.cloud_off,
                    ),
                  ],
                  if (plan.hasTime) ...[
                    const SizedBox(height: 16),
                    _MilestoneCard(plan: plan, goal: state.settings.goal),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    decoration: cardDecoration(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _StatRow(label: 'Wasted today', value: dur(summary.wasted)),
                        _StatRow(
                          label: 'This week so far',
                          value: dur(state.wastedWeek),
                          divider: true,
                        ),
                        _StatRow(
                          label: 'Next 2 weeks at this pace',
                          value: dur(plan.weeklyMinutes * 2),
                          divider: true,
                        ),
                        _StatRow(
                          label: 'Next 4 months at this pace',
                          value: durLong(plan.weeklyMinutes * 17),
                          divider: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kScreenPad, 8, kScreenPad, 14),
            child: KeyedSubtree(
              key: CoachKeys.share,
              child: PrimaryButton(
                label: 'Share verdict',
                icon: Icons.ios_share,
                onPressed: () => Navigator.of(context).push(ReceiptScreen.route()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: C.border, width: 1.5),
        ),
        child: busy
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  valueColor: AlwaysStoppedAnimation(C.orange),
                ),
              )
            : const Icon(Icons.refresh, size: 15, color: C.ink),
      ),
    );
  }
}

class _BannerAction extends StatelessWidget {
  const _BannerAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: C.orange,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: mono(12, weight: 700, color: C.bg)),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.plan, required this.goal});

  final MilestonePlan plan;
  final String goal;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel('What that time could buy · $goal'),
          const SizedBox(height: 4),
          for (final milestone in plan.items)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: milestone == plan.items.first
                    ? null
                    : const Border(top: BorderSide(color: C.hairline)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(milestone.horizon.toUpperCase(),
                            style: mono(10, tracking: 0.06)),
                        const SizedBox(height: 2),
                        Text('${thousands(plan.hoursOf(milestone))}h',
                            style: display(22,
                                weight: 800, tracking: -0.03, color: C.lime)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      milestone.text,
                      style: display(14, weight: 400, color: C.inkDim, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Writing extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(C.orange),
            ),
          ),
          const SizedBox(width: 10),
          Text('Reading your day…', style: mono(12, color: C.inkDim)),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.divider = false,
  });

  final String label;
  final String value;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: divider
            ? const Border(top: BorderSide(color: C.hairline))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: display(14, weight: 400, color: C.muted)),
          ),
          Text(value, style: mono(16, weight: 700, color: C.ink, tracking: 0)),
        ],
      ),
    );
  }
}
