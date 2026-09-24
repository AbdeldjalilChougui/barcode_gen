import 'dart:math' as math;

import '../encoder/barcode_modules.dart';
import '../layout/barcode_layout.dart';

String _num(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  var s = v.toStringAsFixed(3);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// Renders [modules] as a standalone SVG document. Pure Dart.
///
/// [moduleWidth] and [height] are in SVG user units (pixels). Colours are
/// any SVG paint value; a `null` [backgroundColor] leaves the background
/// transparent. [fontSize] defaults to 9 modules, clamped to 8-48.
/// [quietZoneModules] overrides the symbology's quiet zones on both sides.
String barcodeToSvg(
  BarcodeModules modules, {
  double moduleWidth = 2,
  double height = 80,
  String barColor = '#000000',
  String? backgroundColor = '#ffffff',
  bool drawText = true,
  HriPosition hriPosition = HriPosition.below,
  HriLayout hriLayout = HriLayout.auto,
  double? fontSize,
  String fontFamily = 'monospace',
  int? quietZoneModules,
}) {
  final size = fontSize ?? math.min(48, math.max(8, moduleWidth * 9));
  final lineHeight = size * 1.2;
  final layout = BarcodeLayout.compute(
    modules: modules,
    moduleWidth: moduleWidth,
    height: height,
    textHeight: drawText ? lineHeight : 0,
    hriPosition: hriPosition,
    hriLayout: hriLayout,
    quietZoneLeft: quietZoneModules,
    quietZoneRight: quietZoneModules,
  );
  final w = _num(layout.width);
  final h = _num(layout.height);
  final b = StringBuffer()
    ..write('<svg xmlns="http://www.w3.org/2000/svg" version="1.1" ')
    ..write('width="$w" height="$h" viewBox="0 0 $w $h" ')
    ..write('shape-rendering="crispEdges">\n');
  if (backgroundColor != null) {
    b.write(
        '<rect width="$w" height="$h" fill="${_escape(backgroundColor)}"/>\n');
  }
  b.write('<g fill="${_escape(barColor)}">\n');
  for (final r in [...layout.bearers, ...layout.bars]) {
    b.write('<rect x="${_num(r.left)}" y="${_num(r.top)}" '
        'width="${_num(r.width)}" height="${_num(r.height)}"/>\n');
  }
  for (final t in layout.texts) {
    // Baseline roughly one font size below the top of the line box.
    b.write('<text x="${_num(t.centerX)}" y="${_num(t.top + size)}" '
        'text-anchor="middle" font-family="${_escape(fontFamily)}" '
        'font-size="${_num(size)}">${_escape(t.text)}</text>\n');
  }
  b.write('</g>\n</svg>\n');
  return b.toString();
}
