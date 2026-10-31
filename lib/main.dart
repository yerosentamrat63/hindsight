import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/app_detail.dart';
import 'screens/history.dart';
import 'screens/onboarding.dart';
import 'screens/settings_screen.dart';
import 'screens/today.dart';
import 'screens/verdict.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets/coachmark.dart';
import 'widgets/hindsight_launch.dart';
import 'widgets/widget_png.dart';
import 'widgets/ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: C.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const HindsightApp(),
    ),
  );
}

class HindsightApp extends StatelessWidget {
  const HindsightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hindsight',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      // The home-screen widgets are painted inside this tree and captured to
      // PNGs, so they keep the app's fonts (see widgets/widget_png.dart).
      builder: (context, child) =>
          WidgetPngHost(child: child ?? const SizedBox.shrink()),
      home: const AppBoot(),
    );
  }
}

/// Plays the designed launch animation while the app boots, then fades into
/// [RootGate]. The animation is skippable with a tap and honours the OS
/// "remove animations" setting.
class AppBoot extends StatelessWidget {
  const AppBoot({super.key});

  @override
  Widget build(BuildContext context) {
    return LaunchGate(
      ready: context.read<AppState>().ready,
      child: const RootGate(),
      launchBuilder: (onFinished) => HindsightLaunch(
        onFinished: onFinished,
        wordmarkStyle: display(46, weight: 800),
        monoStyle: mono(12, color: C.muted),
      ),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final loading = context.select<AppState, bool>((s) => s.loading);
    final done = context.select<AppState, bool>((s) => s.settings.setupComplete);

    if (loading) return const _Splash();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: done ? const HomeShell() : const OnboardingFlow(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppMark(size: 56),
            const SizedBox(height: 18),
            Text('Hindsight', style: display(28, weight: 800, tracking: -0.03)),
            const SizedBox(height: 6),
            Text('counting the minutes', style: mono(12)),
          ],
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  final Set<int> _visited = {0};
  CoachTip? _tip;
  Timer? _coachTimer;

  static const _todayTour = [
    CoachTip.verdictCard,
    CoachTip.topApps,
    CoachTip.share,
  ];
  static const _settingsTour = [
    CoachTip.voice,
    CoachTip.retag,
    CoachTip.writer,
  ];

  List<CoachTip> _tourFor(int page) =>
      page == 3 ? _settingsTour : _todayTour;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.verdict == null) state.generateVerdict();
      _later(const Duration(milliseconds: 650), () => _maybeShowTip(0));
    });
  }

  @override
  void dispose() {
    _coachTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A cancelable delay, so leaving the screen never leaves a timer behind.
  void _later(Duration delay, VoidCallback action) {
    _coachTimer?.cancel();
    _coachTimer = Timer(delay, () {
      if (mounted) action();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      final state = context.read<AppState>();
      state.refreshPermissions();
      // The user may have just granted usage access in Android's settings.
      state.refreshUsage();
    }
  }

  void _go(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _visited.add(i);
    });
    _later(const Duration(milliseconds: 400), () => _maybeShowTip(i));
  }

  /// Runs the first unseen tip that belongs to [page]. Tips only ever appear on
  /// the screen they describe.
  Future<void> _maybeShowTip(int page) async {
    final state = context.read<AppState>();
    if (!state.settings.setupComplete || _tip != null) return;
    for (final tip in _tourFor(page)) {
      if (tip.page != page) continue;
      if (state.settings.coachSeen.contains(tip.id)) continue;
      await _show(tip);
      return;
    }
  }

  Future<void> _show(CoachTip tip) async {
    if (tip.page != _index) {
      setState(() {
        _index = tip.page;
        _visited.add(tip.page);
      });
      await Future.delayed(const Duration(milliseconds: 260));
    }
    final target = tip.target.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: const Duration(milliseconds: 280),
      );
    }
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    setState(() => _tip = tip);
  }

  Future<void> _nextTip() async {
    final current = _tip;
    if (current == null) return;
    final state = context.read<AppState>();
    await state.markCoachSeen(current.id);
    if (!mounted) return;

    CoachTip? next;
    for (final tip in _tourFor(current.page)) {
      if (tip.page != current.page) continue;
      if (state.settings.coachSeen.contains(tip.id)) continue;
      next = tip;
      break;
    }

    if (next == null) {
      setState(() => _tip = null);
      return;
    }
    setState(() => _tip = null);
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) await _show(next);
  }

  Future<void> _skipTour() async {
    final current = _tip;
    if (current == null) return;
    final state = context.read<AppState>();
    for (final tip in _tourFor(current.page)) {
      if (tip.page != current.page) continue;
      await state.markCoachSeen(tip.id);
    }
    if (!mounted) return;
    setState(() => _tip = null);
  }

  /// Settings > Replay tips: forget every tip, then start the Settings tour
  /// right where the user is standing.
  Future<void> _replayTips() async {
    setState(() => _tip = null);
    final state = context.read<AppState>();
    await state.resetCoachTips();
    if (!mounted) return;
    await _maybeShowTip(3);
  }

  Widget _page(int i) => switch (i) {
        0 => TodayScreen(
            onOpenSettings: () => _go(3),
            onOpenVerdict: () => _go(1),
          ),
        1 => const VerdictScreen(),
        2 => HistoryScreen(onOpenApp: (meta) => pushAppDetail(context, meta)),
        _ => SettingsScreen(onReplayTips: _replayTips),
      };

  @override
  Widget build(BuildContext context) {
    final tip = _tip;
    return Stack(
      children: [
        Scaffold(
          backgroundColor: C.bg,
          body: IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < 4; i++)
                _visited.contains(i) ? _page(i) : const SizedBox.shrink(),
            ],
          ),
          bottomNavigationBar: BottomNav(current: _index, onSelect: _go),
        ),
        if (tip != null)
          Positioned.fill(
            child: CoachOverlay(
              tip: tip,
              onNext: _nextTip,
              onSkip: _skipTour,
            ),
          ),
      ],
    );
  }
}
