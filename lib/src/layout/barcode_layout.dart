import 'dart:math' as math;

import '../encoder/barcode_modules.dart';

/// Where the human-readable interpretation is drawn.
enum HriPosition {
  /// Below the bars (the usual place; EAN guard bars extend into it).
  below,

  /// Above the bars.
  above,

  /// Not drawn.
  none,
}

/// How the human-readable interpretation is laid out.
enum HriLayout {
  /// Use the symbology's own layout: EAN/UPC digits split around the guard
  /// bars, add-on digits above the add-on. Other symbologies get one
  /// centred line.
  auto,

  /// Always one centred line under (or over) the whole symbol.
  singleLine,
}

/// An axis-aligned rectangle in logical pixels.
class LayoutRect {
  /// Creates a rectangle.
  const LayoutRect(this.left, this.top, this.width, this.height);

  /// Left edge.
  final double left;

  /// Top edge.
  final double top;

  /// Width.
  final double width;

  /// Height.
  final double height;

  /// Right edge.
  double get right => left + width;

  /// Bottom edge.
  double get bottom => top + height;

  @override
  String toString() => 'LayoutRect($left, $top, $width, $height)';
}

/// A piece of HRI text centred on [centerX], with its box starting at [top].
class LayoutText {
  /// Creates a positioned text.
  const LayoutText(this.text, this.centerX, this.top, this.maxWidth);

  /// Characters to draw.
  final String text;

  /// Horizontal centre in logical pixels.
  final double centerX;

  /// Top of the text box in logical pixels.
  final double top;

  /// Width available to the text.
  final double maxWidth;
}

/// Device pixels per module that make a symbol of [totalModules] modules
/// (including quiet zones) fit in [availableWidth] logical pixels. Never
/// less than 1.
int fitModulePixels(
  double availableWidth,
  double devicePixelRatio,
  int totalModules,
) {
  if (totalModules <= 0) return 1;
  final px = (availableWidth * devicePixelRatio + 1e-9) ~/ totalModules;
  return math.max(1, px);
}

double _snap(double v, double dpr) => (v * dpr).roundToDouble() / dpr;

/// Pure-Dart geometry of a rendered barcode, shared by the Flutter painter
/// and the SVG exporter. All values are logical pixels.
class BarcodeLayout {
  BarcodeLayout._({
    required this.width,
    required this.height,
    required this.symbolLeft,
    required this.moduleWidth,
    required this.bars,
    required this.bearers,
    required this.texts,
  });

  /// Computes the layout.
  ///
  /// [moduleWidth] is the width of one module; pass `modulePixels / dpr`
  /// from [fitModulePixels] to keep every edge on a device pixel.
  /// [textHeight] is the height of one line of HRI text; `0` hides the
  /// text. Quiet zones default to the symbology's recommendation. When
  /// [availableWidth] is larger than the symbol, the symbol is centred.
  factory BarcodeLayout.compute({
    required BarcodeModules modules,
    required double moduleWidth,
    required double height,
    double textHeight = 0,
    HriPosition hriPosition = HriPosition.below,
    HriLayout hriLayout = HriLayout.auto,
    int? quietZoneLeft,
    int? quietZoneRight,
    double? availableWidth,
    double devicePixelRatio = 1,
  }) {
    final dpr = devicePixelRatio;
    final mw = moduleWidth;
    final count = modules.moduleCount;
    final showText = textHeight > 0 && hriPosition != HriPosition.none;
    final useSegments = showText &&
        hriLayout == HriLayout.auto &&
        modules.textSegments.isNotEmpty;
    final eanBelow = useSegments && hriPosition == HriPosition.below;

    var qzl = quietZoneLeft ?? modules.quietZoneLeft;
    var qzr = quietZoneRight ?? modules.quietZoneRight;
    if (useSegments) {
      for (final s in modules.textSegments) {
        qzl = math.max(qzl, -s.span.start);
        qzr = math.max(qzr, s.span.end - count);
      }
    }
    final frame = modules.bearerBars == BearerBars.frame;
    final bearer = modules.bearerBars == BearerBars.none
        ? 0.0
        : modules.bearerThickness * mw;
    final side = frame ? bearer : 0.0;
    final natural = side * 2 + (qzl + count + qzr) * mw;
    final width = math.max(natural, availableWidth ?? 0);
    final origin = _snap((width - natural) / 2, dpr);
    final symbolLeft = origin + side + qzl * mw;

    // Vertical bands.
    final textH = showText ? textHeight : 0.0;
    double barsTop = 0;
    var barsBottom = height;
    if (showText && hriPosition == HriPosition.above) barsTop = textH;
    if (showText && hriPosition == HriPosition.below) barsBottom -= textH;
    final frameTop = barsTop;
    final frameBottom = barsBottom;
    barsTop += bearer;
    barsBottom -= bearer;
    final guardBottom = eanBelow ? barsBottom + textH / 2 : barsBottom;
    final addOn = modules.addOn;
    // Below-HRI EAN add-ons carry their digits above the add-on bars.
    final addOnTop = eanBelow ? barsTop + textH : barsTop;

    double x(num module) => symbolLeft + module * mw;

    final bars = <LayoutRect>[];
    var m = 0;
    for (var i = 0; i < modules.widths.length; i++) {
      final w = modules.widths[i];
      if (i.isEven) {
        final inAddOn = addOn != null && addOn.contains(m);
        final top = inAddOn ? addOnTop : barsTop;
        final bottom = inAddOn || modules.isGuard(m) ? guardBottom : barsBottom;
        bars.add(LayoutRect(x(m), top, w * mw, bottom - top));
      }
      m += w;
    }

    final bearers = <LayoutRect>[];
    if (bearer > 0) {
      final left = origin;
      final w = natural;
      bearers
        ..add(LayoutRect(left, frameTop, w, bearer))
        ..add(LayoutRect(left, frameBottom - bearer, w, bearer));
      if (frame) {
        final h = frameBottom - frameTop;
        bearers
          ..add(LayoutRect(left, frameTop, bearer, h))
          ..add(LayoutRect(left + w - bearer, frameTop, bearer, h));
      }
    }

    final texts = <LayoutText>[];
    if (showText) {
      final lineTop = hriPosition == HriPosition.above ? 0.0 : height - textH;
      if (useSegments) {
        for (final s in modules.textSegments) {
          final isAddOn = addOn != null && s.span == addOn;
          texts.add(LayoutText(
            s.text,
            x((s.span.start + s.span.end) / 2),
            isAddOn && eanBelow ? barsTop : lineTop,
            s.span.length * mw,
          ));
        }
      } else if (modules.text.isNotEmpty) {
        texts.add(LayoutText(
          modules.text,
          x(count / 2),
          lineTop,
          math.max(count * mw, natural),
        ));
      }
    }

    return BarcodeLayout._(
      width: width,
      height: height,
      symbolLeft: symbolLeft,
      moduleWidth: mw,
      bars: bars,
      bearers: bearers,
      texts: texts,
    );
  }

  /// Total width including quiet zones (and centring margin).
  final double width;

  /// Total height.
  final double height;

  /// X of the first module of the symbol.
  final double symbolLeft;

  /// Width of one module.
  final double moduleWidth;

  /// One rectangle per bar, left to right.
  final List<LayoutRect> bars;

  /// Bearer bar rectangles (ITF), empty when none.
  final List<LayoutRect> bearers;

  /// HRI text boxes.
  final List<LayoutText> texts;
}
