// Hindsight launch animation (the "Rewind" mark), drawn entirely with
// CustomPainter. No packages, no assets, no Lottie.
//
//   HindsightLaunch  the animation itself (plays once, tap to skip)
//   LaunchGate       plays the animation while the app boots, then fades
//                    into the real home screen
//
// The timeline mirrors the "Launch animation" board on the design canvas.
// Everything is expressed in one normalised clock `n` (0..1) so each stage is
// easy to retime: see the _endN constant below.
//
// Honours the OS "remove animations" setting: it shows the final frame and
// finishes after a short pause.

import 'dart:math' as math;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

const Color _ink = Color(0xFF0E0E0D);
const Color _cream = Color(0xFFF3EFE6);
const Color _orange = Color(0xFFFF6B3D);
const Color _lime = Color(0xFFB7F34D);
const Color _muted = Color(0xFFA8A398);
const Color _track = Color(0xFF232321);

// ---------------------------------------------------------------------------
// Timeline (normalised 0..1, same percentages as the design board)
// ---------------------------------------------------------------------------

/// Fraction of the web loop that the app plays. Everything after this was only
/// the hold/fade used for looping on the canvas.
const double _endN = 0.90;

// Curves matching the CSS cubic-beziers on the board.
const Curve _easeMove = Cubic(.65, 0, .35, 1);
const Curve _easeDraw = Cubic(.4, 0, .2, 1);
const Curve _easeSpin = Cubic(.2, .8, .2, 1);
const Curve _easePop = Cubic(.3, 1.4, .5, 1);
const Curve _easeRipple = Cubic(.2, .6, .3, 1);

/// Progress of [n] between [a] and [b], clamped to 0..1 and eased by [curve].
double _seg(double n, double a, double b, [Curve curve = Curves.linear]) {
  if (n <= a) return 0;
  if (n >= b) return 1;
  return curve.transform((n - a) / (b - a));
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

Color _withOpacity(Color c, double o) =>
    c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

// ---------------------------------------------------------------------------
// Public widgets
// ---------------------------------------------------------------------------

/// The launch animation. Plays once; calls [onFinished] when done (or when the
/// user taps to skip, if [skippable]).
class HindsightLaunch extends StatefulWidget {
  const HindsightLaunch({
    super.key,
    this.onFinished,
    this.duration = const Duration(milliseconds: 2000),
    this.skippable = true,
    this.showProgress = true,
    this.progressLabel = 'Counting your day',
    this.tagline = 'TIME, IN HINDSIGHT',
    this.background = _ink,
    this.wordmarkStyle,
    this.monoStyle,
  });

  final VoidCallback? onFinished;

  /// Length of the whole animation. 2s is the recommended cold-start length.
  final Duration duration;

  /// Tap anywhere to jump to the end.
  final bool skippable;

  /// The small "Counting your day" loading line at the bottom.
  final bool showProgress;
  final String progressLabel;
  final String tagline;
  final Color background;

  /// Pass your theme's display font (Bricolage Grotesque) and mono font
  /// (JetBrains Mono). Colours are applied for you.
  final TextStyle? wordmarkStyle;
  final TextStyle? monoStyle;

  @override
  State<HindsightLaunch> createState() => _HindsightLaunchState();
}

class _HindsightLaunchState extends State<HindsightLaunch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _initialised = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    if (MediaQuery.of(context).disableAnimations) {
      // Reduced motion: show the final frame, then move on.
      _c.value = 1;
      Future<void>.delayed(const Duration(milliseconds: 700), _finish);
    } else {
      _c.forward();
    }
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished?.call();
  }

  void _skip() {
    if (_finished || _c.isCompleted) return;
    _c.animateTo(1,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  TextStyle get _wordStyle =>
      (widget.wordmarkStyle ?? const TextStyle()).copyWith(
        fontSize: 46,
        fontWeight: FontWeight.w800,
        height: 1.1,
        color: _cream,
      );

  TextStyle _monoStyle(double size, double spacing, Color color) =>
      (widget.monoStyle ?? const TextStyle()).copyWith(
        fontSize: size,
        letterSpacing: spacing,
        color: color,
        fontWeight: FontWeight.w400,
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hindsight',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.skippable ? _skip : null,
        // Material, not a bare ColoredBox: text outside a Material ancestor
        // gets Flutter's underlined error fallback style.
        child: Material(
          color: widget.background,
          child: LayoutBuilder(
            builder: (context, box) {
              final centerY = box.maxHeight / 2;
              return AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final n = _c.value * _endN;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(painter: _LaunchPainter(n)),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: centerY + 2,
                        child: _buildWordmark(n),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: centerY + 66,
                        child: _buildTagline(n),
                      ),
                      if (widget.showProgress)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: centerY + 302,
                          child: _buildProgress(n),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // The name wipes in right to left, as if rewound.
  Widget _buildWordmark(double n) {
    final f = _seg(n, .56, .68, _easeSpin);
    if (f <= 0) return const SizedBox.shrink();
    final base = _wordStyle;
    final style =
        base.copyWith(letterSpacing: base.fontSize! * _lerp(.5, -.03, f));
    // The board blurs the word in as it wipes. A per-frame blur is a full
    // offscreen pass on a low-end GPU, and it was the heaviest thing on screen
    // during launch, so the wipe carries the entry on its own. Isolated so the
    // rest of the launch screen is not re-rasterised with it.
    return RepaintBoundary(
      child: Opacity(
        opacity: f,
        child: ClipRect(
          clipper: _RevealFromRight(f),
          child: Text('Hindsight', textAlign: TextAlign.center, style: style),
        ),
      ),
    );
  }

  Widget _buildTagline(double n) {
    final f = _seg(n, .66, .74, _easeSpin);
    if (f <= 0) return const SizedBox.shrink();
    return RepaintBoundary(
      child: Opacity(
        opacity: f,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - f)),
          child: Text(
            widget.tagline,
            textAlign: TextAlign.center,
            style: _monoStyle(12, 12 * .16, _muted),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(double n) {
    final show = _seg(n, .56, .62);
    if (show <= 0) return const SizedBox.shrink();
    final fill = _seg(n, .58, .88, _easeDraw);
    return RepaintBoundary(
      child: Opacity(
        opacity: show,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.progressLabel,
                style: _monoStyle(11, 11 * .08, _muted)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                width: 120,
                height: 3,
                child: Stack(
                  children: [
                    const Positioned.fill(child: ColoredBox(color: _track)),
                    Positioned.fill(
                      // Scaling the fill avoids a layout pass every frame.
                      child: Transform(
                        alignment: Alignment.centerLeft,
                        transform: Matrix4.diagonal3Values(fill, 1, 1),
                        child: const ColoredBox(color: _lime),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealFromRight extends CustomClipper<Rect> {
  _RevealFromRight(this.f);
  final double f;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * (1 - f), 0, size.width, size.height);

  @override
  bool shouldReclip(_RevealFromRight old) => old.f != f;
}

/// Plays [HindsightLaunch] while [ready] completes, then fades into [child].
///
/// If the animation finishes first it holds on the final frame until [ready]
/// completes, so the user never sees a half-loaded home screen. If [ready]
/// finishes first the animation still plays out (it is short), unless the
/// user taps to skip.
class LaunchGate extends StatefulWidget {
  const LaunchGate({
    super.key,
    required this.ready,
    required this.child,
    this.playAnimation = true,
    this.launchBuilder,
  });

  final Future<void> ready;
  final Widget child;

  /// Set false for warm starts or after the first launch: skips the animation.
  final bool playAnimation;

  /// Override to customise [HindsightLaunch] (fonts, duration, ...).
  final Widget Function(VoidCallback onFinished)? launchBuilder;

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  late bool _animDone = !widget.playAnimation;
  bool _readyDone = false;

  @override
  void initState() {
    super.initState();
    // A failed boot still lets the app through; handle the error in `ready`.
    widget.ready.catchError((Object _) {}).whenComplete(() {
      if (mounted) setState(() => _readyDone = true);
    });
  }

  void _onAnimFinished() {
    if (mounted) setState(() => _animDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final showChild = _animDone && _readyDone;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: showChild
          ? KeyedSubtree(key: const ValueKey('home'), child: widget.child)
          : KeyedSubtree(
              key: const ValueKey('launch'),
              child: widget.launchBuilder?.call(_onAnimFinished) ??
                  HindsightLaunch(onFinished: _onAnimFinished),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter: streaks + the Rewind mark
// ---------------------------------------------------------------------------

class _Streak {
  const _Streak(this.top, this.width, this.height, this.from, this.to,
      this.opacity, this.orange);
  final double top; // px at 844 tall
  final double width;
  final double height;
  final double from; // start x at 390 wide
  final double to; // end x at 390 wide
  final double opacity;
  final bool orange;
}

const List<_Streak> _streaks = [
  _Streak(180, 140, 2, 460, -320, .50, true),
  _Streak(262, 220, 3, 520, -340, .30, false),
  _Streak(355, 90, 2, 430, -300, .40, true),
  _Streak(489, 180, 2, 500, -330, .28, false),
  _Streak(575, 120, 3, 470, -310, .45, true),
  _Streak(660, 200, 2, 540, -340, .30, false),
];

class _LaunchPainter extends CustomPainter {
  _LaunchPainter(this.n);

  /// Normalised time, 0..1 (see _endN).
  final double n;

  @override
  void paint(Canvas canvas, Size size) {
    _paintStreaks(canvas, size);
    _paintMark(canvas, size);
  }

  // Horizontal speed lines sweeping right to left while the hand rewinds.
  void _paintStreaks(Canvas canvas, Size size) {
    final u = _seg(n, .21, .43);
    final fade = math.min(_seg(n, .21, .23), 1 - _seg(n, .43, .45));
    if (fade <= 0) return;
    for (final s in _streaks) {
      final x = _lerp(s.from / 390 * size.width, s.to / 390 * size.width, u);
      final y = s.top / 844 * size.height;
      final paint = Paint()
        ..color = _withOpacity(s.orange ? _orange : _cream, s.opacity * fade);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, s.width, s.height),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  void _paintMark(Canvas canvas, Size size) {
    // Whole-mark opacity / scale / lift.
    final opacity = _seg(n, 0, .07, Curves.easeOut);
    if (opacity <= 0) return;

    double scale;
    if (n < .07) {
      scale = _lerp(.86, .96, _seg(n, 0, .07, _easeMove));
    } else if (n < .44) {
      scale = _lerp(.96, 1.06, _seg(n, .07, .44, _easeMove));
    } else {
      scale = _lerp(1.06, .62, _seg(n, .44, .60, _easeMove));
    }
    final dy = _lerp(0, -86, _seg(n, .44, .60, _easeMove));

    if (opacity < 1) {
      canvas.saveLayer(
        null,
        Paint()
          ..color = Color.fromARGB((opacity * 255).round(), 255, 255, 255),
      );
    }
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + dy);
    canvas.scale(2.4 * scale); // 100-unit design grid -> 240 logical px
    canvas.translate(-50, -50);

    _paintTicks(canvas);
    _paintRipple(canvas);
    _paintArc(canvas);
    _paintArrowhead(canvas);
    _paintHands(canvas);
    _paintDot(canvas);

    canvas.restore();
    if (opacity < 1) canvas.restore();
  }

  // 12 tick marks that turn counter-clockwise with the hand.
  void _paintTicks(Canvas canvas) {
    double o;
    if (n < .30) {
      o = _seg(n, .21, .30) * .55;
    } else if (n < .46) {
      o = .55;
    } else {
      o = .55 * (1 - _seg(n, .46, .52));
    }
    if (o <= 0) return;
    final rot = -math.pi * _seg(n, .21, .52, Curves.easeInOut);
    final paint = Paint()
      ..color = _withOpacity(_cream, o)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(rot);
    for (var i = 0; i < 12; i++) {
      final a = -math.pi / 2 + i * math.pi / 6;
      canvas.drawLine(
        Offset(math.cos(a) * 38, math.sin(a) * 38),
        Offset(math.cos(a) * 42, math.sin(a) * 42),
        paint,
      );
    }
    canvas.restore();
  }

  // Lime ripple as the hand lands at 12.
  void _paintRipple(Canvas canvas) {
    double o;
    if (n < .45) {
      o = 0;
    } else if (n < .46) {
      o = .8 * _seg(n, .45, .46);
    } else {
      o = .8 * (1 - _seg(n, .46, .62));
    }
    if (o <= 0) return;
    final s = _lerp(1, 9, _seg(n, .46, .62, _easeRipple));
    canvas.drawCircle(
      const Offset(50, 50),
      6 * s,
      Paint()
        ..color = _withOpacity(_lime, o)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * s,
    );
  }

  // 270 degree counter-clockwise arc that draws itself from 12 o'clock.
  void _paintArc(Canvas canvas) {
    final p = _seg(n, .04, .20, _easeDraw);
    if (p <= 0) return;
    final path = Path()
      ..arcTo(
        Rect.fromCircle(center: const Offset(50, 50), radius: 26),
        -math.pi / 2,
        -3 * math.pi / 2 * p,
        true,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = _orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintArrowhead(Canvas canvas) {
    double s;
    if (n < .17) {
      s = 0;
    } else if (n < .24) {
      s = _lerp(0, 1.3, _seg(n, .17, .24, _easePop));
    } else {
      s = _lerp(1.3, 1, _seg(n, .24, .29, _easePop));
    }
    if (s <= .001) return;
    final path = Path()
      ..moveTo(76, 35)
      ..lineTo(88, 52)
      ..lineTo(64, 52)
      ..close();
    canvas.save();
    canvas.translate(76, 43.5);
    canvas.scale(s);
    canvas.translate(-76, -43.5);
    canvas.drawPath(path, Paint()..color = _orange);
    canvas.drawPath(
      path,
      Paint()
        ..color = _orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  // The hand spins one full turn backwards (kept to one so it stays readable
  // in 2s); three ghosts trail behind it.
  void _paintHands(Canvas canvas) {
    final ghostFade = n < .22
        ? 0.0
        : n < .30
            ? _seg(n, .22, .30)
            : n < .46
                ? 1.0
                : 1 - _seg(n, .46, .50);

    // Furthest ghost first so the real hand sits on top.
    const lags = [.266, .254, .242];
    const peaks = [.12, .22, .35];
    if (ghostFade > 0) {
      for (var i = 0; i < 3; i++) {
        final rot =
            -2 * math.pi * _seg(n, lags[i], lags[i] + .24, _easeSpin);
        _drawHand(canvas, rot, peaks[i] * ghostFade);
      }
    }
    final handOpacity = _seg(n, .20, .22);
    if (handOpacity > 0) {
      final rot = -2 * math.pi * _seg(n, .23, .47, _easeSpin);
      _drawHand(canvas, rot, handOpacity);
    }
  }

  void _drawHand(Canvas canvas, double rotation, double opacity) {
    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(rotation);
    canvas.drawLine(
      Offset.zero,
      const Offset(0, -16),
      Paint()
        ..color = _withOpacity(_cream, opacity)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _paintDot(Canvas canvas) {
    double s;
    if (n < .03) {
      s = 0;
    } else if (n < .09) {
      s = _lerp(0, 1.4, _seg(n, .03, .09, _easePop));
    } else {
      s = _lerp(1.4, 1, _seg(n, .09, .12, _easePop));
    }
    if (s <= .001) return;
    canvas.drawCircle(const Offset(50, 50), 5.5 * s, Paint()..color = _lime);
  }

  @override
  bool shouldRepaint(_LaunchPainter old) => old.n != n;
}
