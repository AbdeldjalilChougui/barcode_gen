import 'package:flutter/widgets.dart';

import '../encoder/barcode_exception.dart';
import '../encoder/barcode_modules.dart';
import '../encoder/barcode_type.dart';
import '../layout/barcode_layout.dart';
import 'barcode_painter.dart';

/// Builds the widget shown when the data cannot be encoded.
typedef BarcodeErrorBuilder = Widget Function(
  BuildContext context,
  BarcodeException error,
);

/// Draws a 1D barcode.
///
/// ```dart
/// BarcodeView(
///   type: const BarcodeType.ean13(),
///   data: '4006381333931',
///   height: 100,
/// )
/// ```
///
/// Without [moduleWidth] the barcode fills the available width (or uses 2
/// logical pixels per module when the width is unbounded). Modules are
/// always a whole number of device pixels wide.
class BarcodeView extends StatelessWidget {
  /// Creates a barcode widget.
  const BarcodeView({
    super.key,
    required this.type,
    required this.data,
    this.height = 100,
    this.moduleWidth,
    this.barColor = const Color(0xFF000000),
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.quietZoneModules,
    this.hriPosition = HriPosition.below,
    this.hriLayout = HriLayout.auto,
    this.hriStyle,
    this.errorBuilder,
    this.semanticsLabel,
  });

  /// The symbology.
  final BarcodeType type;

  /// The data to encode.
  final String data;

  /// Total height, including the human-readable text.
  final double height;

  /// Logical width of one module. `null` fits the available width.
  final double? moduleWidth;

  /// Bar colour.
  final Color barColor;

  /// Background colour; `null` for transparent. Keep it light: scanners
  /// need contrast.
  final Color? backgroundColor;

  /// Quiet zone on each side in modules. `null` uses the symbology's
  /// recommended value; `0` removes it.
  final int? quietZoneModules;

  /// Where the human-readable interpretation (HRI) goes.
  final HriPosition hriPosition;

  /// How the HRI is laid out: EAN-style split digits or a single line.
  final HriLayout hriLayout;

  /// Style of the HRI text.
  final TextStyle? hriStyle;

  /// Builds the widget shown when [data] is invalid for [type]. Defaults to
  /// a small text with the error message.
  final BarcodeErrorBuilder? errorBuilder;

  /// Accessibility label. Defaults to "`<symbology>` barcode: `<text>`".
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final BarcodeModules modules;
    try {
      modules = type.encode(data);
    } on BarcodeException catch (e) {
      if (errorBuilder != null) return errorBuilder!(context, e);
      return Semantics(
        label: 'Invalid barcode: ${e.message}',
        child: SizedBox(
          height: height,
          child: Center(
            child: Text(
              e.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB00020), fontSize: 12),
            ),
          ),
        ),
      );
    }
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ??
        View.of(context).devicePixelRatio;
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    return Semantics(
      container: true,
      image: true,
      label: semanticsLabel ?? '${type.name} barcode: ${modules.text}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fit = moduleWidth == null && constraints.hasBoundedWidth;
          final painter = BarcodePainter(
            modules: modules,
            moduleWidth: fit ? null : (moduleWidth ?? 2),
            barColor: barColor,
            backgroundColor: backgroundColor,
            hriPosition: hriPosition,
            hriLayout: hriLayout,
            hriStyle: hriStyle,
            quietZoneModules: quietZoneModules,
            devicePixelRatio: dpr,
            textDirection: textDirection,
          );
          final width =
              fit ? constraints.maxWidth : painter.naturalSize(height).width;
          return CustomPaint(size: Size(width, height), painter: painter);
        },
      ),
    );
  }
}
