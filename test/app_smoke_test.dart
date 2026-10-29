import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hindsight/ai/providers.dart';
import 'package:hindsight/data/sample_usage.dart';
import 'package:hindsight/data/usage_repository.dart';
import 'package:hindsight/main.dart';
import 'package:hindsight/models.dart';
import 'package:hindsight/screens/api_key.dart';
import 'package:hindsight/screens/onboarding.dart';
import 'package:hindsight/screens/prompt.dart';
import 'package:hindsight/screens/settings_screen.dart';
import 'package:hindsight/store.dart';
import 'package:hindsight/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget tests report Android as the target platform, so the real repository
/// would call the `hindsight/usage` channel and wait forever for a host that is
/// not there. This one behaves like the app on a device without the switch on:
/// sample data, no access.
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

Widget _wrap(Widget child, AppState state) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(theme: AppTheme.build(), home: child),
  );
}

Future<AppState> _ready(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final state = AppState(repo: _DemoUsage());
  await state.init();
  return state;
}

/// The nav shows a label only for the tab you are on, so unselected tabs are
/// reached through their icon.
Future<void> _openTab(WidgetTester tester, IconData icon, String label) async {
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
  expect(find.text(label), findsWidgets, reason: '$label tab label');
}

/// Without the real fonts the test font gives every glyph a full em of width,
/// which overflows rows that are comfortable in the app.
Future<void> _loadFonts() async {
  const families = {
    'Bricolage': 'assets/fonts/BricolageGrotesque.ttf',
    'JetBrainsMono': 'assets/fonts/JetBrainsMono.ttf',
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key)
      ..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('every tab renders at phone size', (tester) async {
    final state = await _ready(tester);
    await tester.pumpWidget(_wrap(const HomeShell(), state));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    // Today
    expect(find.text('Today'), findsWidgets);
    expect(find.text('6h 12m'), findsOneWidget);
    expect(find.text('TOP APPS'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Verdict
    await _openTab(tester, Icons.chat_bubble_outline, 'Verdict');
    expect(find.text('4h 33m'), findsWidgets);
    expect(find.text('Share verdict'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Receipt
    await tester.tap(find.text('Share verdict'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('NO REFUNDS ON TIME'), findsOneWidget);
    expect(find.text('WASTED'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    // History
    await _openTab(tester, Icons.bar_chart, 'History');
    expect(find.text('34h 39m'), findsOneWidget);
    expect(find.text('BEST DAY'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);

    // Day view: today broken into three-hour blocks.
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.textContaining('BY APP'), findsOneWidget);
    expect(find.text('BIGGEST APP'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Settings
    await _openTab(tester, Icons.tune, 'Settings');
    expect(find.text('VOICE'), findsOneWidget);
    expect(find.text('Replay tips'), findsOneWidget);
    expect(find.text('Delete all my data'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app detail and the goal row render', (tester) async {
    final state = await _ready(tester);
    await tester.pumpWidget(_wrap(const HomeShell(), state));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    await tester.tap(find.text('TikTok'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('WHEN YOU OPEN IT · TODAY'), findsOneWidget);
    expect(find.text('OPENS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new).first);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    await _openTab(tester, Icons.tune, 'Settings');
    expect(find.text('UI/UX designer'), findsOneWidget);
    await tester.tap(find.text('Goal'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('What are you becoming?'), findsOneWidget);
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('UI/UX designer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding walks the first three steps', (tester) async {
    final state = await _ready(tester);
    await tester.pumpWidget(_wrap(const OnboardingFlow(), state));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(find.text('Your phone knows where your time went.'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(find.text('What do you want to become?'), findsOneWidget);
    await tester.tap(find.text('Writer'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(find.text('One switch to flip, and your data stays yours.'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding tag taps actually change the tag', (tester) async {
    final state = await _ready(tester);
    await tester.pumpWidget(_wrap(const OnboardingFlow(), state));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    // Demo data on this test device, so the permission step can be skipped.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Which of these are a waste?'), findsOneWidget);

    final wasted = find.text('Wasted');
    final before = wasted.evaluate().length;
    expect(before, greaterThan(0));

    await tester.ensureVisible(wasted.first);
    await tester.tap(wasted.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    // A wasted app became neutral, in the list and in the saved settings.
    expect(find.text('Wasted').evaluate().length, before - 1);
    expect(state.settings.tags, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the today row keeps the tag beside the app name', (tester) async {
    final state = await _ready(tester);
    await tester.pumpWidget(_wrap(const HomeShell(), state));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    // The tag used to get the spare width, which pushed it into the middle of
    // the row and left a visible gap after the app name.
    final name = tester.getTopLeft(find.text('TikTok').first);
    final tag = tester.getTopLeft(find.text('Wasted').first);
    expect(tag.dx, greaterThan(name.dx));
    expect(tag.dx, lessThan(200));

    final time = tester.getTopRight(find.text('2h 40m').first);
    expect(time.dx, greaterThan(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding can step back after continuing', (tester) async {
    final state = await _ready(tester);
    await tester.pumpWidget(_wrap(const OnboardingFlow(), state));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('What do you want to become?'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Your phone knows where your time went.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the verdict writer offers every provider', (tester) async {
    final state = await _ready(tester);
    await tester.pumpWidget(_wrap(const ApiKeyScreen(), state));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(find.text('Groq'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Anthropic'), findsOneWidget);
    expect(find.text('Google Gemini'), findsOneWidget);
    expect(find.text('OpenRouter'), findsOneWidget);
    expect(find.text('GROQ API KEY'), findsOneWidget);

    await tester.tap(find.text('Anthropic'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('ANTHROPIC API KEY'), findsOneWidget);
    expect(state.settings.provider.id, 'anthropic');
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings asks for exact reminder times only when needed',
      (tester) async {
    final state = await _ready(tester);
    state.exactAlarmsAllowed = false;
    await tester.pumpWidget(_wrap(const SettingsScreen(), state));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    final hint = find.textContaining('allow exact alarms');
    expect(hint, findsOneWidget);

    // Opens Android's Alarms & reminders screen; a no-op under test.
    await tester.tap(hint);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);

    state.exactAlarmsAllowed = true;
    await state.setNotifyAt(22 * 60); // notifies, so the row rebuilds
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.textContaining('allow exact alarms'), findsNothing);
  });

  testWidgets('the prompt editor shows a built-in voice per tone', (tester) async {
    final state = await _ready(tester);
    await tester.pumpWidget(_wrap(const PromptScreen(), state));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(find.text('BUILT-IN · BRUTAL ROAST'), findsOneWidget);

    await tester.tap(find.text('Gentle coach'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('BUILT-IN · GENTLE COACH'), findsOneWidget);

    await tester.enterText(
        find.byType(TextField), 'Sound like a disappointed coach.');
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Clear'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first-use tips run per page and can be replayed', (tester) async {
    final state = await _ready(tester);
    await state.completeSetup();
    await tester.pumpWidget(_wrap(const HomeShell(), state));

    // Today's first tip, after the post-frame delay.
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('TIP 1 OF 3'), findsOneWidget);
    expect(find.text('Your verdict lives here'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Your biggest time sinks'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Your biggest time sinks'), findsNothing);

    // The share tip belongs to the Verdict page, so it waits for a visit.
    await _openTab(tester, Icons.chat_bubble_outline, 'Verdict');
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Share the damage'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Share the damage'), findsNothing);

    // Settings has its own three tips.
    await _openTab(tester, Icons.tune, 'Settings');
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Pick how it talks to you'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Pick how it talks to you'), findsNothing);

    // Replay starts the Settings tour again from the top.
    await tester.tap(find.text('Replay tips'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Pick how it talks to you'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
