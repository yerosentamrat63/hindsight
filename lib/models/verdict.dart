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
