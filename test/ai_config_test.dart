import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hindsight/ai/providers.dart';
import 'package:hindsight/ai/verdict_context.dart';
import 'package:hindsight/ai/verdict_service.dart';
import 'package:hindsight/data/sample_usage.dart';
import 'package:hindsight/data/usage_repository.dart';
import 'package:hindsight/format.dart';
import 'package:hindsight/models.dart';
import 'package:hindsight/store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Same idea as the widget smoke test: no platform channels, sample data.
class _DemoUsage extends UsageRepository {
  @override
  bool get isAndroid => false;

  @override
  Future<bool> hasAccess() async => false;

  @override
  Future<UsageData> load({int days = 14}) async => buildSampleUsage();

  @override
  Future<void> openAccessSettings() async {}
}

Future<AppState> _state() async {
  final state = AppState(repo: _DemoUsage());
  await state.init();
  return state;
}

VerdictContext _context({Tone tone = Tone.roast}) => VerdictContext(
      tone: tone,
      goal: 'UI/UX designer',
      paceMinutes: 60,
      wastedToday: 273,
      neutralToday: 52,
      productiveToday: 47,
      wastedWeek: 2079,
      wastedPrevWeek: 2292,
      limitMinutes: 240,
      opensToday: 142,
      topApps: const [
        AppLine(name: 'TikTok', minutes: 160, tag: AppTag.wasted),
      ],
    );

String _verdictJson() =>
    '{"headline":"H","body":"B with 4h 33m.","one_liner":"O"}';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a fresh install can tag an app', () async {
    final state = await _state();
    expect(state.settings.tags, isEmpty);

    // This used to throw: the default tag map was const, so the write failed
    // and onboarding tags looked stuck.
    await state.cycleTag('tiktok');
    expect(state.settings.tags['tiktok'], AppTag.wasted.next);
    expect(state.tagFor(state.usage.apps['tiktok']!), AppTag.wasted.next);
  });

  test('keys and models are kept per provider', () async {
    final state = await _state();
    await state.saveAiConfig(
      provider: AiProvider.openai,
      apiKey: 'sk-openai',
      model: 'gpt-4o-mini',
    );
    await state.saveAiConfig(
      provider: AiProvider.groq,
      apiKey: 'gsk-groq',
      model: 'openai/gpt-oss-20b',
    );

    expect(state.settings.provider, AiProvider.groq);
    expect(state.settings.apiKey, 'gsk-groq');

    await state.setProvider(AiProvider.openai);
    expect(state.settings.apiKey, 'sk-openai');
    expect(state.settings.model, 'gpt-4o-mini');

    // Switching back costs nothing.
    await state.setProvider(AiProvider.groq);
    expect(state.settings.apiKey, 'gsk-groq');
    expect(state.settings.model, 'openai/gpt-oss-20b');

    await state.setVoicePrompts({Tone.roast: '  Sound like a coach.  '});
    expect(state.settings.voicePrompt(Tone.roast), 'Sound like a coach.');

    final restarted = await _state();
    expect(restarted.settings.provider, AiProvider.groq);
    expect(restarted.settings.apiKey, 'gsk-groq');
    expect(restarted.settings.apiKeys[AiProvider.openai.id], 'sk-openai');
    expect(restarted.settings.model, 'openai/gpt-oss-20b');
    expect(restarted.settings.voicePrompt(Tone.roast), 'Sound like a coach.');
  });

  test('a single old Groq key still loads', () async {
    SharedPreferences.setMockInitialValues({
      'settings.v1': jsonEncode({
        'tone': 'future',
        'goal': 'Writer',
        'pace': 30,
        'limit': 60,
        'notify': true,
        'notifyAt': 1200,
        'apiKey': 'gsk_old',
        'model': 'llama-3.3-70b-versatile',
        'tags': {'tiktok': 'productive'},
        'setupComplete': true,
        'coach': <String>[],
      }),
    });

    final state = await _state();
    expect(state.settings.provider, AiProvider.groq);
    expect(state.settings.apiKey, 'gsk_old');
    expect(state.settings.model, AppSettings.defaultModel);
    expect(state.settings.goal, 'Writer');
    expect(state.settings.tags['tiktok'], AppTag.productive);
  });

  test('a custom prompt reaches the model and keeps the fixed rules', () async {
    http.Request? sent;
    final service = VerdictService(
      client: MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': _verdictJson()},
                'finish_reason': 'stop',
              },
            ],
          }),
          200,
        );
      }),
    );

    final verdict = await service.generate(
      _context(),
      ep: const AiEndpoint(
        provider: AiProvider.groq,
        apiKey: 'gsk_test',
        model: 'openai/gpt-oss-120b',
      ),
      persona: 'Sound like a football coach.',
      dayKey: 20261029,
    );

    expect(verdict.fromAi, isTrue);
    expect(verdict.body, contains('4h 33m'));
    expect(sent!.url.toString(), 'https://api.groq.com/openai/v1/chat/completions');
    expect(sent!.headers['Authorization'], 'Bearer gsk_test');

    final body = jsonDecode(sent!.body) as Map<String, dynamic>;
    final system = (body['messages'] as List).first['content'] as String;
    expect(system, contains('Sound like a football coach.'));
    expect(system, contains('Return JSON only'));
    expect(system, contains('Wasted today'));
    // The built-in roast persona is replaced, not stacked on top of.
    expect(system, isNot(contains('roast comedian')));
  });

  test('Anthropic and Gemini envelopes are read correctly', () async {
    final anthropic = VerdictService(
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://api.anthropic.com/v1/messages');
        expect(request.headers['x-api-key'], 'sk-ant-test');
        expect(request.headers['anthropic-version'], isNotNull);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['system'], isA<String>());
        return http.Response(
          jsonEncode({
            'stop_reason': 'end_turn',
            'content': [
              {'type': 'text', 'text': '```json\n${_verdictJson()}\n```'},
            ],
          }),
          200,
        );
      }),
    );

    final a = await anthropic.generate(
      _context(),
      ep: const AiEndpoint(
        provider: AiProvider.anthropic,
        apiKey: 'sk-ant-test',
        model: 'claude-3-5-haiku-latest',
      ),
      dayKey: 20261029,
    );
    expect(a.headline, 'H');

    final gemini = VerdictService(
      client: MockClient((request) async {
        expect(request.url.path, contains('/models/gemini-2.0-flash:generateContent'));
        expect(request.url.queryParameters['key'], 'AIza-test');
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'finishReason': 'STOP',
                'content': {
                  'parts': [
                    {'text': _verdictJson()},
                  ],
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final g = await gemini.generate(
      _context(),
      ep: const AiEndpoint(
        provider: AiProvider.gemini,
        apiKey: 'AIza-test',
        model: 'gemini-2.0-flash',
      ),
      dayKey: 20261029,
    );
    expect(g.body, contains('4h 33m'));
  });

  test('Gemini model listing keeps only chat models', () async {
    final service = VerdictService(
      client: MockClient((request) async {
        expect(request.url.queryParameters['key'], 'AIza-test');
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-2.0-flash',
                'supportedGenerationMethods': ['generateContent'],
              },
              {
                'name': 'models/text-embedding-004',
                'supportedGenerationMethods': ['embedContent'],
              },
            ],
          }),
          200,
        );
      }),
    );

    final models = await service.fetchModels(const AiEndpoint(
      provider: AiProvider.gemini,
      apiKey: 'AIza-test',
      model: 'gemini-2.0-flash',
    ));
    expect(models, ['gemini-2.0-flash']);
  });

  test('a rejected key says so in words', () async {
    final service = VerdictService(
      client: MockClient((_) async => http.Response('{}', 401)),
    );

    expect(
      () => service.fetchModels(const AiEndpoint(
        provider: AiProvider.openai,
        apiKey: 'sk-wrong',
        model: 'gpt-4o-mini',
      )),
      throwsA(
        isA<VerdictException>().having(
          (e) => e.message,
          'message',
          contains('rejected'),
        ),
      ),
    );
  });
}
