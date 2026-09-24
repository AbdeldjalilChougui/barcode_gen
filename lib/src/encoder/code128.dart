import 'barcode_exception.dart';
import 'barcode_modules.dart';
import 'barcode_type.dart';

/// Code 128 symbol character bar/space widths for values 0-106
/// (ISO/IEC 15417 Table 1). Value 106 is the stop pattern including its
/// final bar.
const code128Patterns = [
  '212222', '222122', '222221', '121223', '121322', '131222', '122213', //
  '122312', '132212', '221213', '221312', '231212', '112232', '122132',
  '122231', '113222', '123122', '123221', '223211', '221132', '221231',
  '213212', '223112', '312131', '311222', '321122', '321221', '312212',
  '322112', '322211', '212123', '212321', '232121', '111323', '131123',
  '131321', '112313', '132113', '132311', '211313', '231113', '231311',
  '112133', '112331', '132131', '113123', '113321', '133121', '313121',
  '211331', '231131', '213113', '213311', '213131', '311123', '311321',
  '331121', '312113', '312311', '332111', '314111', '221411', '431111',
  '111224', '111422', '121124', '121421', '141122', '141221', '112214',
  '112412', '122114', '122411', '142112', '142211', '241211', '221114',
  '413111', '241112', '134111', '111242', '121142', '121241', '114212',
  '124112', '124211', '411212', '421112', '421211', '212141', '214121',
  '412121', '111143', '111341', '131141', '114113', '114311', '411113',
  '411311', '113141', '114131', '311141', '411131', '211412', '211214',
  '211232', '2331112',
];

const _startA = 103;
const _startB = 104;
const _startC = 105;
const _stop = 106;
const _shift = 98;
const _codeC = 99;
const _fnc1Value = 102;
const _fnc1Token = -1;

// Code sets.
const _a = 0;
const _b = 1;
const _c = 2;
const _inf = 1 << 30;

bool _inA(int t) => t == _fnc1Token || (t >= 0 && t < 96);
bool _inB(int t) => t == _fnc1Token || (t >= 32 && t < 128);
bool _isDigit(int t) => t >= 0x30 && t <= 0x39;

int _valueA(int t) => t == _fnc1Token ? _fnc1Value : (t < 32 ? t + 64 : t - 32);
int _valueB(int t) => t == _fnc1Token ? _fnc1Value : t - 32;

// "Code A" is 101 in sets B and C; "Code B" is 100 in sets A and C.
const _codeA = 101;
const _codeB = 100;

// How a token is encoded while staying in a set.
const _none = 0;
const _plain = 1;
const _shifted = 2;
const _pair = 3;

/// Code 128 encoder (ISO/IEC 15417) with automatic selection of code sets
/// A, B and C (including Shift) that yields the fewest symbol characters.
///
/// Accepts ASCII 0-127. Put [fnc1] in the data to encode an FNC1 character.
/// Extended characters (FNC4) are not supported.
class Code128Encoder extends BarcodeType {
  /// Creates a Code 128 encoder.
  const Code128Encoder();

  /// Placeholder character that encodes FNC1 (the common `\xF1`
  /// convention). It never appears in the HRI text.
  static const fnc1 = 'ñ';

  @override
  String get name => 'Code 128';

  /// The full symbol character value sequence for [data]: start, data,
  /// check symbol and stop (106).
  List<int> codewords(String data) {
    final tokens = _tokenize(data);
    final values = _optimalValues(tokens);
    var sum = values.first;
    for (var i = 1; i < values.length; i++) {
      sum += i * values[i];
    }
    return [...values, sum % 103, _stop];
  }

  @override
  BarcodeModules encode(String data) =>
      modulesFromCodewords(codewords(data), data.replaceAll(fnc1, ''));

  /// Builds [BarcodeModules] from a complete value sequence.
  static BarcodeModules modulesFromCodewords(List<int> values, String text) {
    final widths = <int>[
      for (final v in values)
        for (final c in code128Patterns[v].codeUnits) c - 0x30,
    ];
    return BarcodeModules(widths: widths, text: text);
  }

  static List<int> _tokenize(String data) {
    if (data.isEmpty) {
      throw const BarcodeException(
        BarcodeErrorKind.invalidLength,
        'Code 128 data must not be empty',
      );
    }
    final out = <int>[];
    for (final r in data.runes) {
      if (r == 0xF1) {
        out.add(_fnc1Token);
      } else if (r < 128) {
        out.add(r);
      } else {
        throw BarcodeException(
          BarcodeErrorKind.invalidCharacter,
          'Code 128 cannot encode U+${r.toRadixString(16).padLeft(4, '0')}',
        );
      }
    }
    return out;
  }

  /// Dynamic programming over (position, code set).
  ///
  /// `stay[i][s]` is the fewest symbols that encode tokens `i..` when the
  /// symbol at `i` is encoded in set `s` without switching first; `best[i][s]`
  /// also allows one "Code X" switch before it. Ties prefer staying in the
  /// current set, then C, B, A, so the output is deterministic.
  static List<int> _optimalValues(List<int> t) {
    final n = t.length;
    final stay = List.generate(n + 1, (_) => List.filled(3, _inf));
    final stayHow = List.generate(n + 1, (_) => List.filled(3, _none));
    final best = List.generate(n + 1, (_) => List.filled(3, _inf));
    final switchTo = List.generate(n + 1, (_) => List.filled(3, -1));
    best[n] = [0, 0, 0];
    for (var i = n - 1; i >= 0; i--) {
      for (final s in const [_a, _b]) {
        final inSet = s == _a ? _inA(t[i]) : _inB(t[i]);
        final inOther = s == _a ? _inB(t[i]) : _inA(t[i]);
        if (inSet) {
          stay[i][s] = 1 + best[i + 1][s];
          stayHow[i][s] = _plain;
        } else if (inOther) {
          stay[i][s] = 2 + best[i + 1][s];
          stayHow[i][s] = _shifted;
        }
      }
      if (t[i] == _fnc1Token) {
        stay[i][_c] = 1 + best[i + 1][_c];
        stayHow[i][_c] = _plain;
      } else if (i + 1 < n && _isDigit(t[i]) && _isDigit(t[i + 1])) {
        stay[i][_c] = 1 + best[i + 2][_c];
        stayHow[i][_c] = _pair;
      }
      for (var s = 0; s < 3; s++) {
        var cost = stay[i][s];
        for (final to in const [_c, _b, _a]) {
          if (to == s || stay[i][to] >= _inf) continue;
          if (1 + stay[i][to] < cost) {
            cost = 1 + stay[i][to];
            switchTo[i][s] = to;
          }
        }
        best[i][s] = cost;
      }
    }
    var set = -1;
    for (final s in const [_c, _b, _a]) {
      if (stay[0][s] < _inf && (set < 0 || stay[0][s] < stay[0][set])) set = s;
    }
    if (set < 0) {
      throw const BarcodeException(
        BarcodeErrorKind.invalidCharacter,
        'Code 128 cannot encode the data',
      );
    }
    final out = <int>[
      const [_startA, _startB, _startC][set]
    ];
    var i = 0;
    var mayswitch = false;
    while (i < n) {
      if (mayswitch && switchTo[i][set] >= 0) {
        final to = switchTo[i][set];
        out.add(to == _a ? _codeA : (to == _b ? _codeB : _codeC));
        set = to;
      }
      mayswitch = true;
      switch (stayHow[i][set]) {
        case _plain:
          out.add(set == _a ? _valueA(t[i]) : _valueB(t[i]));
          i++;
        case _shifted:
          out
            ..add(_shift)
            ..add(set == _a ? _valueB(t[i]) : _valueA(t[i]));
          i++;
        default:
          out.add((t[i] - 0x30) * 10 + (t[i + 1] - 0x30));
          i += 2;
      }
    }
    return out;
  }
}
