import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/verdict_service.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Lets the user write the voice instruction the AI follows, one per tone.
///
/// Empty means the built-in voice. The counting rules stay fixed either way,
/// so a custom prompt cannot invent numbers or break the JSON the app reads.
class PromptScreen extends StatefulWidget {
  const PromptScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const PromptScreen());

  @override
  State<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends State<PromptScreen> {
  late Tone _tone;
  late final Map<Tone, TextEditingController> _fields;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppState>().settings;
    _tone = settings.tone;
    _fields = {
      for (final tone in Tone.values)
        tone: TextEditingController(text: settings.voicePrompt(tone)),
    };
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  bool _custom(Tone tone) => _fields[tone]!.text.trim().isNotEmpty;

  Future<void> _save() async {
    setState(() => _busy = true);
    FocusScope.of(context).unfocus();
    await context.read<AppState>().setVoicePrompts({
      for (final entry in _fields.entries) entry.key: entry.value.text,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final field = _fields[_tone]!;

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kScreenPad, 4, kScreenPad, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(title: 'Verdict prompt'),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tell it how to say it',
                        style: display(
                          30,
                          weight: 800,
                          tracking: -0.035,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Write the voice the AI should use, per tone. Leave a box '
                        'empty and the built-in voice is used. Your numbers and '
                        'milestones are always counted on the phone, so a custom '
                        'prompt cannot invent them.',
                        style: display(
                          15,
                          weight: 400,
                          color: C.muted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          for (var i = 0; i < Tone.values.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _ToneTab(
                                tone: Tone.values[i],
                                selected: Tone.values[i] == _tone,
                                custom: _custom(Tone.values[i]),
                                onTap: () =>
                                    setState(() => _tone = Tone.values[i]),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),
                      const MonoLabel('Your instruction'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: field,
                        minLines: 7,
                        maxLines: 12,
                        keyboardType: TextInputType.multiline,
                        style: display(15, weight: 400, height: 1.4),
                        cursorColor: C.lime,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText:
                              'e.g. Sound like a disappointed football '
                              'coach. Short sentences. Name the app and the '
                              'minutes, then say what the time should have '
                              'bought. No jokes, no exclamation marks.',
                          hintStyle: display(
                            15,
                            weight: 400,
                            color: C.faint,
                            height: 1.4,
                          ),
                          filled: true,
                          fillColor: C.surface,
                          contentPadding: const EdgeInsets.all(16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: C.border,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: C.ink,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                field.text = VerdictService.builtInVoice(_tone);
                                setState(() {});
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Start from the built-in voice',
                                  style: mono(
                                    12,
                                    color: C.lime,
                                    tracking: 0.02,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_custom(_tone))
                            GestureDetector(
                              onTap: () {
                                field.clear();
                                setState(() {});
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Clear',
                                  style: mono(
                                    12,
                                    color: C.orange,
                                    tracking: 0.02,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: cardDecoration(radius: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MonoLabel('Built-in · ${_tone.label}'),
                            const SizedBox(height: 4),
                            Text(
                              VerdictService.builtInVoice(_tone),
                              style: display(
                                13,
                                weight: 400,
                                color: C.inkDim,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!state.settings.hasApiKey) ...[
                        const SizedBox(height: 12),
                        const NoticeBanner(
                          title: 'No AI key yet',
                          body:
                              'Custom voices only apply when an AI service is '
                              'writing the verdict. Offline verdicts use the '
                              'built-in lines.',
                          color: C.lime,
                          icon: Icons.info_outline,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                color: C.bg,
                padding: const EdgeInsets.only(top: 6),
                child: PrimaryButton(
                  label: _busy ? 'Saving…' : 'Save prompt',
                  icon: _busy ? null : Icons.check_rounded,
                  onPressed: _busy ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToneTab extends StatelessWidget {
  const _ToneTab({
    required this.tone,
    required this.selected,
    required this.custom,
    required this.onTap,
  });

  final Tone tone;
  final bool selected;
  final bool custom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? C.ink : C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? C.ink : (custom ? C.orange : C.border),
            width: 1.5,
          ),
        ),
        child: Text(
          tone.label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: display(
            13,
            weight: 600,
            color: selected ? C.bg : C.ink,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
