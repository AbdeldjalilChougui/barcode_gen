/// Width in modules of a wide element. ISO/IEC 16388 (Code 39), 16390
/// (ITF) and the Codabar specification allow a wide:narrow ratio between
/// 2.0 and 3.0; whole modules require 2 or 3, and 3 is used for the widest
/// decoding margin.
const wideModules = 3;

/// Converts an `n`/`w` element string to module widths.
List<int> nwToWidths(String nw) =>
    [for (final c in nw.split('')) c == 'w' ? wideModules : 1];
