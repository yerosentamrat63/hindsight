import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../theme.dart';

/// The open-circle arrow mark from the welcome screen.
class NudgeMark extends StatelessWidget {
  const NudgeMark({super.key, this.size = 22, this.color = C.orange});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _NudgePainter(color),
    );
  }
}

class _NudgePainter extends CustomPainter {
  _NudgePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromLTWH(
      size.width * 0.09,
      size.height * 0.09,
      size.width * 0.82,
      size.height * 0.82,
    );
    canvas.drawArc(rect, -1.05, 5.1, false, paint);
  }

  @override
  bool shouldRepaint(covariant _NudgePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The app icon, drawn from the "Icon A · Rewind" artboard: a clock hand with
/// the time running backwards. Used on the launch screen so the in-app splash
/// matches the launcher icon exactly.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _AppMarkPainter());
  }
}

class _AppMarkPainter extends CustomPainter {
  static const _strokeArc = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100);

    final arc = Paint()
      ..color = C.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeArc
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(50, 50), radius: 26),
      -math.pi / 2,
      -math.pi * 1.5,
      false,
      arc,
    );

    final arrow = Path()
      ..moveTo(76, 35)
      ..lineTo(88, 52)
      ..lineTo(64, 52)
      ..close();
    canvas.drawPath(
      arrow,
      Paint()
        ..color = C.orange
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      arrow,
      Paint()
        ..color = C.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawLine(
      const Offset(50, 50),
      const Offset(50, 34),
      Paint()
        ..color = C.ink
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(
      const Offset(50, 50),
      5.5,
      Paint()..color = C.lime,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppMarkPainter oldDelegate) => false;
}

class MonoLabel extends StatelessWidget {
  const MonoLabel(
    this.text, {
    super.key,
    this.color = C.muted,
    this.size = 11,
    this.upper = true,
    this.tracking = 0.08,
  });

  final String text;
  final Color color;
  final double size;
  final bool upper;
  final double tracking;

  @override
  Widget build(BuildContext context) {
    return Text(
      upper ? text.toUpperCase() : text,
      style: mono(size, color: color, tracking: tracking,
          height: 1.25),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: MonoLabel(text)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Filled, ink-coloured call to action.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: C.ink,
        borderRadius: BorderRadius.circular(height / 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: display(17, weight: 700, color: C.bg)),
              if (icon != null) ...[
                const SizedBox(width: 10),
                Icon(icon, size: 20, color: C.bg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 56,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(height / 2),
          side: const BorderSide(color: C.border, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: C.ink),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: display(15, weight: 600, color: C.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.color = C.surface,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: cardDecoration(color: color, radius: radius),
      child: child,
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar(this.initials, {super.key, this.size = 36, this.color = C.surface2});

  final String initials;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        initials,
        style: mono(size * 0.36, weight: 700, color: C.ink, tracking: 0),
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.tag,
    this.height = 24,
    this.fontSize = 11,
  });

  final AppTag tag;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final color = tagColor(tag);
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * 0.42),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: switch (tag) {
          AppTag.wasted => C.orangeWash,
          AppTag.productive => C.limeWash,
          AppTag.neutral => C.surface2,
        },
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: switch (tag) {
            AppTag.wasted => const Color(0x8CFF6B3D),
            AppTag.productive => const Color(0x73B7F34D),
            AppTag.neutral => C.border,
          },
          width: 1.5,
        ),
      ),
      child: Text(
        tag.upper,
        style: mono(fontSize, weight: 700, color: color, tracking: 0.06),
      ),
    );
  }
}

class AppToggle extends StatelessWidget {
  const AppToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: 52,
        height: 44,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 52,
                height: 28,
                decoration: BoxDecoration(
                  color: value ? C.lime : C.border,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 160),
              left: value ? 26 : 2,
              top: 10,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: value ? C.bg : C.muted,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wasted / neutral / productive proportional bar.
class SplitBar extends StatelessWidget {
  const SplitBar({
    super.key,
    required this.wasted,
    required this.neutral,
    required this.productive,
    this.height = 14,
  });

  final int wasted;
  final int neutral;
  final int productive;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = wasted + neutral + productive;
    if (total <= 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: C.surface2,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );
    }
    return Row(
      children: [
        for (final segment in [
          (wasted, C.orange),
          (neutral, C.neutral),
          (productive, C.lime),
        ])
          if (segment.$1 > 0)
            Expanded(
              flex: math.max(1, segment.$1),
              child: Container(
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: segment.$2,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
      ],
    );
  }
}

class SplitLegend extends StatelessWidget {
  const SplitLegend({super.key, required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _cell('● WASTED', C.orange, dur(summary.wasted)),
        _cell('● NEUTRAL', C.muted, dur(summary.neutral)),
        _cell('● PRODUCTIVE', C.lime, dur(summary.productive)),
      ],
    );
  }

  Widget _cell(String label, Color color, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: mono(11, color: color, tracking: 0.04),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value, style: display(17, weight: 700)),
        ],
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  const DashedLinePainter();


  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x8CF3EFE6)
      ..strokeWidth = 1.5;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1), Offset(x + 5, 1), paint);
      x += 10;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 24 vertical bars used on the app detail screen.
class HourlyBars extends StatelessWidget {
  const HourlyBars({super.key, required this.minutes, this.height = 100});

  final List<int> minutes;
  final double height;

  @override
  Widget build(BuildContext context) {
    final data = minutes.length == 24
        ? minutes
        : List<int>.filled(24, 0);
    final peak = data.reduce(math.max);
    final peakHour = data.indexOf(peak);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 24; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Container(
                  height: peak <= 0 ? 2 : math.max(2.0, height * data[i] / peak),
                  decoration: BoxDecoration(
                    color: i == peakHour && peak > 0
                        ? C.orange
                        : const Color(0x66FF6B3D),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(3),
                      topRight: Radius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Big single-value ring used on goal progress.
class GoalRing extends StatelessWidget {
  const GoalRing({
    super.key,
    required this.value,
    required this.total,
    required this.label,
    required this.sub,
  });

  final int value;
  final int total;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 14,
              backgroundColor: C.surface2,
              valueColor: const AlwaysStoppedAnimation(C.lime),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: display(38, weight: 800, tracking: -0.04)),
              const SizedBox(height: 2),
              Text(sub, style: mono(12, tracking: 0)),
            ],
          ),
        ],
      ),
    );
  }
}

class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 78,
    this.color = C.lime,
  });

  final List<int> values;
  final List<String> labels;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(1, math.max);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(dur(values[i]),
                            style: mono(11, color: C.inkDim, tracking: 0),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 5),
                        Container(
                          height: math.max(4.0, (height - 22) * values[i] / maxValue),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                              bottomLeft: Radius.circular(3),
                              bottomRight: Radius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final label in labels)
              Expanded(
                child: Center(
                  child: Text(label, style: mono(11, tracking: 0)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class BackHeader extends StatelessWidget {
  const BackHeader({super.key, this.title, this.trailing, this.onBack});

  final String? title;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack ?? () => Navigator.of(context).maybePop(),
          behavior: HitTestBehavior.opaque,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.arrow_back_ios_new, size: 20, color: C.ink),
          ),
        ),
        if (title != null) ...[
          const SizedBox(width: 4),
          Expanded(child: Text(title!, style: display(18, weight: 700))),
        ] else
          const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.title,
    required this.body,
    this.color = C.orange,
    this.icon,
    this.action,
  });

  final String title;
  final String body;
  final Color color;
  final IconData? icon;

  /// Optional control shown under the body, e.g. a "Refresh" button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color == C.orange ? C.orangeWash : C.limeWash,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: display(15, weight: 700, color: color, height: 1.2)),
                const SizedBox(height: 4),
                Text(body,
                    style: display(13.5,
                        weight: 500, color: C.ink, height: 1.4)),
                if (action != null) ...[
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: action!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final int current;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.timer_outlined, 'Today'),
    (Icons.chat_bubble_outline, 'Verdict'),
    (Icons.bar_chart, 'History'),
    (Icons.tune, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      decoration: const BoxDecoration(
        color: C.bg,
        border: Border(top: BorderSide(color: C.hairline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < _items.length; i++)
            _item(i),
        ],
      ),
    );
  }

  Widget _item(int index) {
    final selected = index == current;
    final item = _items[index];
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.$1,
            size: 22, color: selected ? C.bg : C.muted),
        if (selected) ...[
          const SizedBox(width: 8),
          Text(item.$2,
              style: display(14, weight: 700, color: C.bg, height: 1)),
        ],
      ],
    );

    return Material(
      color: selected ? C.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => onSelect(index),
        child: SizedBox(
          height: 48,
          width: selected ? null : 56,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 0),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
