import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hindsight/screens/receipt.dart';
import 'package:hindsight/theme.dart';
import 'package:hindsight/widgets/hindsight_launch.dart';

void main() {
  testWidgets('the launch animation plays once and hands over', (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: HindsightLaunch(
        duration: const Duration(milliseconds: 600),
        onFinished: () => done++,
      ),
    ));

    expect(done, 0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(done, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the launch animation skips it', (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: HindsightLaunch(
        duration: const Duration(seconds: 5),
        onFinished: () => done++,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(HindsightLaunch));
    await tester.pumpAndSettle();
    expect(done, 1);
  });

  testWidgets('reduced motion shows the final frame then moves on',
      (tester) async {
    var done = 0;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: AppTheme.build(),
        home: HindsightLaunch(onFinished: () => done++),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 800));
    expect(done, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the gate holds the last frame until the app is ready',
      (tester) async {
    final ready = Completer<void>();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: LaunchGate(
        ready: ready.future,
        launchBuilder: (onFinished) => HindsightLaunch(
          duration: const Duration(milliseconds: 300),
          onFinished: onFinished,
        ),
        child: const Scaffold(body: Text('home')),
      ),
    ));

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('home'), findsNothing, reason: 'app still booting');

    ready.complete();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the receipt is captured as a 3x PNG, complete offscreen',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: Builder(builder: (ctx) {
        context = ctx;
        return const Scaffold(body: SizedBox.shrink());
      }),
    ));

    final future = renderReceiptPng(
      context,
      const SizedBox(height: 900, child: ColoredBox(color: Colors.white)),
    );
    await tester.pump();
    await tester.pump();
    final bytes = await tester.runAsync(() => future);

    // PNG magic, then decode to check the 3x width and full height.
    expect(bytes, isNotNull);
    expect(bytes!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final image = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      return (await codec.getNextFrame()).image;
    });
    expect(image!.width, 390 * 3);
    expect(image.height, greaterThan(900 * 3));
    expect(find.text('Hindsight'), findsNothing,
        reason: 'nothing left on screen');
    expect(tester.takeException(), isNull);
  });
}
