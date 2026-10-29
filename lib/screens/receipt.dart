import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

const _paper = Color(0xFFF3EFE6);
const _paperInk = Color(0xFF1A1915);
const _paperMuted = Color(0xFF5C584C);
const _paperRule = Color(0xFF9C9684);

/// Picks a letter grade from wasted minutes against the daily limit.
String gradeFor(int wastedWeek, int limitMinutes) {
  final limit = (limitMinutes * 7).clamp(1, 1 << 30);
  final ratio = wastedWeek / limit;
  if (ratio < 0.35) return 'A';
  if (ratio < 0.55) return 'A−';
  if (ratio < 0.75) return 'B+';
  if (ratio < 0.95) return 'B';
  if (ratio < 1.05) return 'C+';
  if (ratio < 1.2) return 'C';
  if (ratio < 1.35) return 'D+';
  if (ratio < 1.6) return 'D';
  return 'F';
}

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const ReceiptScreen());

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _sharing = false;

  Future<void> _share(Widget paper) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await renderReceiptPng(context, paper);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/hindsight-receipt-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'My Hindsight week',
        text: 'My week, in hindsight.',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not render the receipt. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final week = state.week;
    final wasted = state.wastedWeek;
    final reclaimed = state.reclaimedWeek;
    final delta = state.weekDelta;
    final grade = gradeFor(wasted, state.limitMinutes);
    final days = week.map((d) => d.date).toList();

    final topApps = <(AppMeta, int)>[];
    final totals = <String, int>{};
    for (final id in state.usage.apps.keys) {
      if (state.effectiveTags[id] != AppTag.wasted) continue;
      totals[id] = state.weekMinutesOf(id);
    }
    final ids = totals.keys.toList()
      ..sort((a, b) => totals[b]!.compareTo(totals[a]!));
    for (final id in ids.take(4)) {
      final meta = state.usage.apps[id];
      if (meta == null || totals[id] == 0) continue;
      topApps.add((meta, totals[id]!));
    }

    final paper = _Paper(
      weekLabel: weekLabelOf(days),
      wasted: wasted,
      reclaimed: reclaimed,
      grade: grade,
      delta: delta,
      goal: state.settings.goal,
      topApps: topApps,
    );

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(27, 8, 27, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          behavior: HitTestBehavior.opaque,
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(Icons.close, size: 24, color: C.ink),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('Weekly receipt',
                            style: display(18, weight: 700, tracking: -0.01)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    paper,
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(27, 4, 27, 20),
              child: PrimaryButton(
                label: _sharing ? 'Rendering receipt…' : 'Share receipt',
                icon: Icons.ios_share,
                onPressed: _sharing ? null : () => _share(paper),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws [content] offscreen at a fixed 390pt width — full height, ignoring
/// the screen and any scrolling — and returns it as a PNG. The offscreen copy
/// lives in the overlay, far to the left, so it never flashes on screen.
Future<Uint8List> renderReceiptPng(
  BuildContext context,
  Widget content, {
  double width = 390,
  double pixelRatio = 3,
}) async {
  final boundaryKey = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -2000,
      top: 0,
      child: RepaintBoundary(
        key: boundaryKey,
        child: Material(
          color: C.bg,
          child: SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(27, 28, 27, 30),
              child: content,
            ),
          ),
        ),
      ),
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('receipt not mounted');
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('empty image');
    return data.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}

String weekLabelOf(List<DateTime> days) {
  if (days.isEmpty) return '';
  final first = days.first;
  final week = ((first.difference(DateTime(first.year, 1, 1)).inDays) ~/ 7) + 1;
  final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  final last = days.last;
  final span = first.month == last.month
      ? '${first.day}–${last.day} ${months[first.month - 1]}'
      : '${first.day} ${months[first.month - 1]}–${last.day} ${months[last.month - 1]}';
  return 'WEEK $week · $span ${last.year}';
}

class _Paper extends StatelessWidget {
  const _Paper({
    required this.weekLabel,
    required this.wasted,
    required this.reclaimed,
    required this.grade,
    required this.delta,
    required this.goal,
    required this.topApps,
  });

  final String weekLabel;
  final int wasted;
  final int reclaimed;
  final String grade;
  final int delta;
  final String goal;
  final List<(AppMeta, int)> topApps;

  @override
  Widget build(BuildContext context) {
    final compare = delta == 0
        ? 'Holding steady against last week.'
        : delta < 0
            ? '${dur(delta.abs())} less than last week.'
            : '${dur(delta.abs())} more than last week.';

    return Column(
      children: [
        Container(
          color: _paper,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
          child: Column(
            children: [
              const Column(
                children: [
                  Text('HINDSIGHT',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4.5,
                        color: _paperInk,
                      )),
                  SizedBox(height: 4),
                  Text('WEEKLY RECEIPT',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                        letterSpacing: 1.3,
                        color: _paperMuted,
                      )),
                ],
              ),
              const SizedBox(height: 3),
              Text(weekLabel,
                  style: mono(11, color: _paperMuted, tracking: 0.06)),
              const SizedBox(height: 14),
              const _Rule(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('TIME SPENT ON',
                    style: mono(11, color: _paperMuted, tracking: 0.1)),
              ),
              const SizedBox(height: 8),
              if (topApps.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Nothing worth billing this week.',
                      style: display(14, weight: 500, color: _paperInk)),
                ),
              for (final row in topApps) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(row.$1.name,
                        style: display(14, weight: 500, color: _paperInk)),
                    const Expanded(child: _DottedLine()),
                    Text(dur(row.$2),
                        style: display(14, weight: 700, color: _paperInk)),
                  ],
                ),
                if (row != topApps.last) const SizedBox(height: 8),
              ],
              const SizedBox(height: 14),
              const _Rule(),
              const SizedBox(height: 12),
              _PaperTotal(label: 'WASTED', value: durLong(wasted), big: true),
              const SizedBox(height: 6),
              _PaperTotal(label: 'RECLAIMED', value: durLong(reclaimed)),
              const SizedBox(height: 14),
              const _Rule(),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text('GRADE',
                          style: mono(11, color: _paperMuted, tracking: 0.1)),
                      Text(grade,
                          style: display(68,
                              weight: 800,
                              tracking: -0.05,
                              height: 0.9,
                              color: _paperInk)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '$compare Almost ${dur(wasted ~/ 7)} a day, and $goal is still waiting.',
                      style: display(12, weight: 500, color: _paperInk, height: 1.45),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 36,
                width: double.infinity,
                child: CustomPaint(painter: _BarcodePainter()),
              ),
              const SizedBox(height: 8),
              Text('NO REFUNDS ON TIME',
                  style: mono(11, color: _paperMuted, tracking: 0.14)),
            ],
          ),
        ),
        SizedBox(
          height: 10,
          width: double.infinity,
          child: CustomPaint(painter: _TearPainter()),
        ),
      ],
    );
  }
}

class _PaperTotal extends StatelessWidget {
  const _PaperTotal({
    required this.label,
    required this.value,
    this.big = false,
  });

  final String label;
  final String value;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: big ? 16 : 14,
      fontWeight: big ? FontWeight.w700 : FontWeight.w400,
      color: _paperInk,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1.5,
      width: double.infinity,
      child: CustomPaint(painter: _RulePainter()),
    );
  }
}

class _RulePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _paperRule
      ..strokeWidth = 1.5;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0.5), Offset((x + 6).clamp(0, size.width), 0.5), paint);
      x += 12;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DottedLine extends StatelessWidget {
  const _DottedLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: SizedBox(
        height: 2,
        child: CustomPaint(painter: _DotPainter()),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _paperRule
      ..strokeWidth = 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1), Offset(x + 1.5, 1), paint);
      x += 5;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _paperInk;
    const pattern = [1.0, 2.0, 1.0, 0.6, 1.4, 3.0, 1.0, 0.8, 2.0, 1.2];
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final w = pattern[i % pattern.length] * 1.6;
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += w + 2.4;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TearPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, 0)..lineTo(size.width, 0);
    final step = 6.0;
    var x = size.width;
    var down = true;
    while (x > 0) {
      x -= step;
      path.lineTo(x, down ? size.height : 0);
      down = !down;
    }
    path
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = _paper);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
