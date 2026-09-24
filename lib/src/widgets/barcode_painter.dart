import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';

import '../encoder/barcode_modules.dart';
import '../layout/barcode_layout.dart';

/// Paints [BarcodeModules] with every module snapped to whole device
/// pixels.
///
/// With a [moduleWidth] the barcode has a fixed natural size (see
/// [naturalSize]); without one it fits the width it is given, using the
/// largest whole number of device pixels per module.
class BarcodePainter extends CustomPainter {
  /// Creates a painter.
  BarcodePainter({
    required this.modules,
    this.moduleWidth,
    this.barColor = const Color(0xFF000000),
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.hriPosition = HriPosition.below,
    this.hriLayout = HriLayout.auto,
    this.hriStyle,
    this.quietZoneModules,
    this.devicePixelRatio = 1.0,
    this.textDirection = TextDirection.ltr,
  });

  /// What to draw.
  final BarcodeModules modules;

  /// Logical width of one module, rounded to whole device pixels. `null`
  /// fits the painted size.
  final double? moduleWidth;

  /// Bar colour.
  final Color barColor;

  /// Background colour, painted over the whole size. `null` leaves it
  /// transparent.
  final Color? backgroundColor;

  /// Where the human-readable text goes.
  final HriPosition hriPosition;

  /// How the human-readable text is split.
  final HriLayout hriLayout;

  /// Style of the human-readable text. Its colour defaults to [barColor]
  /// and its font size to about 9 modules (8-24 logical pixels).
  final TextStyle? hriStyle;

  /// Quiet zone on each side in modules; `null` uses the symbology's
  /// recommendation.
  final int? quietZoneModules;

  /// Device pixels per logical pixel, used for snapping.
  final double devicePixelRatio;

  /// Direction used to lay out the text.
  final TextDirection textDirection;

  TextStyle _style(double mw) {
    final base = TextStyle(
      color: barColor,
      fontSize: math.min(24, math.max(8, mw * 9)),
      height: 1.15,
    );
    return base.merge(hriStyle);
  }

  bool get _hasText =>
      hriPosition != HriPosition.none && modules.text.isNotEmpty;

  double _textHeight(double mw) {
    if (!_hasText) return 0;
    final tp = TextPainter(
      text: TextSpan(text: '0', style: _style(mw)),
      textDirection: textDirection,
    )..layout();
    final h = tp.height;
    tp.dispose();
    return h;
  }

  double _snappedModuleWidth(double availableWidth) {
    final dpr = devicePixelRatio;
    if (moduleWidth != null) {
      return math.max(1, (moduleWidth! * dpr).round()) / dpr;
    }
    // Width in modules, including quiet zones, overhanging text and
    // bearer frame, measured with a 1-unit module.
    final probe = BarcodeLayout.compute(
      modules: modules,
      moduleWidth: 1,
      height: 1,
      textHeight: _hasText ? 1 : 0,
      hriPosition: hriPosition,
      hriLayout: hriLayout,
      quietZoneLeft: quietZoneModules,
      quietZoneRight: quietZoneModules,
    );
    return fitModulePixels(availableWidth, dpr, probe.width.ceil()) / dpr;
  }

  /// The geometry used to paint into [size].
  BarcodeLayout computeLayout(Size size) {
    final mw = _snappedModuleWidth(size.width);
    return BarcodeLayout.compute(
      modules: modules,
      moduleWidth: mw,
      height: size.height,
      textHeight: _textHeight(mw),
      hriPosition: hriPosition,
      hriLayout: hriLayout,
      quietZoneLeft: quietZoneModules,
      quietZoneRight: quietZoneModules,
      availableWidth: moduleWidth == null ? size.width : null,
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// Size of the barcode at [moduleWidth] with the given total [height].
  /// Requires [moduleWidth].
  Size naturalSize(double height) {
    assert(moduleWidth != null, 'naturalSize needs a moduleWidth');
    return Size(computeLayout(Size(0, height)).width, height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final layout = computeLayout(size);
    if (backgroundColor != null) {
      canvas.drawRect(
        Offset.zero & Size(math.max(size.width, layout.width), size.height),
        Paint()..color = backgroundColor!,
      );
    }
    final bar = Paint()
      ..color = barColor
      ..isAntiAlias = false;
    for (final r in [...layout.bearers, ...layout.bars]) {
      canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, r.height), bar);
    }
    final style = _style(layout.moduleWidth);
    for (final t in layout.texts) {
      final tp = TextPainter(
        text: TextSpan(text: t.text, style: style),
        textDirection: textDirection,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(t.maxWidth, 1));
      tp.paint(canvas, Offset(t.centerX - tp.width / 2, t.top));
      tp.dispose();
    }
  }

  /// Renders the barcode into an image of [size] logical pixels scaled by
  /// [pixelRatio]. Modules are snapped to the image's pixels.
  Future<ui.Image> toImage(Size size, {double pixelRatio = 1}) {
    final painter = BarcodePainter(
      modules: modules,
      moduleWidth: moduleWidth,
      barColor: barColor,
      backgroundColor: backgroundColor,
      hriPosition: hriPosition,
      hriLayout: hriLayout,
      hriStyle: hriStyle,
      quietZoneModules: quietZoneModules,
      devicePixelRatio: pixelRatio,
      textDirection: textDirection,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    painter.paint(canvas, size);
    final picture = recorder.endRecording();
    final image = picture.toImage(
      (size.width * pixelRatio).round(),
      (size.height * pixelRatio).round(),
    );
    return image.whenComplete(picture.dispose);
  }

  /// Renders the barcode like [toImage] and encodes it as PNG.
  Future<Uint8List> toPngBytes(Size size, {double pixelRatio = 1}) async {
    final image = await toImage(size, pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  @override
  bool shouldRepaint(BarcodePainter oldDelegate) =>
      !_sameModules(oldDelegate.modules, modules) ||
      oldDelegate.moduleWidth != moduleWidth ||
      oldDelegate.barColor != barColor ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.hriPosition != hriPosition ||
      oldDelegate.hriLayout != hriLayout ||
      oldDelegate.hriStyle != hriStyle ||
      oldDelegate.quietZoneModules != quietZoneModules ||
      oldDelegate.devicePixelRatio != devicePixelRatio ||
      oldDelegate.textDirection != textDirection;
}

bool _sameModules(BarcodeModules a, BarcodeModules b) =>
    identical(a, b) ||
    (listEquals(a.widths, b.widths) &&
        a.text == b.text &&
        listEquals(a.guards, b.guards) &&
        listEquals(a.textSegments, b.textSegments) &&
        a.addOn == b.addOn &&
        a.quietZoneLeft == b.quietZoneLeft &&
        a.quietZoneRight == b.quietZoneRight &&
        a.bearerBars == b.bearerBars &&
        a.bearerThickness == b.bearerThickness);
