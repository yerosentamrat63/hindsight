import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../ai/providers.dart';
import '../ai/verdict_service.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'prompt.dart';

class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const ApiKeyScreen());

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  late final TextEditingController _key;
  late final TextEditingController _baseUrl;
  late final TextEditingController _modelField;
  late AiProvider _provider;
  late String _model;
  late List<String> _models;
  bool _reveal = false;
  bool _busy = false;
  bool _loadingModels = false;
  String? _modelsError;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppState>().settings;
    _provider = settings.provider;
    _key = TextEditingController(text: settings.apiKey);
    _baseUrl = TextEditingController(text: settings.customBaseUrl);
    _model = settings.model;
    _modelField = TextEditingController(text: _model);
    _models = _listFor(_provider, _model);
    if (settings.hasApiKey && _provider != AiProvider.custom) {
      _loadModels(settings.apiKey, quiet: true);
    }
  }

  @override
  void dispose() {
    _key.dispose();
    _baseUrl.dispose();
    _modelField.dispose();
    super.dispose();
  }

  /// The account's models are unknown until the key is checked, so the list
  /// starts from the provider's usual suspects plus whatever was picked before.
  List<String> _listFor(AiProvider provider, String model) {
    final base = provider.fallbackModels;
    return base.contains(model) ? base : [model, ...base.where((m) => m != model)];
  }

  /// Asks the provider which models this key may call, so we never offer one
  /// that answers with a 404.
  Future<List<String>?> _loadModels(String key, {bool quiet = false}) async {
    if (key.trim().isEmpty || _provider == AiProvider.custom) return null;
    if (!quiet) setState(() => _loadingModels = true);
    try {
      final models = await context.read<AppState>().fetchModels(
            provider: _provider,
            apiKey: key,
            baseUrl: _baseUrl.text,
          );
      if (!mounted) return models;
      setState(() {
        _models = models;
        _modelsError = null;
        _loadingModels = false;
        if (!models.contains(_model)) {
          _model = models.first;
          _modelField.text = _model;
        }
      });
      return models;
    } on VerdictException catch (e) {
      if (!mounted) return null;
      setState(() {
        _modelsError = e.message;
        _loadingModels = false;
      });
      return null;
    }
  }

  void _pick(AiProvider provider) {
    if (provider == _provider) return;
    final state = context.read<AppState>();
    final settings = state.settings;
    setState(() {
      _provider = provider;
      _modelsError = null;
      _key.text = settings.apiKeys[provider.id] ?? '';
      _model = settings.models[provider.id] ?? provider.fallbackModels.first;
      _modelField.text = _model;
      _models = _listFor(provider, _model);
    });
    state.setProvider(provider);
    if (_key.text.trim().isNotEmpty && provider != AiProvider.custom) {
      _loadModels(_key.text);
    }
  }

  Future<void> _saveAndTest() async {
    final state = context.read<AppState>();
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _modelsError = null;
    });
    await state.saveAiConfig(
      provider: _provider,
      apiKey: _key.text,
      model: _provider == AiProvider.custom ? _modelField.text : _model,
      baseUrl: _baseUrl.text,
    );

    String? problem;
    if (state.settings.hasApiKey) {
      if (_provider == AiProvider.custom) {
        // Local servers often cannot list models; the real test is a call.
        if (_modelField.text.trim().isEmpty) {
          problem = 'Type the model name your server serves.';
        } else {
          await state.saveAiConfig(
            provider: _provider,
            apiKey: _key.text,
            model: _modelField.text,
            baseUrl: _baseUrl.text,
          );
          await state.generateVerdict(force: true);
          problem = state.verdictError;
        }
      } else {
        final models = await _loadModels(_key.text);
        if (models == null) {
          problem = _modelsError;
        } else {
          await state.saveAiConfig(
            provider: _provider,
            apiKey: _key.text,
            model: _model,
            baseUrl: _baseUrl.text,
          );
          await state.generateVerdict(force: true);
          problem = state.verdictError;
        }
      }
    } else {
      await state.generateVerdict(force: true);
    }

    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: C.surface2,
        content: Text(
          problem ??
              (!state.settings.hasApiKey
                  ? 'Saved. No key, so offline verdicts are showing.'
                  : (state.verdict?.fromAi ?? false)
                      ? '$_model works. Verdict written by ${_provider.label}.'
                      : 'Saved. ${_provider.label} could not be reached, so '
                          'offline verdicts are showing.'),
          style: display(14, weight: 500, color: C.ink),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;
    final customCount = settings.voicePrompts.length;

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kScreenPad, 4, kScreenPad, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(title: 'Verdict writer'),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Who writes the verdict?',
                          style: display(30,
                              weight: 800, tracking: -0.035, height: 1.05)),
                      const SizedBox(height: 10),
                      Text(
                        'Hindsight does the counting on your phone. The words come '
                        'from a model you bring a key for. Without a key the '
                        'offline verdict still works — it just reuses the same '
                        'lines.',
                        style: display(15,
                            weight: 400, color: C.muted, height: 1.45),
                      ),
                      const SizedBox(height: 22),
                      const MonoLabel('Service'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final provider in AiProvider.values)
                            _PickChip(
                              label: provider.label,
                              selected: provider == _provider,
                              onTap: () => _pick(provider),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(_provider.blurb,
                          style: mono(11, color: C.faint, tracking: 0.02)),
                      if (_provider.needsBaseUrl) ...[
                        const SizedBox(height: 18),
                        const MonoLabel('Base URL'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _baseUrl,
                          style: mono(13, color: C.ink, tracking: 0.02),
                          cursorColor: C.lime,
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            hintText: 'http://192.168.1.10:11434/v1',
                            hintStyle: mono(13, color: C.faint),
                            filled: true,
                            fillColor: C.surface,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: C.border, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: C.ink, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Any OpenAI-compatible server: Ollama, LM Studio, '
                          'vLLM, or your own. Include /v1 if it needs it.',
                          style: display(12.5,
                              weight: 400, color: C.muted, height: 1.35),
                        ),
                      ],
                      const SizedBox(height: 18),
                      MonoLabel('${_provider.label} API key'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _key,
                        obscureText: !_reveal,
                        style: mono(14, color: C.ink, tracking: 0.02),
                        cursorColor: C.lime,
                        autocorrect: false,
                        enableSuggestions: false,
                        onSubmitted: (_) => _loadModels(_key.text),
                        decoration: InputDecoration(
                          hintText: _provider.keyHint,
                          hintStyle: mono(14, color: C.faint),
                          filled: true,
                          fillColor: C.surface,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_loadingModels)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(C.orange),
                                    ),
                                  ),
                                ),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _reveal = !_reveal),
                                icon: Icon(
                                  _reveal
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 20,
                                  color: C.muted,
                                ),
                              ),
                            ],
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: C.border, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: C.ink, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_provider.keysUrl.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: _provider.keysUrl),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: C.surface2,
                                content: Text(
                                    '${_provider.keysUrl} copied',
                                    style: display(14,
                                        weight: 500, color: C.ink)),
                              ),
                            );
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              const Icon(Icons.key_outlined,
                                  size: 16, color: C.lime),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Get a key at ${_provider.keysUrl.replaceFirst('https://', '')} · stored on this phone only',
                                  style: display(13,
                                      weight: 400, color: C.muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_modelsError != null) ...[
                        const SizedBox(height: 14),
                        NoticeBanner(
                          title: 'Key check failed',
                          body: _modelsError!,
                          icon: Icons.cloud_off,
                        ),
                      ],
                      const SizedBox(height: 22),
                      if (_provider == AiProvider.custom) ...[
                        const MonoLabel('Model'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _modelField,
                          style: mono(13, color: C.ink, tracking: 0.02),
                          cursorColor: C.lime,
                          autocorrect: false,
                          enableSuggestions: false,
                          onChanged: (v) => setState(() => _model = v.trim()),
                          decoration: InputDecoration(
                            hintText: 'llama3.2',
                            hintStyle: mono(13, color: C.faint),
                            filled: true,
                            fillColor: C.surface,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: C.border, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: C.ink, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'The model name your server expects, exactly as it '
                          'lists it.',
                          style: display(12.5,
                              weight: 400, color: C.muted, height: 1.35),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            const Expanded(child: MonoLabel('Model')),
                            GestureDetector(
                              onTap: _loadingModels
                                  ? null
                                  : () => _loadModels(_key.text),
                              behavior: HitTestBehavior.opaque,
                              child: Text(
                                _loadingModels ? 'Checking…' : 'Refresh',
                                style: mono(11, color: C.lime, tracking: 0.02),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final model in _models)
                              _PickChip(
                                label: model,
                                monospace: true,
                                selected: model == _model,
                                onTap: () => setState(() => _model = model),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 22),
                      Container(
                        decoration: cardDecoration(),
                        child: GestureDetector(
                          onTap: () =>
                              Navigator.of(context).push(PromptScreen.route()),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 54),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('Voice prompt',
                                      style: display(15, weight: 600)),
                                ),
                                Text(
                                  customCount == 0
                                      ? 'Built-in'
                                      : 'Custom · $customCount of 3',
                                  style: mono(12, tracking: 0.02),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right,
                                    size: 18, color: C.muted),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (settings.apiKeys.containsKey(_provider.id)) ...[
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () async {
                            await state.saveAiConfig(
                              provider: _provider,
                              apiKey: '',
                              model: _model,
                              baseUrl: _baseUrl.text,
                            );
                            await state.generateVerdict(force: true);
                            if (!mounted) return;
                            _key.clear();
                            setState(() {
                              _models = _provider.fallbackModels;
                              _modelsError = null;
                            });
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              const Icon(Icons.close, size: 18, color: C.orange),
                              const SizedBox(width: 8),
                              Text('Remove ${_provider.label} key',
                                  style: display(14,
                                      weight: 700, color: C.orange)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              PrimaryButton(
                label: _busy ? 'Checking…' : 'Save and test',
                icon: _busy ? null : Icons.bolt,
                onPressed: _busy ? null : _saveAndTest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickChip extends StatelessWidget {
  const _PickChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.monospace = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? C.ink : C.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? C.ink : C.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: monospace
              ? mono(12, color: selected ? C.bg : C.ink, tracking: 0.02)
              : display(14,
                  weight: 600, color: selected ? C.bg : C.ink, height: 1.2),
        ),
      ),
    );
  }
}
