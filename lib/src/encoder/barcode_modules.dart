/// A half-open range `[start, end)` of modules, measured from the first
/// module of the symbol. Values may be negative or exceed the symbol width
/// when they refer to the quiet zones (for example the leading EAN-13 digit).
class ModuleSpan {
  /// Creates the span `[start, end)`.
  const ModuleSpan(this.start, this.end);

  /// First module of the span.
  final int start;

  /// One past the last module of the span.
  final int end;

  /// Number of modules covered.
  int get length => end - start;

  /// Whether [module] lies inside the span.
  bool contains(int module) => module >= start && module < end;

  @override
  bool operator ==(Object other) =>
      other is ModuleSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'ModuleSpan($start, $end)';
}

/// One piece of human-readable interpretation (HRI) text and the module
/// range it is centred on.
class HriSegment {
  /// Creates a segment showing [text] centred over [span].
  const HriSegment(this.text, this.span);

  /// The characters to print.
  final String text;

  /// Horizontal extent the text is centred in.
  final ModuleSpan span;

  @override
  bool operator ==(Object other) =>
      other is HriSegment && other.text == text && other.span == span;

  @override
  int get hashCode => Object.hash(text, span);

  @override
  String toString() => 'HriSegment($text, $span)';
}

/// Bearer bars drawn around an ITF symbol.
enum BearerBars {
  /// No bearer bars.
  none,

  /// Horizontal bars along the top and bottom edges only.
  horizontal,

  /// A full rectangle around the symbol and its quiet zones.
  frame,
}

/// The output of an encoder: a sequence of bar and space widths in modules
/// plus everything a renderer needs to draw the symbol.
///
/// [widths] always starts with a bar and alternates bar, space, bar...
class BarcodeModules {
  /// Creates a module description. Throws [ArgumentError] when a width is
  /// not positive.
  BarcodeModules({
    required List<int> widths,
    required this.text,
    List<ModuleSpan> guards = const [],
    List<HriSegment> textSegments = const [],
    this.addOn,
    this.quietZoneLeft = 10,
    this.quietZoneRight = 10,
    this.bearerBars = BearerBars.none,
    this.bearerThickness = 0,
  })  : widths = List.unmodifiable(widths),
        guards = List.unmodifiable(guards),
        textSegments = List.unmodifiable(textSegments) {
    for (final w in widths) {
      if (w <= 0) throw ArgumentError.value(widths, 'widths', 'must be > 0');
    }
  }

  /// Builds modules from a `'1'` (bar) / `'0'` (space) string that starts
  /// with a bar.
  factory BarcodeModules.fromPattern(
    String pattern, {
    required String text,
    List<ModuleSpan> guards = const [],
    List<HriSegment> textSegments = const [],
    ModuleSpan? addOn,
    int quietZoneLeft = 10,
    int quietZoneRight = 10,
    BearerBars bearerBars = BearerBars.none,
    int bearerThickness = 0,
  }) =>
      BarcodeModules(
        widths: patternToWidths(pattern),
        text: text,
        guards: guards,
        textSegments: textSegments,
        addOn: addOn,
        quietZoneLeft: quietZoneLeft,
        quietZoneRight: quietZoneRight,
        bearerBars: bearerBars,
        bearerThickness: bearerThickness,
      );

  /// Alternating bar and space widths in modules, starting with a bar.
  final List<int> widths;

  /// Human-readable interpretation of the whole symbol.
  final String text;

  /// Module ranges whose bars extend below the others (EAN/UPC guard
  /// patterns, and the outer UPC-A characters).
  final List<ModuleSpan> guards;

  /// Placement of the HRI text. Empty means [text] is centred under the
  /// whole symbol.
  final List<HriSegment> textSegments;

  /// Module range of an EAN/UPC add-on symbol, whose HRI is printed above
  /// its bars. `null` when there is no add-on.
  final ModuleSpan? addOn;

  /// Minimum light margin before the symbol, in modules.
  final int quietZoneLeft;

  /// Minimum light margin after the symbol, in modules.
  final int quietZoneRight;

  /// Bearer bars to draw (ITF-14).
  final BearerBars bearerBars;

  /// Bearer bar thickness in modules; `0` when [bearerBars] is none.
  final int bearerThickness;

  /// Total symbol width in modules, excluding quiet zones.
  int get moduleCount => widths.fold(0, (a, b) => a + b);

  /// One entry per module: `true` for a dark (bar) module.
  List<bool> get bits {
    final out = <bool>[];
    for (var i = 0; i < widths.length; i++) {
      out.addAll(List.filled(widths[i], i.isEven));
    }
    return out;
  }

  /// The modules as a `'1'`/`'0'` string. Handy for tests.
  String get pattern => bits.map((b) => b ? '1' : '0').join();

  /// Module span of every bar, left to right.
  List<ModuleSpan> get bars {
    final out = <ModuleSpan>[];
    var x = 0;
    for (var i = 0; i < widths.length; i++) {
      if (i.isEven) out.add(ModuleSpan(x, x + widths[i]));
      x += widths[i];
    }
    return out;
  }

  /// Whether [module] is inside one of the [guards].
  bool isGuard(int module) => guards.any((g) => g.contains(module));
}

/// Converts a `'1'`/`'0'` pattern starting with `'1'` into run widths.
List<int> patternToWidths(String pattern) {
  if (pattern.isEmpty || pattern[0] != '1') {
    throw ArgumentError.value(pattern, 'pattern', 'must start with a bar');
  }
  final out = <int>[];
  var run = 0;
  var current = '1';
  for (var i = 0; i < pattern.length; i++) {
    final c = pattern[i];
    if (c != '0' && c != '1') {
      throw ArgumentError.value(pattern, 'pattern', 'only 0 and 1 allowed');
    }
    if (c == current) {
      run++;
    } else {
      out.add(run);
      run = 1;
      current = c;
    }
  }
  out.add(run);
  return out;
}
