import '../ai/providers.dart';
import '../format.dart';
import 'tone.dart';

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
