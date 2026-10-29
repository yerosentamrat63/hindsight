import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Where each tip points. The keys are attached to the real widgets, so a tip
/// follows the layout instead of using the design's hard-coded pixels.
class CoachKeys {
  static final verdictCard = GlobalKey();
  static final topApps = GlobalKey();
  static final share = GlobalKey();
  static final voice = GlobalKey();
  static final retag = GlobalKey();
  static final writer = GlobalKey();
}

/// First-use tips. `page` matches the bottom-nav index the tip belongs to.
enum CoachTip {
  verdictCard(
    id: 'today.verdict',
    page: 0,
    step: 1,
    count: 3,
    section: 'Tip',
    title: 'Your verdict lives here',
    body:
        "Every evening Hindsight writes today's verdict. Tap this card to read it.",
  ),
  topApps(
    id: 'today.apps',
    page: 0,
    step: 2,
    count: 3,
    section: 'Tip',
    title: 'Your biggest time sinks',
    body:
        "Today's top apps, tagged wasted, neutral or productive. Tap one for its details.",
  ),
  share(
    id: 'verdict.share',
    page: 1,
    step: 3,
    count: 3,
    section: 'Tip',
    title: 'Share the damage',
    body:
        'Turn any verdict into a card and send it to a friend. Roasts travel well.',
  ),
  voice(
    id: 'settings.voice',
    page: 3,
    step: 1,
    count: 3,
    section: 'Settings tip',
    title: 'Pick how it talks to you',
    body:
        'Gentle coach, Brutal roast or Future you. Same numbers, different voice. Switch whenever you like.',
  ),
  retag(
    id: 'settings.retag',
    page: 3,
    step: 2,
    count: 3,
    section: 'Settings tip',
    title: 'Disagree with a tag?',
    body:
        'Mark any app as wasted, neutral or productive here. Every verdict and total updates to match.',
  ),
  writer(
    id: 'settings.writer',
    page: 3,
    step: 3,
    count: 3,
    section: 'Settings tip',
    title: 'Give it a sharper tongue',
    body:
        'With a Groq key the verdicts are written by AI. Without one Hindsight still judges you, just offline.',
  );

  const CoachTip({
    required this.id,
    required this.page,
    required this.step,
    required this.count,
    required this.section,
    required this.title,
    required this.body,
  });

  final String id;
  final int page;
  final int step;
  final int count;
  final String section;
  final String title;
  final String body;

  bool get isLast => step == count;

  String get label => '$section $step of $count';

  GlobalKey get target => switch (this) {
        CoachTip.verdictCard => CoachKeys.verdictCard,
        CoachTip.topApps => CoachKeys.topApps,
        CoachTip.share => CoachKeys.share,
        CoachTip.voice => CoachKeys.voice,
        CoachTip.retag => CoachKeys.retag,
        CoachTip.writer => CoachKeys.writer,
      };
}

/// The cream card from the design, with a live spotlight behind it.
class CoachOverlay extends StatelessWidget {
  const CoachOverlay({
    super.key,
    required this.tip,
    required this.onNext,
    required this.onSkip,
  });

  final CoachTip tip;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  static const _cardInk = C.bg;
  static const _cardBody = Color(0xFF2A2924);
  static const _cardMuted = Color(0xFF5C584C);
  static const _dotIdle = Color(0xFFB4AE9C);

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final target = _rectOf(tip) ??
        Rect.fromLTWH(24, screen.height * 0.32, screen.width - 48, 140);
    final rect = _clampToScreen(target, screen);
    final above = rect.top > screen.height * 0.42;
    final radius = tip == CoachTip.share ? 34.0 : 22.0;
    final cardGap = 22.0;
    final arrowX = rect.center.dx.clamp(46.0, screen.width - 46.0);
    final cardBottom = screen.height - rect.top + cardGap;
    final cardTop = rect.bottom + cardGap;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              // Absorb taps so the page behind stays put while a tip is up.
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: CustomPaint(
                painter: _SpotlightPainter(rect: rect, radius: radius),
              ),
            ),
          ),
          if (above)
            Positioned(
              left: 24,
              right: 24,
              bottom: cardBottom,
              child: _card(context),
            )
          else
            Positioned(
              left: 24,
              right: 24,
              top: cardTop,
              child: _card(context),
            ),
          Positioned(
            left: arrowX - 9,
            bottom: above ? cardBottom - 9 : null,
            top: above ? null : cardTop - 9,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: C.ink,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      decoration: BoxDecoration(
        color: C.ink,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tip.label.toUpperCase(),
                  style: mono(11, color: _cardMuted, tracking: 0.08),
                ),
              ),
              Row(
                children: [
                  for (var i = 1; i <= tip.count; i++) ...[
                    if (i > 1) const SizedBox(width: 5),
                    Container(
                      width: i == tip.step ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == tip.step ? _cardInk : _dotIdle,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tip.title,
            style: display(22,
                weight: 800, tracking: -0.02, color: _cardInk, height: 1.1),
          ),
          const SizedBox(height: 6),
          Text(
            tip.body,
            style: display(15, weight: 400, color: _cardBody, height: 1.4),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onSkip,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    tip.isLast ? 'Replay tips any time in Settings' : 'Skip',
                    style: display(tip.isLast ? 12.5 : 15,
                        weight: 600, color: _cardMuted, height: 1.3),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onNext,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: C.bg,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tip.isLast ? 'Got it' : 'Next',
                          style: display(15, weight: 700, color: C.ink)),
                      const SizedBox(width: 8),
                      Icon(
                        tip.isLast
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        size: 16,
                        color: C.ink,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Rect? _rectOf(CoachTip tip) {
    final context = tip.target.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  static Rect _clampToScreen(Rect rect, Size screen) {
    const edge = 6.0;
    final left = rect.left
        .clamp(edge, math.max(edge, screen.width - edge))
        .toDouble();
    final right = rect.right
        .clamp(left + 1, screen.width - edge)
        .toDouble();
    final top = rect.top
        .clamp(edge, math.max(edge, screen.height - edge))
        .toDouble();
    final bottom = rect.bottom
        .clamp(top + 1, screen.height - edge)
        .toDouble();
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.rect, required this.radius});

  final Rect rect;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      rect.inflate(2),
      Radius.circular(radius),
    );
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(hole)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = const Color(0xCC060605));
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = C.ink,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.radius != radius;
}
