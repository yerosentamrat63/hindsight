/// The shape of the HTTP API behind a provider.
enum ApiStyle {
  /// `/chat/completions` with a bearer token. Groq, OpenAI, OpenRouter and most
  /// self-hosted servers speak this.
  openai,

  /// Anthropic's `/messages` with `x-api-key`.
  anthropic,

  /// Google's `generateContent`.
  gemini,
}

/// The shared verdict proxy.
///
/// A build can carry one with
/// `--dart-define=HINDSIGHT_PROXY=https://hindsight-verdict.<you>.workers.dev/v1`.
/// The proxy holds the Groq key, so a friend who installs that build never has
/// to paste anything. A build without the define simply does not offer it.
class HindsightCloud {
  HindsightCloud._();

  static String baseUrl = const String.fromEnvironment('HINDSIGHT_PROXY');

  static bool get configured => baseUrl.trim().isNotEmpty;
}

/// Services that can write a verdict.
///
/// [hindsight] is the only one that needs no key; the rest are bring-your-own.
enum AiProvider {
  hindsight,
  groq,
  openai,
  anthropic,
  gemini,
  openrouter,
  custom,
}

extension AiProviderX on AiProvider {
  /// What a fresh install starts on: the shared writer when the build has one,
  /// otherwise Groq, where the user brings a key.
  static AiProvider get defaultProvider =>
      HindsightCloud.configured ? AiProvider.hindsight : AiProvider.groq;

  String get id => name;

  /// The shared writer cannot work unless this build was pointed at a proxy.
  bool get available =>
      this != AiProvider.hindsight || HindsightCloud.configured;

  /// Only the shared writer works without the user pasting something.
  bool get requiresKey => this != AiProvider.hindsight;

  String get label => switch (this) {
    AiProvider.hindsight => 'Hindsight',
    AiProvider.groq => 'Groq',
    AiProvider.openai => 'OpenAI',
    AiProvider.anthropic => 'Anthropic',
    AiProvider.gemini => 'Google Gemini',
    AiProvider.openrouter => 'OpenRouter',
    AiProvider.custom => 'OpenAI-compatible',
  };

  /// One line for the picker.
  String get blurb => switch (this) {
    AiProvider.hindsight => 'Included, no key needed',
    AiProvider.groq => 'Fast and free tier',
    AiProvider.openai => 'Your ChatGPT key',
    AiProvider.anthropic => 'Claude models',
    AiProvider.gemini => 'Free tier with AI Studio',
    AiProvider.openrouter => 'Many models, one key',
    AiProvider.custom => 'Ollama, LM Studio, vLLM',
  };

  ApiStyle get style => switch (this) {
    AiProvider.anthropic => ApiStyle.anthropic,
    AiProvider.gemini => ApiStyle.gemini,
    _ => ApiStyle.openai,
  };

  String get defaultBaseUrl => switch (this) {
    AiProvider.hindsight => HindsightCloud.baseUrl.trim(),
    AiProvider.groq => 'https://api.groq.com/openai/v1',
    AiProvider.openai => 'https://api.openai.com/v1',
    AiProvider.anthropic => 'https://api.anthropic.com/v1',
    AiProvider.gemini => 'https://generativelanguage.googleapis.com/v1beta',
    AiProvider.openrouter => 'https://openrouter.ai/api/v1',
    AiProvider.custom => '',
  };

  /// Shown before a key has been checked; a real key replaces this list with
  /// whatever the account can actually call.
  List<String> get fallbackModels => switch (this) {
    AiProvider.hindsight => const ['openai/gpt-oss-120b', 'openai/gpt-oss-20b'],
    AiProvider.groq => const ['openai/gpt-oss-120b', 'openai/gpt-oss-20b'],
    AiProvider.openai => const ['gpt-4o-mini', 'gpt-4.1-mini'],
    AiProvider.anthropic => const [
      'claude-3-5-haiku-latest',
      'claude-3-5-sonnet-latest',
    ],
    AiProvider.gemini => const ['gemini-2.0-flash', 'gemini-1.5-flash'],
    AiProvider.openrouter => const [
      'openai/gpt-4o-mini',
      'anthropic/claude-3.5-sonnet',
    ],
    AiProvider.custom => const ['llama3.2'],
  };

  String get keyHint => switch (this) {
    AiProvider.hindsight => '',
    AiProvider.groq => 'gsk_…',
    AiProvider.openai => 'sk-…',
    AiProvider.anthropic => 'sk-ant-…',
    AiProvider.gemini => 'AIza…',
    AiProvider.openrouter => 'sk-or-…',
    AiProvider.custom => 'Whatever your server expects',
  };

  /// Where the user gets a key. Copy-pasted by the key field.
  String get keysUrl => switch (this) {
    AiProvider.hindsight => '',
    AiProvider.groq => 'https://console.groq.com/keys',
    AiProvider.openai => 'https://platform.openai.com/api-keys',
    AiProvider.anthropic => 'https://console.anthropic.com/settings/keys',
    AiProvider.gemini => 'https://aistudio.google.com/apikey',
    AiProvider.openrouter => 'https://openrouter.ai/keys',
    AiProvider.custom => '',
  };

  bool get needsBaseUrl => this == AiProvider.custom;

  /// Falls back to the build's default when the saved provider is not in this
  /// build (a friends build's "hindsight" opened in the public build).
  static AiProvider parse(String? raw) {
    for (final p in AiProvider.values) {
      if (p.id == raw && p.available) return p;
    }
    return defaultProvider;
  }
}

/// Model ids that show up in `/models` but cannot write a verdict.
const nonChatModels = [
  'whisper',
  'orpheus',
  'guard',
  'tts',
  'embed',
  'moderation',
  'rerank',
];
