import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai/local_verdict.dart';
import 'ai/milestones.dart';
import 'ai/providers.dart';
import 'ai/verdict_context.dart';
import 'ai/verdict_service.dart';
import 'data/key_vault.dart';
import 'data/reminders.dart';
import 'data/usage_repository.dart';
import 'format.dart';
import 'models.dart';
import 'widgets/hindsight_widgets.dart';
import 'widgets/home_widgets.dart';
import 'widgets/widget_png.dart';

class AppState extends ChangeNotifier {
  AppState({UsageRepository? repo, VerdictService? verdicts})
      : _repo = repo ?? UsageRepository(),
        _verdicts = verdicts ?? VerdictService();

  static const _settingsKey = 'settings.v1';
  static const _widgetSnapshotKey = 'widgets.snapshot.v1';
  static const _verdictPrefix = 'verdict.';

  final UsageRepository _repo;
  final VerdictService _verdicts;
  SharedPreferences? _prefs;

  AppSettings settings = AppSettings();
  UsageData usage = UsageData.empty();
  DateTime today = dateOnly(DateTime.now());
  bool loading = true;
  bool verdictLoading = false;
  bool hasUsageAccess = false;
  String? verdictError;
  Verdict? verdict;

  /// The voice/goal/pace a verdict was written for. When it drifts from the
  /// settings the verdict is stale and the screens offer a refresh.
  String? _verdictBasis;

  /// False when Android 13+ has notifications blocked for the app.
  bool notificationsAllowed = true;

  /// False on Android 12+ until the user allows exact alarms. Without it the
  /// evening reminder lands in a ten-minute window instead of on the minute.
  bool exactAlarmsAllowed = true;

  // ---------------------------------------------------------------- lifecycle

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadSettings();
      hasUsageAccess = await _repo.hasAccess();
      usage = await _repo.load();
      _loadCachedVerdict();
      notificationsAllowed = await Reminders.hasPermission();
      exactAlarmsAllowed = await Reminders.canScheduleExact();
      // A reminder that is already switched on still needs Android's permission
      // before it can post anything. Ask once, here, so the 22:00 alarm is not
      // armed invisibly on Android 13+.
      if (settings.setupComplete &&
          settings.notifyEnabled &&
          !notificationsAllowed) {
        await Reminders.requestPermission();
      }
      await _syncReminder();
    } finally {
      loading = false;
      notifyListeners();
    }
    // The launcher widgets are five offscreen paints and PNG encodes. That is
    // not boot: doing it here used to delay the home screen. Paint them once
    // the home screen has settled instead.
    if (!HomeWidgets.isTest) unawaited(_publishWidgetsLater());
  }

  Future<void> _publishWidgetsLater() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    await _publishWidgets();
  }

  // ----------------------------------------------------------------- widgets

  /// Everything the home-screen widgets draw, in one flat snapshot.
  Map<String, Object?> widgetSnapshot() {
    final summary = todaySummary;
    final yesterdayKey = dayKeyOf(dayOffset(today, -1));
    final days = usage.lastDays(today, 7).map(dateFromKey).toList();
    final week = this.week;
    final top = todaySlices.take(3).toList();

    return {
      'wastedToday': summary.wasted,
      'neutralToday': summary.neutral,
      'productiveToday': summary.productive,
      'totalToday': summary.total,
      'limit': limitMinutes,
      'totalDeltaYesterday': summary.total - usage.totalOn(yesterdayKey),
      'wastedWeek': wastedWeek,
      'weekDelta': wastedWeek - wastedPrevWeek,
      'weekSpan': weekSpan(days),
      'days': [
        for (var i = 0; i < days.length; i++)
          {
            'label': weekdayShort(days[i]),
            'wasted': week[i].wasted,
            'today': i == days.length - 1,
          },
      ],
      'apps': [
        for (final slice in top)
          {
            'name': slice.meta.name,
            'mono': widgetInitials(slice.meta.name),
            'minutes': slice.minutes,
            'tag': slice.tag.name,
          },
      ],
      'verdict': verdict?.oneLiner ?? verdict?.headline ?? '',
      'tone': settings.tone.label,
      'updated': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Future<void> _publishWidgets() async {
    final snapshot = widgetSnapshot();
    // Drawing and encoding five PNGs stalls the UI thread for most of a
    // second. Skip it when nothing the widgets show has changed since the
    // last publish; `updated` changes every snapshot and is ignored here.
    final fingerprint = jsonEncode(
      Map<String, Object?>.of(snapshot)..remove('updated'),
    );
    if (_prefs?.getString(_widgetSnapshotKey) == fingerprint) return;
    // The native layouts only carry an image, so draw the widgets first and
    // then ask the launcher to reload them.
    await WidgetPngHost.push(widgetDataFromSnapshot(snapshot));
    await HomeWidgets.publish(snapshot);
    await _prefs?.setString(_widgetSnapshotKey, fingerprint);
  }

  void _loadSettings() {
    final raw = _prefs?.getString(_settingsKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final tags = <String, AppTag>{};
      final rawTags = j['tags'];
      if (rawTags is Map) {
        rawTags.forEach((k, v) => tags[k.toString()] = AppTagX.parse(v.toString()));
      }

      final apiKeys = <String, String>{};
      final rawKeys = j['apiKeys'];
      if (rawKeys is Map) {
        rawKeys.forEach((k, v) {
          final decrypted = KeyVault.decrypt(v.toString());
          if (decrypted.isNotEmpty) apiKeys[k.toString()] = decrypted;
        });
      }
      // Older installs stored a single Groq key and model.
      final oldKey = KeyVault.decrypt((j['apiKey'] ?? '').toString());
      if (apiKeys.isEmpty && oldKey.isNotEmpty) apiKeys[AiProvider.groq.id] = oldKey;

      final models = <String, String>{};
      final rawModels = j['models'];
      if (rawModels is Map) {
        rawModels.forEach((k, v) => models[k.toString()] = v.toString());
      }
      final oldModel = j['model']?.toString();
      if (models.isEmpty && oldModel != null) {
        models[AiProvider.groq.id] = AppSettings.migrateModel(oldModel);
      }

      final prompts = <Tone, String>{};
      final rawPrompts = j['prompts'];
      if (rawPrompts is Map) {
        rawPrompts.forEach((k, v) {
          final text = v.toString().trim();
          if (text.isNotEmpty) prompts[ToneX.parse(k.toString())] = text;
        });
      }

      settings = AppSettings(
        tone: ToneX.parse(j['tone']?.toString()),
        goal: (j['goal'] ?? 'UI/UX designer').toString(),
        paceMinutes: (j['pace'] as num?)?.toInt() ?? 60,
        wastedLimitMinutes: (j['limit'] as num?)?.toInt() ?? 240,
        notifyEnabled: j['notify'] as bool? ?? true,
        notifyAtMinutes: (j['notifyAt'] as num?)?.toInt() ?? 22 * 60,
        provider: AiProviderX.parse(j['provider']?.toString()),
        apiKeys: apiKeys,
        models: models,
        voicePrompts: prompts,
        customBaseUrl: (j['baseUrl'] ?? '').toString(),
        tags: tags,
        setupComplete: j['setupComplete'] as bool? ?? false,
        coachSeen: {
          for (final id in (j['coach'] as List?) ?? const [])
            id.toString(),
        },
      );
    } catch (_) {
      settings = AppSettings();
    }
  }

  Future<void> _saveSettings() async {
    final j = <String, dynamic>{
      'tone': settings.tone.id,
      'goal': settings.goal,
      'pace': settings.paceMinutes,
      'limit': settings.wastedLimitMinutes,
      'notify': settings.notifyEnabled,
      'notifyAt': settings.notifyAtMinutes,
      'provider': settings.provider.id,
      'apiKeys': {
        for (final entry in settings.apiKeys.entries)
          if (entry.value.trim().isNotEmpty)
            entry.key: KeyVault.encrypt(entry.value),
      },
      'models': settings.models,
      'prompts': settings.voicePrompts.map((k, v) => MapEntry(k.id, v)),
      'baseUrl': settings.customBaseUrl,
      'tags': settings.tags.map((k, v) => MapEntry(k, v.name)),
      'setupComplete': settings.setupComplete,
      'coach': settings.coachSeen.toList(),
    };
    await _prefs?.setString(_settingsKey, jsonEncode(j));
  }

  void _loadCachedVerdict() {
    final raw = _prefs?.getString('$_verdictPrefix${dayKeyOf(today)}');
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      verdict = Verdict(
        headline: j['headline'].toString(),
        body: j['body'].toString(),
        oneLiner: j['oneLiner']?.toString(),
        dayKey: dayKeyOf(today),
        source: j['source']?.toString() ?? 'local',
      );
      _verdictBasis = j['basis']?.toString();
    } catch (_) {
      verdict = null;
      _verdictBasis = null;
    }
  }

  Future<void> _cacheVerdict(Verdict v) async {
    final j = {
      'headline': v.headline,
      'body': v.body,
      'oneLiner': v.oneLiner,
      'source': v.source,
      'basis': _verdictBasis,
    };
    await _prefs?.setString('$_verdictPrefix${v.dayKey}', jsonEncode(j));
  }

  // ------------------------------------------------------------------ tagging

  static const _wastedNames = {
    'tiktok', 'instagram', 'youtube', 'netflix', 'snapchat', 'reddit',
    'facebook', 'twitter', 'x', 'reels', 'shorts', 'threads', 'pinterest',
    'twitch', 'discord', 'bilibili',
  };
  static const _productiveNames = {
    'notion', 'duolingo', 'figma', 'github', 'obsidian', 'udemy', 'coursera',
    'linear', 'kindle', 'anki', 'code', 'vscode', 'terminal', 'sublime',
    'photoshop', 'blender', 'ableton', 'fl studio', 'goodnotes',
  };

  static AppTag inferTag(String id, String name) {
    final key = '${id.toLowerCase()} ${name.toLowerCase()}';
    for (final n in _wastedNames) {
      if (key.contains(n)) return AppTag.wasted;
    }
    for (final n in _productiveNames) {
      if (key.contains(n)) return AppTag.productive;
    }
    return AppTag.neutral;
  }

  /// Tags including the sensible defaults for apps the user never touched.
  Map<String, AppTag> get effectiveTags {
    final out = <String, AppTag>{};
    usage.apps.forEach((id, meta) {
      out[id] = settings.tags[id] ?? inferTag(id, meta.name);
    });
    return out;
  }

  AppTag tagFor(AppMeta meta) =>
      settings.tags[meta.id] ?? inferTag(meta.id, meta.name);

  Future<void> setTag(String appId, AppTag tag) async {
    settings.tags = {...settings.tags, appId: tag};
    await _saveSettings();
    notifyListeners();
  }

  Future<void> cycleTag(String appId) async {
    final current = settings.tags[appId] ??
        (usage.apps[appId] == null
            ? AppTag.neutral
            : inferTag(appId, usage.apps[appId]!.name));
    // Always write into a fresh map: the default tag map is const and an
    // in-place write would throw, which is what made onboarding tags look
    // stuck on a fresh install.
    settings.tags = {...settings.tags, appId: current.next};
    await _saveSettings();
    notifyListeners();
  }

  // ------------------------------------------------------------------- stats

  /// True when real per-app usage can be read here (Android).
  bool get onDeviceUsage => _repo.isAndroid;

  int get todayKey => dayKeyOf(today);

  DaySummary get todaySummary =>
      usage.summaryOn(todayKey, today, effectiveTags);

  List<DaySlice> get todaySlices => usage.slicesOn(todayKey, effectiveTags);

  List<DaySummary> get week => usage.week(today, effectiveTags);

  int get wastedWeek => usage.wastedWeek(today, effectiveTags);

  int get wastedPrevWeek => usage.wastedPrevWeek(today, effectiveTags);

  int get weekDelta => wastedWeek - wastedPrevWeek;

  int get reclaimedWeek => usage.reclaimedWeek(today, effectiveTags);

  int get limitMinutes => settings.wastedLimitMinutes;

  DaySummary? get bestDay {
    final w = week;
    if (w.isEmpty) return null;
    return w.reduce((a, b) => a.wasted <= b.wasted ? a : b);
  }

  int get daysUnderLimit => week.where((d) => d.wasted <= limitMinutes).length;

  AppMeta? get mostWastedApp {
    AppMeta? best;
    var bestMinutes = 0;
    usage.apps.forEach((id, meta) {
      if (effectiveTags[id] != AppTag.wasted) return;
      final m = usage.weekMinutes(id, today);
      if (m > bestMinutes) {
        bestMinutes = m;
        best = meta;
      }
    });
    return best;
  }

  int weekMinutesOf(String appId) => usage.weekMinutes(appId, today);

  int todayMinutesOf(String appId) => usage.minutesOn(todayKey, appId);

  // -------------------------------------------------------------- milestones

  /// The two goals this week's pace could buy. Shared by the verdict screen and
  /// the model prompt so both talk about the same, believable horizons.
  MilestonePlan get milestonePlan =>
      planFor(goal: settings.goal, wastedWeek: wastedWeek);

  // ---------------------------------------------------------------- verdicts

  String get _basis =>
      '${settings.tone.id}\u0001${settings.goal}\u0001${settings.paceMinutes}'
      '\u0001${settings.voicePrompt(settings.tone)}';

  /// True when the voice, goal or daily pace changed after the verdict was
  /// written, so the screens can offer a refresh instead of quietly lying.
  bool get verdictStale =>
      verdict != null && !verdictLoading && _verdictBasis != _basis;

  String get staleReason {
    if (_verdictBasis == null) {
      return "Refresh to write today's verdict with your current voice and "
          'goal.';
    }
    final before = _verdictBasis!.split('\u0001');
    final now = _basis.split('\u0001');
    final changed = <String>[
      if (before.isNotEmpty && now.isNotEmpty && before[0] != now[0]) 'voice',
      if (before.length > 1 && now.length > 1 && before[1] != now[1]) 'goal',
      if (before.length > 2 && now.length > 2 && before[2] != now[2])
        'daily pace',
      if (before.length > 3 && now.length > 3 && before[3] != now[3])
        'prompt',
    ];
    if (changed.isEmpty) return 'Refresh for a verdict on the latest numbers.';
    return 'Your ${changed.join(' and ')} changed. Refresh and the verdict '
        'will be rewritten to match.';
  }

  VerdictContext buildContext({Tone? toneOverride}) {
    final s = todaySummary;
    final slices = todaySlices;
    return VerdictContext(
      tone: toneOverride ?? settings.tone,
      goal: settings.goal,
      paceMinutes: settings.paceMinutes,
      wastedToday: s.wasted,
      neutralToday: s.neutral,
      productiveToday: s.productive,
      wastedWeek: wastedWeek,
      wastedPrevWeek: wastedPrevWeek,
      limitMinutes: limitMinutes,
      opensToday: usage.opensToday.values.fold(0, (a, b) => a + b),
      topApps: [
        for (final slice in slices.take(3))
          AppLine(name: slice.meta.name, minutes: slice.minutes, tag: slice.tag),
      ],
      sample: usage.sample,
    );
  }

  Future<void> generateVerdict({Tone? toneOverride, bool force = false}) async {
    final key = dayKeyOf(today);
    if (verdictLoading) return;
    if (!force && verdict != null && verdict!.dayKey == key) return;

    verdictLoading = true;
    verdictError = null;
    notifyListeners();

    final ctx = buildContext(toneOverride: toneOverride);
    try {
      if (settings.hasApiKey) {
        final v = await _verdicts.generate(
          ctx,
          ep: AiEndpoint(
            provider: settings.provider,
            apiKey: settings.apiKey,
            model: settings.model,
            baseUrl: settings.customBaseUrl,
          ),
          persona: settings.voicePrompt(ctx.tone),
          dayKey: key,
        );
        _verdictBasis = _basis;
        verdict = v;
        await _cacheVerdict(v);
      } else {
        _verdictBasis = _basis;
        verdict = localVerdict(ctx, dayKey: key);
      }
    } on VerdictException catch (e) {
      verdictError = e.message;
      _verdictBasis = _basis;
      verdict = localVerdict(ctx, dayKey: key);
    } catch (_) {
      verdictError = 'Something went wrong. Showing the offline verdict.';
      _verdictBasis = _basis;
      verdict = localVerdict(ctx, dayKey: key);
    } finally {
      verdictLoading = false;
      notifyListeners();
      await _publishWidgets();
    }
  }

  // ----------------------------------------------------------------- settings

  Future<void> setTone(Tone tone) async {
    settings.tone = tone;
    await _saveSettings();
    notifyListeners();
    await _publishWidgets();
  }

  Future<void> setGoal(String goal, {int? paceMinutes}) async {
    settings.goal = goal.trim().isEmpty ? settings.goal : goal.trim();
    if (paceMinutes != null) settings.paceMinutes = paceMinutes;
    await _saveSettings();
    notifyListeners();
    await _publishWidgets();
  }

  Future<void> setPace(int minutes) async {
    settings.paceMinutes = minutes;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setLimit(int minutes) async {
    settings.wastedLimitMinutes = minutes;
    await _saveSettings();
    notifyListeners();
    await _publishWidgets();
  }

  Future<void> toggleNotify() async {
    settings.notifyEnabled = !settings.notifyEnabled;
    await _saveSettings();
    if (settings.notifyEnabled) await Reminders.requestPermission();
    await _syncReminder();
    notificationsAllowed = await Reminders.hasPermission();
    notifyListeners();
  }

  Future<void> setNotifyAt(int minutesOfDay) async {
    settings.notifyAtMinutes = minutesOfDay;
    await _saveSettings();
    if (settings.notifyEnabled) await Reminders.requestPermission();
    await _syncReminder();
    notificationsAllowed = await Reminders.hasPermission();
    notifyListeners();
  }

  Future<void> _syncReminder() => Reminders.sync(
        // No evening nag before the user has even finished setting the app up.
        enabled: settings.setupComplete && settings.notifyEnabled,
        atMinutes: settings.notifyAtMinutes,
      );

  /// Called when the app comes back to the foreground: notification permission
  /// and the exact-alarm grant can only be answered in system dialogs.
  Future<void> refreshPermissions() async {
    var changed = false;

    final allowed = await Reminders.hasPermission();
    if (allowed != notificationsAllowed) {
      notificationsAllowed = allowed;
      changed = true;
    }

    final exact = await Reminders.canScheduleExact();
    if (exact != exactAlarmsAllowed) {
      exactAlarmsAllowed = exact;
      changed = true;
      // The alarm was armed in ten-minute windows; arm it on the minute now.
      await _syncReminder();
    }

    if (changed) notifyListeners();
  }

  Future<void> openNotificationSettings() => Reminders.openSettings();

  /// Android's "Alarms & reminders" screen, where exact times are granted.
  Future<void> openExactAlarmSettings() => Reminders.openExactSettings();

  Future<void> markCoachSeen(String id) async {
    settings.coachSeen = {...settings.coachSeen, id};
    await _saveSettings();
    notifyListeners();
  }

  Future<void> resetCoachTips() async {
    settings.coachSeen = {};
    await _saveSettings();
    notifyListeners();
  }

  /// Saves which service writes the verdict, with its key and model. Keys are
  /// kept per provider, so switching services never loses one.
  Future<void> saveAiConfig({
    required AiProvider provider,
    required String apiKey,
    String? model,
    String baseUrl = '',
  }) async {
    settings.provider = provider;
    settings.customBaseUrl = baseUrl.trim();

    final key = apiKey.trim();
    if (key.isEmpty) {
      settings.apiKeys.remove(provider.id);
    } else {
      settings.apiKeys[provider.id] = key;
    }

    final picked = (model ?? '').trim();
    settings.models[provider.id] = picked.isEmpty
        ? (settings.models[provider.id] ?? provider.fallbackModels.first)
        : picked;

    await _saveSettings();
    notifyListeners();
  }

  Future<void> setProvider(AiProvider provider) async {
    settings.provider = provider;
    await _saveSettings();
    notifyListeners();
  }

  /// A written voice instruction per tone. Empty text restores the built-in.
  Future<void> setVoicePrompts(Map<Tone, String> prompts) async {
    settings.voicePrompts = {
      for (final entry in prompts.entries)
        if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
    };
    await _saveSettings();
    notifyListeners();
  }

  /// Chat models the given key can call. Throws [VerdictException] when the
  /// provider rejects the key.
  Future<List<String>> fetchModels({
    required AiProvider provider,
    required String apiKey,
    String baseUrl = '',
  }) =>
      _verdicts.fetchModels(AiEndpoint(
        provider: provider,
        apiKey: apiKey,
        model: provider.fallbackModels.first,
        baseUrl: baseUrl,
      ));

  Future<void> completeSetup() async {
    settings.setupComplete = true;
    await _saveSettings();
    notifyListeners();
    await _syncReminder();
    if (settings.notifyEnabled && !await Reminders.hasPermission()) {
      await Reminders.requestPermission();
    }
  }

  Future<void> refreshUsage() async {
    final now = dateOnly(DateTime.now());
    if (now != today) {
      today = now;
      _loadCachedVerdict();
    }
    hasUsageAccess = await _repo.hasAccess();
    usage = await _repo.load();
    notifyListeners();
    await _publishWidgets();
  }

  Future<bool> requestAccess() async {
    await _repo.openAccessSettings();
    return _repo.hasAccess();
  }

  Future<void> deleteAllData() async {
    await _prefs?.clear();
    settings = AppSettings();
    verdict = null;
    _verdictBasis = null;
    verdictError = null;
    today = dateOnly(DateTime.now());
    await Reminders.sync(enabled: false, atMinutes: settings.notifyAtMinutes);
    await HomeWidgets.publish({});
    usage = await _repo.load();
    notifyListeners();
  }
}
