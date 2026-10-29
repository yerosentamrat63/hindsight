import 'package:flutter/material.dart';

/// Palette lifted straight from the design.
abstract class C {
  static const bg = Color(0xFF0E0E0D);
  static const surface = Color(0xFF181816);
  static const surface2 = Color(0xFF232321);
  static const border = Color(0xFF34332F);
  static const hairline = Color(0xFF2A2A27);
  static const ink = Color(0xFFF3EFE6);
  static const inkDim = Color(0xFFD6D2C7);
  static const muted = Color(0xFFA8A398);
  static const faint = Color(0xFF6B685F);
  static const neutral = Color(0xFF7D7A70);
  static const orange = Color(0xFFFF6B3D);
  static const lime = Color(0xFFB7F34D);
  static const orangeWash = Color(0x24FF6B3D);
  static const limeWash = Color(0x1FB7F34D);
}

FontWeight _fw(double w) {
  final t = ((w - 100) / 800).clamp(0.0, 1.0);
  return FontWeight.lerp(FontWeight.w100, FontWeight.w900, t)!;
}

/// Display type: Bricolage Grotesque, tight tracking, heavy weights.
TextStyle display(
  double size, {
  double weight = 700,
  Color color = C.ink,
  double height = 1.05,
  double tracking = -0.03,
}) {
  return TextStyle(
    fontFamily: 'Bricolage',
    fontSize: size,
    color: color,
    height: height,
    letterSpacing: size * tracking,
    fontWeight: _fw(weight),
    fontVariations: [FontVariation('wght', weight)],
  );
}

/// Mono type: JetBrains Mono, used for labels, metrics and metadata.
TextStyle mono(
  double size, {
  double weight = 400,
  Color color = C.muted,
  double height = 1.3,
  double tracking = 0.02,
}) {
  return TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: size,
    color: color,
    height: height,
    letterSpacing: size * tracking,
    fontWeight: _fw(weight),
    fontVariations: [FontVariation('wght', weight)],
  );
}

const kScreenPad = 24.0;

BoxDecoration cardDecoration({
  Color color = C.surface,
  Color border = C.border,
  double radius = 20,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border, width: 1.5),
  );
}

class AppTheme {
  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: C.bg,
      canvasColor: C.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: C.ink,
        secondary: C.orange,
        surface: C.surface,
        onSurface: C.ink,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: C.ink,
        displayColor: C.ink,
        fontFamily: 'Bricolage',
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
    );
  }
}
