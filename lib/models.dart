import 'ai/providers.dart';
import 'format.dart';

/// The three voices the app can speak in.
enum Tone { coach, roast, future }

extension ToneX on Tone {
  String get id => name;

  String get label => switch (this) {
    Tone.coach => 'Gentle coach',
    Tone.roast => 'Brutal roast',
    Tone.future => 'Future you',
  };

  String get blurb => switch (this) {
    Tone.coach =>
      'You have more time than you think. Here is what it could build.',
    Tone.roast =>
      'Three hours of strangers dancing. Your portfolio sends its regards.',
    Tone.future =>
      'I am you in five years. Remember that thing you stopped building?',
  };

  static Tone parse(String? s) {
    switch (s) {
      case 'coach':
        return Tone.coach;
      case 'future':
        return Tone.future;
      default:
        return Tone.roast;
    }
  }
}

/// Metadata about a tracked app.
class AppMeta {
  const AppMeta({required this.id, required this.name, required this.initials});

  final String id;
  final String name;
  final String initials;
}

/// One app's slice of a single day.
class DaySlice {
  const DaySlice({
    required this.meta,
    required this.minutes,
    required this.tag,
  });

  final AppMeta meta;
  final int minutes;
  final AppTag tag;
}

/// Waste / neutral / productive totals for one day.
class DaySummary {
  const DaySummary({
    required this.date,
    required this.wasted,
    required this.neutral,
    required this.productive,
  });

  final DateTime date;
  final int wasted;
  final int neutral;
  final int productive;

  int get total => wasted + neutral + productive;
  int get dayKey => dayKeyOf(date);
}

/// Everything we know about the user's usage.
///
/// `daily` is keyed by [dayKeyOf]: day -> appId -> minutes.
class UsageData {
  const UsageData({
    required this.apps,
    required this.daily,
    required this.opensToday,
    required this.hourlyToday,
    this.sample = false,
  });

  final Map<String, AppMeta> apps;
  final Map<int, Map<String, int>> daily;
  final Map<String, int> opensToday;

  /// appId -> 24 buckets of minutes, today only.
  final Map<String, List<int>> hourlyToday;

  /// True when this is generated sample data (desktop/web or no permission).
  final bool sample;

  static UsageData empty() =>
      const UsageData(apps: {}, daily: {}, opensToday: {}, hourlyToday: {});

  int minutesOn(int key, String appId) => daily[key]?[appId] ?? 0;

  int totalOn(int key) {
    final m = daily[key];
    if (m == null) return 0;
    return m.values.fold(0, (a, b) => a + b);
  }

  Iterable<int> get dayKeys => daily.keys;

  /// Sorted list of days, oldest first, with `today` last.
  List<int> lastDays(DateTime today, int count) {
    final out = <int>[];
    for (var i = count - 1; i >= 0; i--) {
      out.add(dayKeyOf(today.subtract(Duration(days: i))));
    }
    return out;
  }

  List<DaySlice> slicesOn(int key, Map<String, AppTag> tags) {
    final m = daily[key] ?? const <String, int>{};
    final out = <DaySlice>[];
    m.forEach((appId, minutes) {
      if (minutes <= 0) return;
      final meta =
          apps[appId] ?? AppMeta(id: appId, name: appId, initials: '?');
      out.add(
        DaySlice(
          meta: meta,
          minutes: minutes,
          tag: tags[appId] ?? AppTag.neutral,
        ),
      );
    });
    out.sort((a, b) => b.minutes.compareTo(a.minutes));
    return out;
  }

  DaySummary summaryOn(int key, DateTime date, Map<String, AppTag> tags) {
    var w = 0, n = 0, p = 0;
    (daily[key] ?? const <String, int>{}).forEach((appId, minutes) {
      switch (tags[appId] ?? AppTag.neutral) {
        case AppTag.wasted:
          w += minutes;
        case AppTag.neutral:
          n += minutes;
        case AppTag.productive:
          p += minutes;
      }
    });
    return DaySummary(date: date, wasted: w, neutral: n, productive: p);
  }

  List<DaySummary> week(DateTime today, Map<String, AppTag> tags) {
    final out = <DaySummary>[];
    for (var i = 6; i >= 0; i--) {
      final d = dateOnly(today.subtract(Duration(days: i)));
      out.add(summaryOn(dayKeyOf(d), d, tags));
    }
    return out;
  }

  int weekMinutes(String appId, DateTime today) {
    var total = 0;
    for (var i = 0; i < 7; i++) {
      total += minutesOn(dayKeyOf(today.subtract(Duration(days: i))), appId);
    }
    return total;
  }

  /// Minutes reclaimed for the goal: time spent on productive apps this week.
  int reclaimedWeek(DateTime today, Map<String, AppTag> tags) {
    return week(today, tags).fold<int>(0, (sum, d) => sum + d.productive);
  }

  int wastedWeek(DateTime today, Map<String, AppTag> tags) {
    return week(today, tags).fold<int>(0, (sum, d) => sum + d.wasted);
  }

  int wastedPrevWeek(DateTime today, Map<String, AppTag> tags) {
    var total = 0;
    for (var i = 7; i < 14; i++) {
      final d = dateOnly(today.subtract(Duration(days: i)));
      total += summaryOn(dayKeyOf(d), d, tags).wasted;
    }
    return total;
  }
}

/// A generated judgement.
class Verdict {
  const Verdict({
    required this.headline,
    required this.body,
    required this.dayKey,
    required this.source,
    this.oneLiner,
  });

  final String headline;
  final String body;
  final int dayKey;

  /// 'ai' or 'local'
  final String source;
  final String? oneLiner;

  bool get fromAi => source == 'ai';
}

/// User-facing configuration, persisted to disk.
class AppSettings {
  AppSettings({
    this.tone = Tone.roast,
    this.goal = 'UI/UX designer',
    this.paceMinutes = 60,
    this.wastedLimitMinutes = 240,
    this.notifyEnabled = true,
    this.notifyAtMinutes = 22 * 60,
    AiProvider? provider,
    Map<String, String>? apiKeys,
    Map<String, String>? models,
    Map<Tone, String>? voicePrompts,
    this.customBaseUrl = '',
    Map<String, AppTag>? tags,
    this.setupComplete = false,
    Set<String>? coachSeen,
  }) : provider = provider ?? AiProviderX.defaultProvider,
       apiKeys = apiKeys ?? <String, String>{},
       models = models ?? <String, String>{},
       voicePrompts = voicePrompts ?? <Tone, String>{},
       tags = tags ?? <String, AppTag>{},
       coachSeen = coachSeen ?? <String>{};

  static const defaultModel = 'openai/gpt-oss-120b';

  /// Models this app used to hard-code. A saved id that matches one of these
  /// was our default, not the user's choice, so it is migrated to the current
  /// one when Groq stops serving it.
  static const _legacyModels = {
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
  };

  Tone tone;
  String goal;
  int paceMinutes;
  int wastedLimitMinutes;
  bool notifyEnabled;
  int notifyAtMinutes;

  /// Which AI service writes the verdict, if any.
  AiProvider provider;

  /// One key per provider, so switching back and forth never loses a key.
  Map<String, String> apiKeys;

  /// The model picked for each provider.
  Map<String, String> models;

  /// A written-by-the-user voice instruction per tone. Empty means the
  /// built-in voice is used.
  Map<Tone, String> voicePrompts;

  /// Base URL for [AiProvider.custom] only.
  String customBaseUrl;

  Map<String, AppTag> tags;
  bool setupComplete;

  /// Coachmark ids already shown, so a tip appears once per install.
  Set<String> coachSeen;

  String get apiKey => apiKeys[provider.id] ?? '';

  /// The shared writer needs no key; anything else needs one pasted in.
  bool get hasApiKey =>
      provider.requiresKey ? apiKey.trim().isNotEmpty : provider.available;

  String get model => models[provider.id] ?? provider.fallbackModels.first;

  /// Where requests go: the provider's own endpoint, or the custom one.
  String get endpointUrl => provider == AiProvider.custom
      ? customBaseUrl.trim()
      : provider.defaultBaseUrl;

  String voicePrompt(Tone tone) => voicePrompts[tone] ?? '';

  /// Drops a model id that was only ever our old default.
  static String migrateModel(String? raw) {
    final id = (raw ?? '').trim();
    if (id.isEmpty || _legacyModels.contains(id)) return defaultModel;
    return id;
  }

  AppSettings copy() => AppSettings(
    tone: tone,
    goal: goal,
    paceMinutes: paceMinutes,
    wastedLimitMinutes: wastedLimitMinutes,
    notifyEnabled: notifyEnabled,
    notifyAtMinutes: notifyAtMinutes,
    provider: provider,
    apiKeys: Map<String, String>.from(apiKeys),
    models: Map<String, String>.from(models),
    voicePrompts: Map<Tone, String>.from(voicePrompts),
    customBaseUrl: customBaseUrl,
    tags: Map<String, AppTag>.from(tags),
    setupComplete: setupComplete,
    coachSeen: {...coachSeen},
  );
}
