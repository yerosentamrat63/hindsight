import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hindsight/data/usage_repository.dart';

/// The Kotlin side sends package-keyed maps; the app detail screen reads
/// `opensToday[id]` and `hourlyToday[id]` by package. This pins that contract so
/// a change to either side shows up as a failing test rather than a screen that
/// silently reads zero.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hindsight/usage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('queryUsage payload keeps opens and hourly buckets', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'queryUsage') return null;
      expect(call.arguments, {'days': 1});
      return {
        'apps': {
          'com.instagram.android': {'name': 'Instagram', 'initials': 'In'},
        },
        'daily': {
          '20261028': {'com.instagram.android': 105},
        },
        'opens': {'com.instagram.android': 7},
        'hourly': {
          'com.instagram.android': [0, 0, 0, 0, 0, 0, 0, 0, 0, 12, 30, 5,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        },
      };
    });

    final data = await UsageRepository().read(days: 1);

    expect(data, isNotNull);
    expect(data!.apps['com.instagram.android']!.name, 'Instagram');
    expect(data.daily[20261028]!['com.instagram.android'], 105);
    expect(data.opensToday['com.instagram.android'], 7);
    expect(data.hourlyToday['com.instagram.android']![9], 12);
    expect(data.hourlyToday['com.instagram.android']!.length, 24);
  });

  test('a failed query surfaces instead of a half-filled payload', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'query_failed', message: 'boom');
    });

    expect(
      () => UsageRepository().read(days: 1),
      throwsA(isA<PlatformException>()),
    );
  });
}
