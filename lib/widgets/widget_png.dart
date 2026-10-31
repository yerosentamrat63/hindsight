import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import 'hindsight_widgets.dart';
import 'home_widgets.dart';

/// Draws the five home-screen widgets with Flutter and hands Android the PNGs.
///
/// A RemoteViews layout is inflated inside the launcher's process, where the
/// app's `@font` resources quietly fall back to the system face — which is why
/// the widgets kept coming out in Roboto no matter how the fonts were packaged.
/// Drawing them here keeps Bricolage Grotesque and JetBrains Mono, and the
/// launcher only has to show an image.
///
/// The widgets are painted behind the app's own UI (never at zero opacity,
/// which skips painting), captured once, then removed again.
class WidgetPngHost extends StatefulWidget {
  const WidgetPngHost({super.key, required this.child});

  final Widget child;

  static _WidgetPngHostState? _host;

  /// Redraws every widget for [data] and refreshes the home-screen copies.
  ///
  /// Safe to fire and forget: a failure only means the launcher keeps the
  /// previous picture.
  static Future<void> push(WidgetData data) async => _host?.capture(data);

  @override
  State<WidgetPngHost> createState() => _WidgetPngHostState();
}

class _WidgetPngHostState extends State<WidgetPngHost> {
  static const _keys = ['ring', 'verdict', 'today', 'limit', 'week'];

  /// The card each widget draws, used when the launcher has nothing to say.
  static const _boards = {
    'ring': Size(170, 170),
    'verdict': Size(170, 170),
    'today': Size(360, 170),
    'limit': Size(360, 84),
    'week': Size(360, 360),
  };

  final Map<String, GlobalKey> _boundaries = {
    for (final key in _keys) key: GlobalKey(),
  };

  WidgetData? _data;
  Map<String, Size> _cells = const {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetPngHost._host = this;
  }

  @override
  void dispose() {
    if (WidgetPngHost._host == this) WidgetPngHost._host = null;
    super.dispose();
  }

  Future<void> capture(WidgetData data) async {
    if (!mounted) return;
    // One pass at a time; a second refresh waits rather than racing.
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }
    _busy = true;
    try {
      final cells = await HomeWidgets.sizes();
      if (!mounted) return;
      setState(() {
        _data = data;
        _cells = cells;
      });
      // Two frames: one to lay out, one to paint.
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;

      final ratio = MediaQuery.devicePixelRatioOf(context);
      final dir = await getApplicationSupportDirectory();
      final paths = <String, String>{};

      for (final key in _keys) {
        final boundary = _boundaries[key]?.currentContext?.findRenderObject();
        if (boundary is! RenderRepaintBoundary) continue;
        final image = await boundary.toImage(pixelRatio: ratio);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (bytes == null) continue;
        final file = File('${dir.path}/widget_$key.png');
        await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
        paths[key] = file.path;
      }
      if (paths.isNotEmpty) await HomeWidgets.publishImages(paths);
    } catch (error, stack) {
      // A launcher widget is a nicety; never let it break a refresh, but a
      // silent failure here means a stale picture on the home screen.
      debugPrint('Hindsight: widget capture failed: $error\n$stack');
    } finally {
      if (mounted) setState(() => _data = null);
      _busy = false;
    }
  }

  /// The cell's box, minus the gutter the layouts keep around the card.
  Size _card(String key) {
    final cell = _cells[key];
    final board = _boards[key]!;
    if (cell == null) return board;
    final w = cell.width - 24;
    final h = cell.height - 24;
    // A launcher that reports nonsense should not produce a squashed card.
    if (w < 120 || h < 48) return board;
    return Size(w, h);
  }

  Widget _shot(String key, Widget child) => RepaintBoundary(
        key: _boundaries[key],
        child: widgetHost(WidgetBox(size: _card(key), child: child)),
      );

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (data != null)
          Positioned(
            left: 0,
            top: 0,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shot('ring', RingWidget(data)),
                    _shot('verdict', VerdictWidget(data)),
                    _shot('today', TodayWidget(data)),
                    _shot('limit', LimitWidget(data)),
                    _shot('week', WeekWidget(data)),
                  ],
                ),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}
