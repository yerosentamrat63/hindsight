import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/providers.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/coachmark.dart';
import '../widgets/ui.dart';
import 'api_key.dart';
import 'classify.dart';
import 'prompt.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.onReplayTips});

  /// Opens the Settings coachmark tour from the top.
  final VoidCallback? onReplayTips;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(kScreenPad, 8, kScreenPad, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 40,
              child: Text('Settings',
                  style: display(28, weight: 800, tracking: -0.03)),
            ),
            const SizedBox(height: 18),
            const MonoLabel('Voice'),
            const SizedBox(height: 8),
            Row(
              key: CoachKeys.voice,
              children: [
                for (var i = 0; i < Tone.values.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _ToneButton(
                      tone: Tone.values[i],
                      selected: settings.tone == Tone.values[i],
                      onTap: () => _changeTone(context, state, Tone.values[i]),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            const MonoLabel('Goal and limits'),
            const SizedBox(height: 8),
            Container(
              decoration: cardDecoration(),
              child: Column(
                children: [
                  _SettingsRow(
                    title: 'Goal',
                    value: settings.goal,
                    onTap: () => _editGoal(context, state),
                  ),
                  _SettingsRow(
                    title: 'Wasted-time limit',
                    value: '${dur(settings.wastedLimitMinutes)} a day',
                    divider: true,
                    onTap: () => pickLimit(context, state),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const MonoLabel('Verdict and apps'),
            const SizedBox(height: 8),
            Container(
              decoration: cardDecoration(),
              child: Column(
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 60),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Daily verdict',
                                  style: display(15, weight: 600)),
                              GestureDetector(
                                onTap: () => _pickNotifyTime(context, state),
                                behavior: HitTestBehavior.opaque,
                                child: Text(
                                  'Notify me at ${clockLabel(settings.notifyAtMinutes)}',
                                  style: mono(12, tracking: 0.02),
                                ),
                              ),
                              if (settings.notifyEnabled && !state.notificationsAllowed)
                                GestureDetector(
                                  onTap: () => state.openNotificationSettings(),
                                  behavior: HitTestBehavior.opaque,
                                  child: Text(
                                    'Blocked by Android · allow notifications',
                                    style: mono(11,
                                        color: C.orange, tracking: 0.02),
                                  ),
                                )
                              else if (settings.notifyEnabled &&
                                  !state.exactAlarmsAllowed)
                                GestureDetector(
                                  onTap: () => state.openExactAlarmSettings(),
                                  behavior: HitTestBehavior.opaque,
                                  child: Text(
                                    'Android may delay this by up to 10 min · allow exact alarms',
                                    style: mono(11,
                                        color: C.orange, tracking: 0.02),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        AppToggle(
                          value: settings.notifyEnabled,
                          onChanged: (_) => state.toggleNotify(),
                        ),
                      ],
                    ),
                  ),
                  _SettingsRow(
                    key: CoachKeys.retag,
                    title: 'Retag my apps',
                    value: '',
                    divider: true,
                    onTap: () => Navigator.of(context).push(ClassifyScreen.route()),
                  ),
                  _SettingsRow(
                    key: CoachKeys.writer,
                    title: 'Verdict writer',
                    value: settings.hasApiKey
                        ? '${settings.provider.label} · ${settings.model.split('/').last}'
                        : 'Off · offline verdicts',
                    divider: true,
                    onTap: () => Navigator.of(context).push(ApiKeyScreen.route()),
                  ),
                  _SettingsRow(
                    title: 'Verdict prompt',
                    value: settings.voicePrompts.isEmpty
                        ? 'Built-in'
                        : 'Custom · ${settings.voicePrompts.length} of 3',
                    divider: true,
                    onTap: () => Navigator.of(context).push(PromptScreen.route()),
                  ),
                  _SettingsRow(
                    title: 'Replay tips',
                    value: '${CoachTip.values.length} tips',
                    divider: true,
                    onTap: onReplayTips,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const MonoLabel('Privacy'),
            const SizedBox(height: 8),
            Container(
              decoration: cardDecoration(),
              child: _SettingsRow(
                title: 'Screen-time access',
                value: state.onDeviceUsage
                    ? (state.hasUsageAccess ? 'On' : 'Off · tap to allow')
                    : 'Demo data',
                onTap: state.onDeviceUsage ? state.requestAccess : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Usage is read and stored on this phone. The AI only sees daily totals and your top three apps, never a timeline.',
              style: display(14, weight: 400, color: C.inkDim, height: 1.45),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _confirmDelete(context, state),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delete_outline, size: 20, color: C.orange),
                  const SizedBox(width: 10),
                  Text('Delete all my data',
                      style: display(15, weight: 700, color: C.orange)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editGoal(BuildContext context, AppState state) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GoalSheet(initial: state.settings.goal, state: state),
    );
    if (!context.mounted) return;
    _promptRefresh(context, state);
  }

  Future<void> _changeTone(
    BuildContext context,
    AppState state,
    Tone tone,
  ) async {
    await state.setTone(tone);
    if (!context.mounted) return;
    _promptRefresh(context, state);
  }

  /// The verdict is written for one voice and one goal. When either changes,
  /// say so and offer to rewrite it instead of showing yesterday's judgement.
  void _promptRefresh(BuildContext context, AppState state) {
    if (!state.verdictStale) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: C.surface2,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: C.border, width: 1.5),
        ),
        duration: const Duration(seconds: 8),
        content: Text(
          state.staleReason,
          style: display(14, weight: 500, color: C.ink, height: 1.35),
        ),
        action: SnackBarAction(
          label: 'Refresh',
          textColor: C.lime,
          onPressed: () => state.generateVerdict(force: true),
        ),
      ),
    );
  }

  Future<void> _pickNotifyTime(BuildContext context, AppState state) async {
    final current = state.settings.notifyAtMinutes;
    final picked = await showTimePicker(
      context: context,
      helpText: 'When should the verdict land?',
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      builder: (pickerContext, child) => Theme(
        data: Theme.of(pickerContext).copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor: C.surface,
            dialBackgroundColor: C.bg,
            hourMinuteColor: C.surface2,
            hourMinuteTextColor: C.ink,
            dialHandColor: C.ink,
            dayPeriodColor: C.surface2,
            dayPeriodTextColor: C.ink,
            helpTextStyle: mono(12, color: C.muted),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    await state.setNotifyAt(picked.hour * 60 + picked.minute);
  }

  Future<void> _confirmDelete(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: C.surface,
        title: Text('Delete everything?',
            style: display(20, weight: 800, tracking: -0.02)),
        content: Text(
          'This clears your settings, tags and cached verdicts on this phone. Screen-time data itself is never copied off the device.',
          style: display(14, weight: 400, color: C.inkDim, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Keep it', style: mono(13, color: C.ink)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Delete', style: mono(13, color: C.orange)),
          ),
        ],
      ),
    );
    if (ok == true) await state.deleteAllData();
  }
}

Future<void> pickLimit(BuildContext context, AppState state) {
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
                    child: Text(
                      minutes == 60 ? '1 hour a day' : '${minutes ~/ 60} hours a day',
                      style: display(15,
                          weight: 600,
                          color: minutes == state.limitMinutes ? C.bg : C.ink),
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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.title,
    required this.value,
    this.onTap,
    this.divider = false,
  });

  final String title;
  final String value;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: divider ? const Border(top: BorderSide(color: C.hairline)) : null,
        ),
        child: Row(
          children: [
            Expanded(child: Text(title, style: display(15, weight: 600))),
            if (value.isNotEmpty)
              // A tight slot keeps the value against the chevron. A loose one
              // let it stop short and left a gap, which read like justified
              // text across the row.
              Flexible(
                fit: FlexFit.tight,
                child: Text(value,
                    style: mono(12, tracking: 0.02),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: C.muted),
          ],
        ),
      ),
    );
  }
}

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({required this.initial, required this.state});

  final String initial;
  final AppState state;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final TextEditingController _goal = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.state.setGoal(_goal.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What are you becoming?',
                style: display(22, weight: 800, tracking: -0.03)),
            const SizedBox(height: 4),
            Text('The verdict holds your time against this.',
                style: display(14, weight: 400, color: C.muted)),
            const SizedBox(height: 16),
            TextField(
              controller: _goal,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: display(16, weight: 600),
              cursorColor: C.lime,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: 'UI/UX designer',
                hintStyle: display(16, weight: 400, color: C.faint),
                filled: true,
                fillColor: C.bg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: C.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: C.ink, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Save goal', onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _ToneButton extends StatelessWidget {
  const _ToneButton({
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final Tone tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? C.ink : C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? C.ink : C.border, width: 1.5),
        ),
        child: Text(
          tone.label,
          textAlign: TextAlign.center,
          style: display(14,
              weight: 600, color: selected ? C.bg : C.ink, height: 1.2),
        ),
      ),
    );
  }
}
