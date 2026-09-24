import 'barcode_exception.dart';
import 'barcode_modules.dart';
import 'barcode_type.dart';
import 'wide_narrow.dart';

/// Code 39 characters in check-value order (ISO/IEC 16388).
const _chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. \$/+%';

// Element patterns (bar, space, bar, ... bar) in the order of [_chars].
const _patterns = [
  'nnnwwnwnn', 'wnnwnnnnw', 'nnwwnnnnw', 'wnwwnnnnn', 'nnnwwnnnw', //
  'wnnwwnnnn', 'nnwwwnnnn', 'nnnwnnwnw', 'wnnwnnwnn', 'nnwwnnwnn',
  'wnnnnwnnw', 'nnwnnwnnw', 'wnwnnwnnn', 'nnnnwwnnw', 'wnnnwwnnn',
  'nnwnwwnnn', 'nnnnnwwnw', 'wnnnnwwnn', 'nnwnnwwnn', 'nnnnwwwnn',
  'wnnnnnnww', 'nnwnnnnww', 'wnwnnnnwn', 'nnnnwnnww', 'wnnnwnnwn',
  'nnwnwnnwn', 'nnnnnnwww', 'wnnnnnwwn', 'nnwnnnwwn', 'nnnnwnwwn',
  'wwnnnnnnw', 'nwwnnnnnw', 'wwwnnnnnn', 'nwnnwnnnw', 'wwnnwnnnn',
  'nwwnwnnnn', 'nwnnnnwnw', 'wwnnnnwnn', 'nwwnnnwnn', 'nwnwnwnnn',
  'nwnwnnnwn', 'nwnnnwnwn', 'nnnwnwnwn',
];

const _startStop = 'nwnnwnwnn';

/// Full ASCII mapping for code points 0-127 (ISO/IEC 16388 Annex, also
/// used by Code 93 with its dedicated shift characters).
const fullAsciiTable = [
  '%U', r'$A', r'$B', r'$C', r'$D', r'$E', r'$F', r'$G', r'$H', r'$I', //
  r'$J', r'$K', r'$L', r'$M', r'$N', r'$O', r'$P', r'$Q', r'$R', r'$S',
  r'$T', r'$U', r'$V', r'$W', r'$X', r'$Y', r'$Z', '%A', '%B', '%C',
  '%D', '%E', ' ', '/A', '/B', '/C', '/D', '/E', '/F', '/G',
  '/H', '/I', '/J', '/K', '/L', '-', '.', '/O', '0', '1',
  '2', '3', '4', '5', '6', '7', '8', '9', '/Z', '%F',
  '%G', '%H', '%I', '%J', '%V', 'A', 'B', 'C', 'D', 'E',
  'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O',
  'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y',
  'Z', '%K', '%L', '%M', '%N', '%O', '%W', '+A', '+B', '+C',
  '+D', '+E', '+F', '+G', '+H', '+I', '+J', '+K', '+L', '+M',
  '+N', '+O', '+P', '+Q', '+R', '+S', '+T', '+U', '+V', '+W',
  '+X', '+Y', '+Z', '%P', '%Q', '%R', '%S', '%T',
];

/// Expands ASCII [data] to the Code 39 full-ASCII character sequence.
/// Throws [BarcodeException] for characters above 127.
String code39FullAscii(String data) {
  final b = StringBuffer();
  for (final r in data.runes) {
    if (r > 127) {
      throw BarcodeException(
        BarcodeErrorKind.invalidCharacter,
        'Full ASCII covers code points 0-127 only, got U+'
        '${r.toRadixString(16).padLeft(4, '0')}',
      );
    }
    b.write(fullAsciiTable[r]);
  }
  return b.toString();
}

/// The Code 39 modulo-43 check character for [data] (already restricted
/// to the 43 Code 39 characters).
String code39CheckCharacter(String data) {
  var sum = 0;
  for (final c in data.split('')) {
    final v = _chars.indexOf(c);
    if (v < 0) {
      throw BarcodeException(
        BarcodeErrorKind.invalidCharacter,
        'Code 39 cannot encode "$c"',
      );
    }
    sum += v;
  }
  return _chars[sum % 43];
}

/// Code 39 encoder (ISO/IEC 16388): 3:1 wide/narrow ratio, narrow
/// inter-character gaps, `*` start/stop added automatically.
class Code39Encoder extends BarcodeType {
  /// Creates a Code 39 encoder. With [fullAscii] every ASCII character is
  /// accepted and encoded as a pair; with [checkDigit] a modulo-43 check
  /// character is appended (not shown in the HRI).
  const Code39Encoder({this.fullAscii = false, this.checkDigit = false});

  /// Encode ASCII 0-127 using shift pairs.
  final bool fullAscii;

  /// Append the optional modulo-43 check character.
  final bool checkDigit;

  @override
  String get name => 'Code 39';

  @override
  BarcodeModules encode(String data) {
    if (data.isEmpty) {
      throw const BarcodeException(
        BarcodeErrorKind.invalidLength,
        'Code 39 data must not be empty',
      );
    }
    var body = fullAscii ? code39FullAscii(data) : data;
    for (final c in body.split('')) {
      if (!_chars.contains(c)) {
        throw BarcodeException(
          BarcodeErrorKind.invalidCharacter,
          'Code 39 cannot encode "$c"${fullAscii ? '' : ' (enable fullAscii '
              'for lowercase and symbols)'}',
        );
      }
    }
    if (checkDigit) body += code39CheckCharacter(body);
    final widths = <int>[...nwToWidths(_startStop)];
    for (final c in body.split('')) {
      widths
        ..add(1)
        ..addAll(nwToWidths(_patterns[_chars.indexOf(c)]));
    }
    widths
      ..add(1)
      ..addAll(nwToWidths(_startStop));
    return BarcodeModules(widths: widths, text: data);
  }
}
