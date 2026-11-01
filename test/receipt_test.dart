import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hindsight/screens/receipt.dart';
import 'package:hindsight/theme.dart';

void main() {
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
