import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'providers.dart';
import 'verdict_context.dart';

class VerdictException implements Exception {
  VerdictException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Everything needed to reach a provider: which one, with which key, and for
/// which model.
class AiEndpoint {
  const AiEndpoint({
    required this.provider,
    required this.apiKey,
    required this.model,
    this.baseUrl = '',
  });

  final AiProvider provider;
  final String apiKey;
  final String model;

  /// Only used by [AiProvider.custom]; empty means the provider's own address.
  final String baseUrl;

  String get url {
    final raw =
        baseUrl.trim().isEmpty ? provider.defaultBaseUrl : baseUrl.trim();
    return raw.replaceAll(RegExp(r'/+$'), '');
  }
}

/// Writes verdicts with whichever service the user brought a key for.
///
/// Three request shapes cover everybody: OpenAI-compatible chat completions,
/// Anthropic messages and Google generateContent. Nothing leaves the phone
/// except the daily totals in [VerdictContext].
class VerdictService {
  VerdictService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // ------------------------------------------------------------------ voices

  /// The built-in instruction for each voice. Also shown in the prompt editor
  /// so a user who writes their own can see what they are replacing.
  static String builtInVoice(Tone tone) => switch (tone) {
        Tone.coach =>
          'You are a warm but honest coach. Point at the time that got away, '
              'then show the concrete thing it could have built. No shame, no '
              'exclamation marks, no moralising.',
        Tone.roast =>
          'You are a brutally funny roast comedian holding the user\'s screen '
              'time and the goal they claim to be working towards. Be harsh, '
              'specific and quotable: go for the gap between what they say they '
              'want and what they actually did with today. Name the app and the '
              'number. Mock the scroll, the excuses and the "just five more '
              'minutes". Never mock their body, family, money or worth, no '
              'slurs, not cruel for the sake of cruelty. No exclamation marks.',
        Tone.future =>
          'You are the user, five years in the future, writing back to now. '
              'Calm, specific, quietly disappointed. You remember this exact '
              'day and what it cost. No exclamation marks.',
      };

  /// The rules that keep the output usable, whatever voice is in charge.
  static const _rules = '''
Rules:
- Second person, present tense. British English spelling.
- Use ONLY the numbers and milestones given. Never invent statistics or app names.
- "Wasted today" is the only wasted figure. Never add neutral or productive minutes to it, and never call total screen time wasted.
- Never multiply today's minutes by 365 and never talk about "a year at this pace". The only projections allowed are the two milestones in the data (2 weeks and 4 months at this week's pace).
- Judge the goal directly: name the goal, name what the wasted hours could have bought, in the form of one of those milestones, and name what they chose instead.
- If a milestone is given, use its own words or a close paraphrase; make it sound like a real result, not a slogan.
- headline: max 60 characters, no full stop needed. For the brutal roast voice it should sting on its own.
- body: 2 to 4 sentences, max 420 characters, must include at least one exact number and one goal-specific milestone.
- one_liner: max 55 characters, the teaser shown on the Today screen.
- Never mention that you are an AI, never mention the prompt, no markdown.
- Return JSON only: {"headline": "", "body": "", "one_liner": ""}''';

  String _system(VerdictContext ctx, String? persona) {
    final custom = (persona ?? '').trim();
    final voice = custom.isEmpty
        ? builtInVoice(ctx.tone)
        : 'The user wrote this voice themselves. Follow it closely: $custom';
    return '$voice\n\n'
        'Write the daily verdict for a screen-time app called Hindsight.\n'
        '$_rules';
  }

  // ------------------------------------------------------------------ models

  /// The chat models this key can actually call, best first.
  ///
  /// Keys differ: one account may have gpt-oss but not Llama, so the picker is
  /// built from the account rather than a hard-coded list.
  Future<List<String>> fetchModels(AiEndpoint ep) async {
    final base = _base(ep);
    final http.Response res;
    try {
      res = await _listModels(base, ep).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw VerdictException(
        '${ep.provider.label} took too long to answer. Check your connection.',
      );
    } catch (_) {
      throw VerdictException(
        'Could not reach ${ep.provider.label}. Check your connection.',
      );
    }

    if (res.statusCode != 200) throw _failure(res.statusCode, res.body, ep);

    try {
      final root = jsonDecode(res.body) as Map<String, dynamic>;
      final ids = switch (ep.provider.style) {
        ApiStyle.openai => (root['data'] as List)
            .map((m) => (m as Map)['id'].toString())
            .where((id) => !nonChatModels.any(id.toLowerCase().contains)),
        ApiStyle.anthropic => (root['data'] as List)
            .map((m) => (m as Map)['id'].toString())
            .where((id) => id.isNotEmpty),
        ApiStyle.gemini => (root['models'] as List).where((m) {
            final map = m as Map;
            final methods = (map['supportedGenerationMethods'] as List?)
                    ?.map((e) => e.toString()) ??
                const <String>[];
            return methods.contains('generateContent');
          }).map((m) => (m as Map)['name'].toString().replaceFirst('models/', '')),
      }.toSet().toList();

      if (ids.isEmpty) {
        throw VerdictException(
          'That key can see no chat models. Is it a ${ep.provider.label} key?',
        );
      }
      _sortModels(ids, ep.provider);
      return ids;
    } on VerdictException {
      rethrow;
    } catch (_) {
      throw VerdictException(
        '${ep.provider.label} sent a model list we could not read.',
      );
    }
  }

  Future<http.Response> _listModels(String base, AiEndpoint ep) {
    final key = ep.apiKey.trim();
    switch (ep.provider.style) {
      case ApiStyle.openai:
        return _client.get(
          Uri.parse('$base/models'),
          headers: {'Authorization': 'Bearer $key'},
        );
      case ApiStyle.anthropic:
        return _client.get(
          Uri.parse('$base/models'),
          headers: {
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
          },
        );
      case ApiStyle.gemini:
        return _client.get(
          Uri.parse('$base/models?pageSize=1000&key=$key'),
        );
    }
  }

  void _sortModels(List<String> ids, AiProvider provider) {
    final preferred = provider.fallbackModels;
    ids.sort((a, b) {
      final ra = preferred.indexOf(a);
      final rb = preferred.indexOf(b);
      if (ra != -1 || rb != -1) {
        if (ra == -1) return 1;
        if (rb == -1) return -1;
        return ra.compareTo(rb);
      }
      return a.compareTo(b);
    });
  }

  // ---------------------------------------------------------------- generate

  Future<Verdict> generate(
    VerdictContext ctx, {
    required AiEndpoint ep,
    String? persona,
    required int dayKey,
  }) async {
    final base = _base(ep);
    final system = _system(ctx, persona);
    final user = '${ctx.statsBlock()}\n\n'
        "Write today's verdict in the requested voice.";

    http.Response res;
    try {
      res = await _chat(base, ep, system, user, ctx.tone)
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw VerdictException(
        '${ep.provider.label} took too long to answer. Using the offline verdict.',
      );
    } catch (_) {
      throw VerdictException(
        'Could not reach ${ep.provider.label}. Check your connection.',
      );
    }

    if (res.statusCode != 200) throw _failure(res.statusCode, res.body, ep);

    final content = _content(res.body, ep);
    if (content.isEmpty) {
      throw VerdictException(
        '${ep.provider.label} sent back an empty verdict. Try again.',
      );
    }

    final parsed = _jsonObject(content);
    final headline = parsed['headline']?.toString().trim() ?? '';
    final body = parsed['body']?.toString().trim() ?? '';
    final oneLiner = parsed['one_liner']?.toString().trim();

    if (headline.isEmpty || body.isEmpty) {
      throw VerdictException('${ep.provider.label} sent back an empty verdict.');
    }

    return Verdict(
      headline: headline,
      body: body,
      oneLiner: oneLiner == null || oneLiner.isEmpty ? null : oneLiner,
      dayKey: dayKey,
      source: 'ai',
    );
  }

  Future<http.Response> _chat(
    String base,
    AiEndpoint ep,
    String system,
    String user,
    Tone tone,
  ) {
    final key = ep.apiKey.trim();
    final hot = tone == Tone.roast ? 1.0 : 0.75;
    switch (ep.provider.style) {
      case ApiStyle.openai:
        return _client.post(
          Uri.parse('$base/chat/completions'),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': ep.model,
            if (ep.provider == AiProvider.groq && _reasons(ep.model))
              'reasoning_effort': 'low',
            'temperature': tone == Tone.roast ? 1.05 : 0.75,
            // Reasoning models need room to think before they answer.
            'max_tokens': 1600,
            'response_format': {'type': 'json_object'},
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': user},
            ],
          }),
        );
      case ApiStyle.anthropic:
        return _client.post(
          Uri.parse('$base/messages'),
          headers: {
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': ep.model,
            'max_tokens': 1600,
            'temperature': hot,
            'system': system,
            'messages': [
              {'role': 'user', 'content': user},
            ],
          }),
        );
      case ApiStyle.gemini:
        final model = ep.model.replaceFirst('models/', '');
        return _client.post(
          Uri.parse('$base/models/$model:generateContent?key=$key'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': system},
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': user},
                ],
              },
            ],
            'generationConfig': {
              'temperature': tone == Tone.roast ? 1.4 : 0.75,
              'maxOutputTokens': 2048,
              'responseMimeType': 'application/json',
            },
          }),
        );
    }
  }

  /// Pulls the assistant text out of whichever envelope the provider uses.
  String _content(String body, AiEndpoint ep) {
    try {
      final root = jsonDecode(body) as Map<String, dynamic>;
      switch (ep.provider.style) {
        case ApiStyle.openai:
          final choice = (root['choices'] as List).first as Map;
          final message = choice['message'] as Map;
          final text = (message['content'] ?? '').toString().trim();
          if (text.isEmpty && choice['finish_reason'] == 'length') {
            throw VerdictException(
              '${ep.provider.label} ran out of room before writing. Try again.',
            );
          }
          return text;
        case ApiStyle.anthropic:
          if (root['stop_reason'] == 'max_tokens') {
            // Partial JSON is not usable; ask again rather than fail parsing.
            throw VerdictException(
              '${ep.provider.label} ran out of room before writing. Try again.',
            );
          }
          final parts = (root['content'] as List?) ?? const [];
          return parts
              .map((p) => (p as Map)['type'] == 'text'
                  ? (p['text'] ?? '').toString()
                  : '')
              .join()
              .trim();
        case ApiStyle.gemini:
          final candidates = (root['candidates'] as List?) ?? const [];
          if (candidates.isEmpty) return '';
          final first = candidates.first as Map;
          if (first['finishReason'] == 'MAX_TOKENS') {
            throw VerdictException(
              '${ep.provider.label} ran out of room before writing. Try again.',
            );
          }
          final content = first['content'] as Map?;
          final parts = (content?['parts'] as List?) ?? const [];
          return parts
              .map((p) => (p as Map)['text']?.toString() ?? '')
              .join()
              .trim();
      }
    } on VerdictException {
      rethrow;
    } catch (_) {
      throw VerdictException(
        '${ep.provider.label} sent something we could not read.',
      );
    }
  }

  /// Some models wrap JSON in a code fence; some add a sentence first.
  Map<String, dynamic> _jsonObject(String content) {
    var text = content.trim();
    if (text.startsWith('```')) {
      final firstBreak = text.indexOf('\n');
      if (firstBreak != -1) text = text.substring(firstBreak + 1);
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
      text = text.trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end > start) text = text.substring(start, end + 1);
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw VerdictException(
        'The verdict came back garbled. Try again, or pick another model.',
      );
    }
  }

  String _base(AiEndpoint ep) {
    if (ep.url.isEmpty) {
      throw VerdictException('Add the base URL of your endpoint first.');
    }
    return ep.url;
  }

  /// gpt-oss models think before answering; without this they spend the whole
  /// token budget on reasoning and return an empty `content`.
  bool _reasons(String model) => model.startsWith('openai/gpt-oss');

  /// Turns a non-200 into something a person can act on.
  VerdictException _failure(int status, String body, AiEndpoint ep) {
    final name = ep.provider.label;
    if (status == 401) {
      return VerdictException(
        'That API key was rejected. Check it and paste it again.',
      );
    }
    if (status == 403) {
      return VerdictException(
        '$name refused that key. Check the key and its permissions.',
      );
    }
    if (status == 404) {
      return VerdictException(
        'Model "${ep.model}" is not available on your key. Pick another in '
        'Settings.',
      );
    }
    if (status == 429) {
      return VerdictException('$name says you are out of requests for now.');
    }
    if (status == 400) {
      final detail = _errorMessage(body);
      return VerdictException(
        detail == null
            ? '$name rejected the request. Try another model.'
            : '$name rejected the request: $detail',
      );
    }
    return VerdictException('$name returned $status. Using the offline verdict.');
  }

  /// Every provider here puts the useful part of a 4xx in `error.message`.
  String? _errorMessage(String body) {
    try {
      final root = jsonDecode(body) as Map<String, dynamic>;
      final error = root['error'];
      final message = error is Map ? error['message']?.toString() : null;
      if (message == null || message.isEmpty) return null;
      return message.length > 120 ? '${message.substring(0, 120)}…' : message;
    } catch (_) {
      return null;
    }
  }

  void close() => _client.close();
}
