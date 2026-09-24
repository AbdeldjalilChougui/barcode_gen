import 'barcode_exception.dart';
import 'barcode_modules.dart';
import 'barcode_type.dart';
import 'code39.dart' show fullAsciiTable;

const _chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. \$/+%';

// Bar/space widths for values 0-46 (43 characters and the four shift
// characters ($) (%) (/) (+)), each 9 modules.
const _patterns = [
  '131112', '111213', '111312', '111411', '121113', '121212', '121311', //
  '111114', '131211', '141111', '211113', '211212', '211311', '221112',
  '221211', '231111', '112113', '112212', '112311', '122112', '132111',
  '111123', '111222', '111321', '121122', '131121', '212112', '212211',
  '211122', '211221', '221121', '222111', '112122', '112221', '122121',
  '123111', '121131', '311112', '311211', '321111', '112131', '113121',
  '211131', '121221', '312111', '311121', '122211',
];

const _startStop = '111141';

// Shift values replacing $, %, / and + in full-ASCII pairs.
const _shiftDollar = 43;
const _shiftPercent = 44;
const _shiftSlash = 45;
const _shiftPlus = 46;

List<int> _values(String data) {
  final out = <int>[];
  for (final r in data.runes) {
    if (r > 127) {
      throw BarcodeException(
        BarcodeErrorKind.invalidCharacter,
        'Code 93 covers ASCII 0-127 only, got U+'
        '${r.toRadixString(16).padLeft(4, '0')}',
      );
    }
    final direct = _chars.indexOf(String.fromCharCode(r));
    // The 43 native characters except the four shift symbols encode
    // directly; $ % / + themselves also exist as native characters.
    if (direct >= 0) {
      out.add(direct);
      continue;
    }
    final pair = fullAsciiTable[r];
    out
      ..add(switch (pair[0]) {
        r'$' => _shiftDollar,
        '%' => _shiftPercent,
        '/' => _shiftSlash,
        _ => _shiftPlus,
      })
      ..add(_chars.indexOf(pair[1]));
  }
  return out;
}

int _weighted(List<int> values, int maxWeight) {
  var sum = 0;
  var w = 1;
  for (var i = values.length - 1; i >= 0; i--) {
    sum += values[i] * w;
    w = w == maxWeight ? 1 : w + 1;
  }
  return sum % 47;
}

/// The two Code 93 check values `[C, K]` for [data].
List<int> code93CheckValues(String data) {
  final v = _values(data);
  final c = _weighted(v, 20);
  final k = _weighted([...v, c], 15);
  return [c, k];
}

/// Code 93 encoder with its two mandatory modulo-47 check characters.
/// Accepts ASCII 0-127; characters outside the 43-character set use the
/// full-ASCII shift characters automatically.
class Code93Encoder extends BarcodeType {
  /// Creates a Code 93 encoder.
  const Code93Encoder();

  @override
  String get name => 'Code 93';

  @override
  BarcodeModules encode(String data) {
    if (data.isEmpty) {
      throw const BarcodeException(
        BarcodeErrorKind.invalidLength,
        'Code 93 data must not be empty',
      );
    }
    final v = _values(data);
    final check = code93CheckValues(data);
    final widths = <int>[];
    void add(String p) => widths.addAll(p.codeUnits.map((c) => c - 0x30));
    add(_startStop);
    for (final x in [...v, ...check]) {
      add(_patterns[x]);
    }
    add(_startStop);
    widths.add(1); // termination bar
    return BarcodeModules(widths: widths, text: data);
  }
}
