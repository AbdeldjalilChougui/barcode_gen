import 'barcode_exception.dart';
import 'barcode_modules.dart';
import 'barcode_type.dart';
import 'check_digits.dart';
import 'wide_narrow.dart';

// ISO/IEC 16390 digit patterns, five elements with two wide.
const _digits = [
  'nnwwn', 'wnnnw', 'nwnnw', 'wwnnn', 'nnwnw', //
  'wnwnn', 'nwwnn', 'nnnww', 'wnnwn', 'nwnwn',
];

BarcodeModules _itf(
  String data,
  String text,
  BearerBars bearer,
  int thickness,
) {
  final widths = <int>[1, 1, 1, 1]; // start: narrow bar/space x2
  for (var i = 0; i < data.length; i += 2) {
    final bars = _digits[data.codeUnitAt(i) - 0x30];
    final spaces = _digits[data.codeUnitAt(i + 1) - 0x30];
    for (var k = 0; k < 5; k++) {
      widths
        ..add(bars[k] == 'w' ? wideModules : 1)
        ..add(spaces[k] == 'w' ? wideModules : 1);
    }
  }
  widths.addAll([wideModules, 1, 1]); // stop: wide bar, narrow space, bar
  return BarcodeModules(
    widths: widths,
    text: text,
    bearerBars: bearer,
    bearerThickness: bearer == BearerBars.none ? 0 : thickness,
  );
}

void _requireDigits(String data, String name) {
  if (!isAllDigits(data)) {
    throw BarcodeException(
      BarcodeErrorKind.invalidCharacter,
      '$name accepts digits only, got "$data"',
    );
  }
}

/// Interleaved 2 of 5 (ISO/IEC 16390). Needs an even, non-zero number of
/// digits; add a leading zero yourself if your data has an odd length.
class ItfEncoder extends BarcodeType {
  /// Creates an ITF encoder, optionally with [bearerBars].
  const ItfEncoder({
    this.bearerBars = BearerBars.none,
    this.bearerThickness = 5,
  });

  /// Bearer bars to draw.
  final BearerBars bearerBars;

  /// Bearer bar thickness in modules.
  final int bearerThickness;

  @override
  String get name => 'ITF';

  @override
  BarcodeModules encode(String data) {
    _requireDigits(data, name);
    if (data.isEmpty || data.length.isOdd) {
      throw BarcodeException(
        BarcodeErrorKind.invalidLength,
        'ITF needs an even number of digits, got ${data.length}',
      );
    }
    return _itf(data, data, bearerBars, bearerThickness);
  }
}

/// ITF-14 (GS1 General Specifications section 5.3): a GTIN-14 in ITF with
/// a GS1 check digit and, by default, a bearer bar frame.
class Itf14Encoder extends BarcodeType {
  /// Creates an ITF-14 encoder. Accepts 13 digits (check digit computed)
  /// or 14 digits (check digit verified).
  const Itf14Encoder({
    this.bearerBars = BearerBars.frame,
    this.bearerThickness = 5,
  });

  /// Bearer bars to draw.
  final BearerBars bearerBars;

  /// Bearer bar thickness in modules.
  final int bearerThickness;

  @override
  String get name => 'ITF-14';

  @override
  BarcodeModules encode(String data) {
    _requireDigits(data, name);
    final String full;
    if (data.length == 13) {
      full = '$data${gs1CheckDigit(data)}';
    } else if (data.length == 14) {
      final expected = gs1CheckDigit(data.substring(0, 13));
      if (data.codeUnitAt(13) - 0x30 != expected) {
        throw BarcodeException(
          BarcodeErrorKind.invalidCheckDigit,
          'ITF-14 check digit should be $expected in "$data"',
        );
      }
      full = data;
    } else {
      throw BarcodeException(
        BarcodeErrorKind.invalidLength,
        'ITF-14 needs 13 or 14 digits, got ${data.length}',
      );
    }
    return _itf(full, full, bearerBars, bearerThickness);
  }
}
