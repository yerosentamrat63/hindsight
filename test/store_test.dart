import 'package:flutter_test/flutter_test.dart';
import 'package:hindsight/data/sample_usage.dart';
import 'package:hindsight/data/usage_repository.dart';
import 'package:hindsight/format.dart';
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

  test('dayOffset shifts calendar days correctly across month boundaries', () {
    final nov1 = DateTime(2026, 11, 1);
    final oct31 = dayOffset(nov1, -1);
    expect(oct31.year, 2026);
    expect(oct31.month, 10);
    expect(oct31.day, 31);
    expect(dayKeyOf(oct31), 20261031);
  });

  test('refreshUsage advances today when day shifts across midnight', () async {
    final state = AppState(repo: _DemoUsage());
    await state.init();

    // Artificially simulate that state was initialized yesterday
    state.today = dayOffset(state.today, -1);
    final yesterday = state.today;

    await state.refreshUsage();
    expect(state.today, isNot(yesterday));
    expect(state.today, dateOnly(DateTime.now()));
  });

  test('deleteAllData resets state, settings, and cached verdict basis', () async {
    final state = AppState(repo: _DemoUsage());
    await state.init();
    await state.setGoal('Mobile Architect');
    await state.generateVerdict();

    expect(state.settings.goal, 'Mobile Architect');
    expect(state.verdict, isNotNull);

    await state.deleteAllData();
    expect(state.settings.goal, 'UI/UX designer');
    expect(state.verdict, isNull);
    expect(state.verdictStale, isFalse);
  });
}
