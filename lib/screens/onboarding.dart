import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'classify.dart';

const _goals = [
  'UI/UX designer',
  'Backend developer',
  'Mobile developer',
  'Data scientist',
  'Writer',
  'Stronger athlete',
];

const _paces = [
  (30, '30 min'),
  (60, '1 hour'),
  (120, '2 hours'),
  (180, '3 hours+'),
];

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;

  Tone _tone = Tone.roast;
  String _goal = _goals.first;
  int _pace = 60;
  final _goalField = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _tone = s.tone;
    _goal = s.goal;
    _pace = s.paceMinutes;
    _goalField.text = s.goal;
  }

  @override
  void dispose() {
    _goalField.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step = (_step + 1).clamp(0, 3));
  void _back() => setState(() => _step = (_step - 1).clamp(0, 3));

  Future<void> _finish() async {
    final state = context.read<AppState>();
    await state.setTone(_tone);
    await state.setGoal(_goalField.text.trim().isEmpty ? _goal : _goalField.text,
        paceMinutes: _pace);
    await state.completeSetup();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // System back walks the flow backwards instead of quitting the app, so
      // there is no dead end after the first "Continue".
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (_step) {
              0 => _ToneStep(
                  key: const ValueKey(0),
                  tone: _tone,
                  onPick: (t) => setState(() => _tone = t),
                  onNext: _next,
                ),
              1 => _GoalStep(
                  key: const ValueKey(1),
                  goal: _goal,
                  pace: _pace,
                  field: _goalField,
                  onGoal: (g) => setState(() => _goal = g),
                  onPace: (p) => setState(() => _pace = p),
                  onBack: _back,
                  onNext: _next,
                ),
              2 => _PermissionStep(
                  key: const ValueKey(2),
                  onBack: _back,
                  onNext: _next,
                ),
              _ => _ClassifyStep(
                  key: const ValueKey(3),
                  onBack: _back,
                  onFinish: _finish,
                ),
            },
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.done});

  final int done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
              decoration: BoxDecoration(
                color: i < done ? C.ink : C.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    this.onBack,
    this.brand = false,
  });

  final int step;
  final VoidCallback? onBack;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          if (onBack != null)
            GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.arrow_back_ios_new, size: 20, color: C.ink),
              ),
            )
          else if (brand)
            const Row(
              children: [
                AppMark(size: 22),
                SizedBox(width: 8),
                _Wordmark(),
              ],
            )
          else
            const Spacer(),
          const Spacer(),
          Text('$step / 4', style: mono(12, tracking: 0)),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Text('Hindsight',
        style: display(20, weight: 800, tracking: -0.02));
  }
}

class _ToneStep extends StatelessWidget {
  const _ToneStep({
    super.key,
    required this.tone,
    required this.onPick,
    required this.onNext,
  });

  final Tone tone;
  final ValueChanged<Tone> onPick;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPad, 12, kScreenPad, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(step: 1, brand: true),
          const SizedBox(height: 16),
          const _Progress(done: 1),
          const SizedBox(height: 36),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your phone knows where your time went.',
                      style: display(38,
                          weight: 800, tracking: -0.035, height: 1.04)),
                  const SizedBox(height: 12),
                  Text(
                    'Pick the voice you want to hear it in. You can change it any time.',
                    style: display(16, weight: 400, color: C.muted, height: 1.45),
                  ),
                  const SizedBox(height: 24),
                  for (final t in Tone.values) ...[
                    _ToneCard(tone: t, selected: t == tone, onTap: () => onPick(t)),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(label: 'Continue', icon: Icons.arrow_forward, onPressed: onNext),
        ],
      ),
    );
  }
}

class _ToneCard extends StatelessWidget {
  const _ToneCard({
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
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? C.surface2 : C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? C.ink : C.border, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tone.label,
                      style: display(18, weight: 700, tracking: -0.01)),
                  const SizedBox(height: 6),
                  Text(tone.blurb,
                      style: display(14, weight: 400, color: C.muted, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? C.ink : Colors.transparent,
                  border: Border.all(
                    color: selected ? C.ink : C.faint,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: C.surface2,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({
    super.key,
    required this.goal,
    required this.pace,
    required this.field,
    required this.onGoal,
    required this.onPace,
    required this.onBack,
    required this.onNext,
  });

  final String goal;
  final int pace;
  final TextEditingController field;
  final ValueChanged<String> onGoal;
  final ValueChanged<int> onPace;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What do you want to become?',
              style: display(36, weight: 800, tracking: -0.035, height: 1.05)),
          const SizedBox(height: 10),
          Text(
            'Every verdict is measured against this. Be specific, because the verdicts will be.',
            style: display(15, weight: 400, color: C.muted, height: 1.45),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final g in _goals)
                _Chip(
                  label: g,
                  selected: goal == g,
                  onTap: () {
                    onGoal(g);
                    field.text = g;
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          const MonoLabel('Or type your own'),
          const SizedBox(height: 8),
          TextField(
            controller: field,
            style: display(16, weight: 500),
            cursorColor: C.lime,
            onChanged: onGoal,
            decoration: InputDecoration(
              hintText: 'e.g. Game developer',
              hintStyle: display(16, weight: 400, color: C.faint),
              filled: true,
              fillColor: C.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          const SizedBox(height: 20),
          const MonoLabel('Time you could give it daily'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < _paces.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _Chip(
                    label: _paces[i].$2,
                    selected: pace == _paces[i].$1,
                    height: 48,
                    onTap: () => onPace(_paces[i].$1),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPad, 4, kScreenPad, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(step: 2, onBack: onBack),
          const SizedBox(height: 12),
          const _Progress(done: 2),
          const SizedBox(height: 28),
          Expanded(child: content),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Continue', icon: Icons.arrow_forward, onPressed: onNext),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 44,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? C.ink : C.surface,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: selected ? C.ink : C.border, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: display(15,
              weight: 600, color: selected ? C.bg : C.ink, height: 1.2),
        ),
      ),
    );
  }
}

class _PermissionStep extends StatefulWidget {
  const _PermissionStep({super.key, required this.onBack, required this.onNext});

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  State<_PermissionStep> createState() => _PermissionStepState();
}

class _PermissionStepState extends State<_PermissionStep>
    with WidgetsBindingObserver {
  bool _denied = false;
  bool _busy = false;
  bool _waiting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed && _waiting) _check();
  }

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _waiting = true;
    });
    await context.read<AppState>().requestAccess();
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _check() async {
    final state = context.read<AppState>();
    await state.refreshUsage();
    if (!mounted) return;
    setState(() {
      _waiting = false;
      _denied = !state.hasUsageAccess;
    });
  }

  @override
  Widget build(BuildContext context) {
    final onDevice = context.select<AppState, bool>((s) => s.onDeviceUsage);
    final granted = context.select<AppState, bool>((s) => s.hasUsageAccess);

    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPad, 4, kScreenPad, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(step: 3, onBack: widget.onBack),
          const SizedBox(height: 12),
          const _Progress(done: 3),
          const SizedBox(height: 28),
          Text('One switch to flip, and your data stays yours.',
              style: display(34, weight: 800, tracking: -0.035, height: 1.06)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (onDevice)
                    _AccessCard(
                      granted: granted,
                      waiting: _waiting,
                      denied: _denied && !granted,
                    ),
                  const SizedBox(height: 22),
                  const _PrivacyRow(
                    icon: Icons.phone_android,
                    text: 'Per-app times are read and stored on this phone only.',
                  ),
                  const SizedBox(height: 14),
                  const _PrivacyRow(
                    icon: Icons.shield_outlined,
                    text:
                        'The AI only sees daily totals and your top three apps, never a minute-by-minute log.',
                  ),
                  const SizedBox(height: 14),
                  const _PrivacyRow(
                    icon: Icons.delete_outline,
                    text: 'Delete everything any time from Settings.',
                  ),
                  if (!onDevice) ...[
                    const SizedBox(height: 16),
                    const NoticeBanner(
                      title: 'No usage access on this device',
                      body:
                          'Screen-time data comes from Android. On this device Hindsight runs on a demo week so you can try it.',
                      color: C.lime,
                      icon: Icons.info_outline,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!onDevice || granted) ...[
            PrimaryButton(
              label: 'Continue',
              icon: Icons.arrow_forward,
              onPressed: widget.onNext,
            ),
          ] else ...[
            PrimaryButton(
              label: 'Open usage access settings',
              icon: Icons.open_in_new,
              onPressed: _busy ? null : _request,
            ),
            const SizedBox(height: 10),
            OutlineButton(
              label: 'I have turned it on',
              icon: Icons.refresh,
              height: 52,
              onPressed: _busy ? null : _check,
            ),
            const SizedBox(height: 6),
            Center(
              child: GestureDetector(
                onTap: widget.onNext,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Text(
                    'Skip for now — look around with demo data',
                    style: mono(12, color: C.muted, tracking: 0.02),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The permission state in plain words, with the three steps spelled out.
/// The old cardboard mock of Android's settings screen looked tappable and
/// was not, which is what made this step feel wrong.
class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.granted,
    required this.waiting,
    required this.denied,
  });

  final bool granted;
  final bool waiting;
  final bool denied;

  @override
  Widget build(BuildContext context) {
    final accent = granted ? C.lime : C.orange;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: granted ? C.limeWash : C.orangeWash,
                  border: Border.all(color: accent, width: 1.5),
                ),
                child: Icon(
                  granted ? Icons.check_rounded : Icons.lock_open_outlined,
                  size: 20,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      granted
                          ? 'Access granted'
                          : waiting
                              ? 'Waiting for the switch'
                              : 'Usage access is off',
                      style: display(17, weight: 700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      granted
                          ? 'Hindsight is reading your screen time on this phone.'
                          : 'Android calls this “Usage access”.',
                      style: display(13.5, weight: 400, color: C.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!granted) ...[
            const SizedBox(height: 16),
            const _StepLine(number: '1', text: 'Open the Android setting below'),
            const SizedBox(height: 8),
            const _StepLine(number: '2', text: 'Find Hindsight in the list'),
            const SizedBox(height: 8),
            const _StepLine(number: '3', text: 'Turn the switch on, then come back'),
          ],
          if (denied) ...[
            const SizedBox(height: 14),
            Text(
              'Still off. The switch is per-app and Android can take a second to save it — try again, or skip and look around first.',
              style: display(13, weight: 400, color: C.orange, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: C.surface2,
          ),
          child: Text(number,
              style: mono(11, weight: 700, color: C.ink, tracking: 0)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: display(14, weight: 400, color: C.inkDim, height: 1.35)),
        ),
      ],
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: C.border, width: 1.5),
          ),
          child: Icon(icon, size: 18, color: C.lime),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text,
              style: display(15, weight: 400, height: 1.35)),
        ),
      ],
    );
  }
}

class _ClassifyStep extends StatelessWidget {
  const _ClassifyStep({
    super.key,
    required this.onBack,
    required this.onFinish,
  });

  final VoidCallback onBack;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPad, 4, kScreenPad, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(step: 4, onBack: onBack),
          const SizedBox(height: 12),
          const _Progress(done: 4),
          const SizedBox(height: 24),
          Text('Which of these are a waste?',
              style: display(32, weight: 800, tracking: -0.035, height: 1.05)),
          const SizedBox(height: 8),
          Text(
            'Tap a tag to change it. This keeps the verdicts fair, and you can redo it in Settings.',
            style: display(15, weight: 400, color: C.muted, height: 1.45),
          ),
          const SizedBox(height: 14),
          const ClassifySummary(),
          const SizedBox(height: 10),
          const Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 12),
              child: ClassifyList(maxRows: 8),
            ),
          ),
          PrimaryButton(
            label: 'Finish setup',
            icon: Icons.check_rounded,
            onPressed: onFinish,
          ),
        ],
      ),
    );
  }
}
