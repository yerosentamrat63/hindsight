// hindsight_widgets.dart
//
// The five Hindsight home-screen widgets as plain Flutter widgets, matching the
// boards on the design canvas. Drop at lib/widgets/hindsight_widgets.dart.
//
// Android home-screen widgets cannot run Dart, so the approach is:
//   1. Build each widget here (pixel-faithful, same fonts and layout as the app).
//   2. Render it to a PNG with home_widget's renderFlutterWidget.
//   3. The native provider only shows that PNG in an ImageView and handles taps.
//
// Needs:  home_widget: ^0.6.0   (pubspec.yaml)
//         fonts declared in pubspec under the family names below.
//
// Widget cards (logical px, same as the boards):
//   ring    170 x 170   (2x2)
//   verdict 170 x 170   (2x2)
//   today   360 x 170   (4x2)
//   limit   360 x  84   (4x1)
//   week    360 x 360   (4x4)

import 'dart:math' as math;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Config: change these to match your project
// ---------------------------------------------------------------------------

/// Family names exactly as declared in pubspec.yaml.
const String kDisplayFont = 'Bricolage Grotesque';
const String kMonoFont = 'JetBrains Mono';

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

const Color _ink = Color(0xFF0E0E0D);
const Color _cream = Color(0xFFF3EFE6);
const Color _orange = Color(0xFFFF6B3D);
const Color _lime = Color(0xFFB7F34D);
const Color _muted = Color(0xFFA8A398);
const Color _grey = Color(0xFF7D7A70);
const Color _track = Color(0xFF232321);
const Color _panel = Color(0xFF181816);
const Color _line = Color(0xFF34332F);
const Color _hairline = Color(0x1AF3EFE6); // cream at 10%

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

enum WidgetTag { wasted, neutral, productive }

class AppUsage {
  const AppUsage(this.name, this.abbr, this.minutes, this.tag);
  final String name;
  final String abbr; // two letters shown in the app tile
  final int minutes;
  final WidgetTag tag;
}

class WidgetData {
  const WidgetData({
    required this.wastedMin,
    required this.neutralMin,
    required this.productiveMin,
    required this.limitMin,
    required this.deltaVsYesterdayMin,
    required this.topApps,
    required this.verdictLine,
    required this.toneLabel,
    required this.weekWastedMin,
    required this.weekRange,
    required this.weekDeltaMin,
    required this.weekVerdict,
    required this.weekDayLabels,
    required this.weekDayWastedMin,
    required this.todayIndex,
  });

  final int wastedMin;
  final int neutralMin;
  final int productiveMin;
  final int limitMin;
  final int deltaVsYesterdayMin; // positive = more than yesterday
  final List<AppUsage> topApps; // widget shows the first 3
  final String verdictLine;
  final String toneLabel;

  final int weekWastedMin;
  final String weekRange; // e.g. '19–25 OCT'
  final int weekDeltaMin; // positive = more than last week
  final String weekVerdict;
  final List<String> weekDayLabels; // 7 entries
  final List<int> weekDayWastedMin; // 7 entries
  final int todayIndex;

  int get screenTimeMin => wastedMin + neutralMin + productiveMin;

  /// Matches the numbers on the design boards.
  static const WidgetData sample = WidgetData(
    wastedMin: 273,
    neutralMin: 52,
    productiveMin: 47,
    limitMin: 240,
    deltaVsYesterdayMin: 32,
    topApps: [
      AppUsage('TikTok', 'Tk', 160, WidgetTag.wasted),
      AppUsage('Instagram', 'Ig', 65, WidgetTag.wasted),
      AppUsage('Telegram', 'Tg', 52, WidgetTag.neutral),
    ],
    verdictLine: '4h 33m gone. Your portfolio noticed.',
    toneLabel: 'Brutal roast',
    weekWastedMin: 2079,
    weekRange: '19–25 OCT',
    weekDeltaMin: -213,
    weekVerdict: 'Almost a work week gone. The portfolio is still empty.',
    weekDayLabels: ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    weekDayWastedMin: [306, 264, 348, 234, 276, 378, 273],
    todayIndex: 6,
  );
}

// ---------------------------------------------------------------------------
// Formatting + text styles
// ---------------------------------------------------------------------------

String fmtMin(int m) {
  final h = m ~/ 60;
  final r = m % 60;
  if (h == 0) return '${r}m';
  return '${h}h ${r.toString().padLeft(2, '0')}m';
}

String fmtDelta(int m) => '${m >= 0 ? '+' : '-'}${fmtMin(m.abs())}';

TextStyle _display(
  double size, {
  FontWeight weight = FontWeight.w800,
  double ls = -.03, // in em
  double height = 1.1,
  Color color = _cream,
}) =>
    TextStyle(
      fontFamily: kDisplayFont,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: size * ls,
      height: height,
      color: color,
      fontVariations: [
        FontVariation('wght', weight.value.toDouble()),
        FontVariation('opsz', size.clamp(12.0, 96.0)),
      ],
    );

TextStyle _mono(
  double size, {
  Color color = _muted,
  FontWeight weight = FontWeight.w400,
  double ls = 0, // in em
}) =>
    TextStyle(
      fontFamily: kMonoFont,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: size * ls,
      color: color,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
    );

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

/// The rounded dark card every widget sits in.
class _Card extends StatelessWidget {
  const _Card({
    required this.width,
    required this.height,
    required this.padding,
    required this.child,
  });
  final double width;
  final double height;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: WidgetBox.sizeOf(context)?.width ?? width,
        height: WidgetBox.sizeOf(context)?.height ?? height,
        padding: padding,
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _hairline, width: 1),
        ),
        child: child,
      );
}

/// Small circular cream button with an arrow (the "open" affordance).
class _ArrowButton extends StatelessWidget {
  const _ArrowButton(this.size);
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: _cream, shape: BoxShape.circle),
        child: Icon(Icons.arrow_forward_rounded, size: size * .5, color: _ink),
      );
}

/// The Rewind logo (icon concept A). Draws in a 78-unit box cropped tightly
/// around the artwork so it can sit inline next to text.
class RewindMark extends StatelessWidget {
  const RewindMark({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _MarkPainter()));
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 78, size.height / 78);
    canvas.translate(-16, -11);

    final arc = Path()
      ..arcTo(
        Rect.fromCircle(center: const Offset(50, 50), radius: 26),
        -math.pi / 2,
        -3 * math.pi / 2,
        true,
      );
    canvas.drawPath(
      arc,
      Paint()
        ..color = _orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );

    final head = Path()
      ..moveTo(76, 35)
      ..lineTo(88, 52)
      ..lineTo(64, 52)
      ..close();
    canvas.drawPath(head, Paint()..color = _orange);
    canvas.drawPath(
      head,
      Paint()
        ..color = _orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawLine(
      const Offset(50, 50),
      const Offset(50, 34),
      Paint()
        ..color = _cream
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(50, 50), 5.5, Paint()..color = _lime);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 2, width: double.infinity, child: CustomPaint(painter: _DashPainter()));
}

class _DashPainter extends CustomPainter {
  const _DashPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x80F3EFE6)
      ..strokeWidth = 1.5;
    const dash = 4.0, gap = 4.0;
    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 1), Offset(math.min(x + dash, size.width), 1), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

Color _tagColor(WidgetTag t) => switch (t) {
      WidgetTag.wasted => _orange,
      WidgetTag.neutral => _muted,
      WidgetTag.productive => _lime,
    };

// ---------------------------------------------------------------------------
// 1. Ring, 2x2
// ---------------------------------------------------------------------------

class RingWidget extends StatelessWidget {
  const RingWidget(this.data, {super.key});
  final WidgetData data;

  static const Size size = Size(170, 170);

  @override
  Widget build(BuildContext context) {
    final progress = data.limitMin == 0 ? 1.0 : (data.wastedMin / data.limitMin).clamp(0.0, 1.0);
    final over = data.wastedMin - data.limitMin;
    final isOver = over > 0;

    return _Card(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('WASTED TODAY', style: _mono(10, ls: .1)),
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(size: const Size(96, 96), painter: _RingPainter(progress)),
                Text(fmtMin(data.wastedMin), style: _display(23, ls: -.04, height: 1)),
              ],
            ),
          ),
          Text(
            isOver ? '${fmtMin(over)} over limit' : '${fmtMin(-over)} left',
            style: _mono(11, color: isOver ? _orange : _lime, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8; // radius 40 in a 96 box
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = _orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
    final a = -math.pi / 2 + sweep;
    canvas.drawCircle(
      Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a)),
      5,
      Paint()..color = _cream,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ---------------------------------------------------------------------------
// 2. Verdict, 2x2
// ---------------------------------------------------------------------------

class VerdictWidget extends StatelessWidget {
  const VerdictWidget(this.data, {super.key});
  final WidgetData data;

  static const Size size = Size(170, 170);

  @override
  Widget build(BuildContext context) {
    return _Card(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              const RewindMark(size: 20),
              const SizedBox(width: 6),
              Text('VERDICT', style: _mono(10, ls: .1)),
            ],
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                data.verdictLine,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: _display(23, ls: -.03, height: 1.1),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(data.toneLabel, style: _mono(10)),
              const _ArrowButton(28),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Today, 4x2
// ---------------------------------------------------------------------------

class TodayWidget extends StatelessWidget {
  const TodayWidget(this.data, {super.key});
  final WidgetData data;

  static const Size size = Size(360, 170);

  @override
  Widget build(BuildContext context) {
    final up = data.deltaVsYesterdayMin > 0;
    final apps = data.topApps.take(3).toList();

    return _Card(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('SCREEN TIME', style: _mono(10, ls: .1)),
                      Text(fmtMin(data.screenTimeMin), style: _display(44, ls: -.045, height: .95)),
                      Text(
                        '${fmtDelta(data.deltaVsYesterdayMin)} vs yesterday',
                        style: _mono(11, color: up ? _orange : _lime),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [for (final a in apps) _AppRow(a)],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SplitBar(data: data),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Wasted ${fmtMin(data.wastedMin)}', style: _mono(10)),
              Text('Neutral ${fmtMin(data.neutralMin)}', style: _mono(10)),
              Text('Productive ${fmtMin(data.productiveMin)}', style: _mono(10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow(this.app);
  final AppUsage app;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 32,
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _track, borderRadius: BorderRadius.circular(8)),
              child: Text(app.abbr, style: _mono(10, color: _cream, weight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                app.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _display(14, weight: FontWeight.w600, ls: 0, height: 1.2),
              ),
            ),
            Text(fmtMin(app.minutes), style: _mono(12, color: _tagColor(app.tag))),
          ],
        ),
      );
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.data});
  final WidgetData data;

  @override
  Widget build(BuildContext context) {
    Widget seg(int m, Color c) => Expanded(
          flex: math.max(1, m),
          child: Container(
            height: 8,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
          ),
        );
    return Row(
      children: [
        seg(data.wastedMin, _orange),
        const SizedBox(width: 3),
        seg(data.neutralMin, _grey),
        const SizedBox(width: 3),
        seg(data.productiveMin, _lime),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Limit bar, 4x1
// ---------------------------------------------------------------------------

class LimitWidget extends StatelessWidget {
  const LimitWidget(this.data, {super.key});
  final WidgetData data;

  static const Size size = Size(360, 84);

  @override
  Widget build(BuildContext context) {
    final over = data.wastedMin - data.limitMin;
    final isOver = over > 0;
    final scale = math.max(data.wastedMin, data.limitMin).toDouble();
    final fill = scale == 0 ? 0.0 : data.wastedMin / scale;
    final tick = scale == 0 ? 1.0 : data.limitMin / scale;
    final color = isOver ? _orange : _lime;

    return _Card(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text.rich(
                TextSpan(
                  text: '${fmtMin(data.wastedMin)} ',
                  style: _display(20, ls: -.03, height: 1.1),
                  children: [
                    TextSpan(
                      text: 'wasted of ${fmtMin(data.limitMin)} limit',
                      style: _mono(11, weight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Text(
                isOver ? '+${fmtMin(over)} over' : '${fmtMin(-over)} left',
                style: _mono(11, color: color, weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 12,
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(color: _track, borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: box.maxWidth * fill,
                    child: Container(
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  Positioned(
                    left: box.maxWidth * tick - 1.5,
                    top: -3,
                    width: 3,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(color: _cream, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Week, 4x4
// ---------------------------------------------------------------------------

class WeekWidget extends StatelessWidget {
  const WeekWidget(this.data, {super.key});
  final WidgetData data;

  static const Size size = Size(360, 360);
  static const double _chartH = 110;
  static const double _maxBar = 90;

  @override
  Widget build(BuildContext context) {
    final days = data.weekDayWastedMin;
    final peak = math.max(days.fold<int>(0, math.max), data.limitMin);
    final k = peak == 0 ? 0.0 : _maxBar / peak;
    final less = data.weekDeltaMin <= 0;

    return _Card(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const RewindMark(size: 24),
                  const SizedBox(width: 8),
                  Text('Hindsight', style: _display(15, ls: -.01, height: 1.2)),
                ],
              ),
              Text(data.weekRange.toUpperCase(), style: _mono(10, ls: .08)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WASTED THIS WEEK', style: _mono(10, ls: .08)),
                  const SizedBox(height: 2),
                  Text(
                    fmtMin(data.weekWastedMin),
                    style: _display(40, ls: -.045, height: .95, color: _orange),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${fmtMin(data.weekDeltaMin.abs())} ${less ? 'less' : 'more'}',
                  style: _mono(11, color: less ? _lime : _orange, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _chartH,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < days.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: days[i] * k,
                          decoration: BoxDecoration(
                            color: days[i] <= data.limitMin ? _lime : _orange,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              topRight: Radius.circular(6),
                              bottomLeft: Radius.circular(2),
                              bottomRight: Radius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Positioned(left: 0, right: 0, bottom: data.limitMin * k, child: const _DashedLine()),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < data.weekDayLabels.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.weekDayLabels[i],
                    textAlign: TextAlign.center,
                    style: _mono(
                      10,
                      color: i == data.todayIndex ? _cream : _muted,
                      weight: i == data.todayIndex ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _line, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    data.weekVerdict,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _display(14, weight: FontWeight.w600, ls: 0, height: 1.2),
                  ),
                ),
                const SizedBox(width: 12),
                const _ArrowButton(40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rendering to the home screen
// ---------------------------------------------------------------------------

/// Gives an off-screen widget the context it needs to lay out text.
Widget widgetHost(Widget w) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: DefaultTextStyle(style: const TextStyle(color: _cream), child: w),
      ),
    );

// ---------------------------------------------------------------------------
// In-app preview (optional): see all five on one scrollable screen.
// ---------------------------------------------------------------------------

class WidgetGallery extends StatelessWidget {
  const WidgetGallery({super.key, this.data = WidgetData.sample});
  final WidgetData data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1A),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(spacing: 16, runSpacing: 16, children: [RingWidget(data), VerdictWidget(data)]),
            const SizedBox(height: 16),
            TodayWidget(data),
            const SizedBox(height: 16),
            LimitWidget(data),
            const SizedBox(height: 16),
            WeekWidget(data),
          ],
        ),
      ),
    );
  }
}
// ---------------------------------------------------------------------------
// Sizing + the app's snapshot
// ---------------------------------------------------------------------------

/// The launcher decides how big a cell is; the boards assume a fixed artboard.
/// Wrapping a widget in [WidgetBox] makes the card take the cell's box, so the
/// flexible parts inside it absorb the difference instead of letterboxing.
class WidgetBox extends InheritedWidget {
  const WidgetBox({super.key, required this.size, required super.child});

  final Size size;

  static Size? sizeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WidgetBox>()?.size;

  @override
  bool updateShouldNotify(WidgetBox oldWidget) => oldWidget.size != size;
}

/// Builds the widget model from `AppState.widgetSnapshot()`.
WidgetData widgetDataFromSnapshot(Map<String, Object?> snapshot) {
  List<Map<String, Object?>> objects(String key) => [
        for (final entry in (snapshot[key] as List? ?? const []))
          if (entry is Map) entry.cast<String, Object?>(),
      ];

  int minutes(Object? value) => (value as num?)?.toInt() ?? 0;

  final apps = objects('apps');
  final days = objects('days');
  final line = (snapshot['verdict'] ?? '').toString().trim();
  final today = days.indexWhere((day) => day['today'] == true);

  return WidgetData(
    wastedMin: minutes(snapshot['wastedToday']),
    neutralMin: minutes(snapshot['neutralToday']),
    productiveMin: minutes(snapshot['productiveToday']),
    limitMin: minutes(snapshot['limit']),
    deltaVsYesterdayMin: minutes(snapshot['totalDeltaYesterday']),
    topApps: [
      for (final app in apps)
        AppUsage(
          (app['name'] ?? '').toString(),
          (app['mono'] ?? '').toString(),
          minutes(app['minutes']),
          switch ((app['tag'] ?? '').toString()) {
            'wasted' => WidgetTag.wasted,
            'productive' => WidgetTag.productive,
            _ => WidgetTag.neutral,
          },
        ),
    ],
    verdictLine: line.isEmpty ? 'Your verdict is being written.' : line,
    toneLabel: (snapshot['tone'] ?? 'Brutal roast').toString(),
    weekWastedMin: minutes(snapshot['wastedWeek']),
    weekRange: (snapshot['weekSpan'] ?? '').toString(),
    weekDeltaMin: minutes(snapshot['weekDelta']),
    weekVerdict: line.isEmpty ? "Open Hindsight for today's verdict." : line,
    weekDayLabels: [for (final day in days) (day['label'] ?? '').toString()],
    weekDayWastedMin: [for (final day in days) minutes(day['wasted'])],
    todayIndex: today < 0 ? (days.isEmpty ? 0 : days.length - 1) : today,
  );
}
