import 'package:flutter_test/flutter_test.dart';
import 'package:hindsight/data/sample_usage.dart';
import 'package:hindsight/data/usage_repository.dart';
import 'package:hindsight/models.dart';
import 'package:hindsight/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DemoUsage extends UsageRepository {
  @override
  bool get isAndroid => false;

  @override
  Future<bool> hasAccess() async => false;

  @override
  Future<UsageData> load({int days = 14}) async => buildSampleUsage();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('switching voice marks the verdict out of date', () async {
    final state = AppState(repo: _DemoUsage());
    await state.init();
    await state.generateVerdict();

    expect(state.verdictStale, isFalse);
    final roastHeadline = state.verdict!.headline;

    await state.setTone(Tone.coach);
    expect(state.verdictStale, isTrue);
    expect(state.staleReason.toLowerCase(), contains('voice'));

    await state.generateVerdict(force: true);
    expect(state.verdictStale, isFalse);
    expect(state.verdict!.headline, isNot(roastHeadline));
  });

  test('changing the goal marks the verdict out of date', () async {
    final state = AppState(repo: _DemoUsage());
    await state.init();
    await state.generateVerdict();

    await state.setGoal('Backend developer');
    expect(state.verdictStale, isTrue);
    expect(state.staleReason.toLowerCase(), contains('goal'));

    await state.generateVerdict(force: true);
    expect(state.verdictStale, isFalse);
    expect(state.verdict!.body.toLowerCase(),
        anyOf(contains('api'), contains('backend')));
  });

  test('coach tips are remembered and can be replayed', () async {
    final state = AppState(repo: _DemoUsage());
    await state.init();

    await state.markCoachSeen('today.verdict');
    expect(state.settings.coachSeen, contains('today.verdict'));

    await state.resetCoachTips();
    expect(state.settings.coachSeen, isEmpty);
  });
}
