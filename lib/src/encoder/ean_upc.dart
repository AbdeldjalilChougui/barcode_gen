import 'barcode_exception.dart';
import 'barcode_modules.dart';
import 'barcode_type.dart';
import 'check_digits.dart';

// ISO/IEC 15420 number set A (odd parity, "L"), stored as 7-module patterns.
const _setA = [
  '0001101', '0011001', '0010011', '0111101', '0100011', //
  '0110001', '0101111', '0111011', '0110111', '0001011',
];

String _setC(int d) =>
    _setA[d].split('').map((c) => c == '1' ? '0' : '1').join();

// Number set B ("G") is number set C read right to left.
String _setB(int d) => _setC(d).split('').reversed.join();

String _digitPattern(int d, String set) => switch (set) {
      'A' => _setA[d],
      'B' => _setB(d),
      _ => _setC(d),
    };

// Parity of the left-hand six digits of EAN-13, keyed by the leading digit.
const _ean13Parity = [
  'AAAAAA', 'AABABB', 'AABBAB', 'AABBBA', 'ABAABB', //
  'ABBAAB', 'ABBBAA', 'ABABAB', 'ABABBA', 'ABBABA',
];

// UPC-E parity for number system 0, keyed by the check digit (B = even).
const _upcEParity = [
  'BBBAAA', 'BBABAA', 'BBAABA', 'BBAAAB', 'BABBAA', //
  'BAABBA', 'BAAABB', 'BABABA', 'BABAAB', 'BAABAB',
];

// EAN-5 add-on parity keyed by its checksum.
const _ean5Parity = [
  'BBAAA', 'BABAA', 'BAABA', 'BAAAB', 'ABBAA', //
  'AABBA', 'AAABB', 'ABABA', 'ABAAB', 'AABAB',
];

const _normalGuard = '101';
const _centreGuard = '01010';
const _upcEEndGuard = '010101';
const _addOnGap = 9;

List<int> _digits(String s) => [for (final c in s.codeUnits) c - 0x30];

void _requireDigits(String data, String name) {
  if (!isAllDigits(data)) {
    throw BarcodeException(
      BarcodeErrorKind.invalidCharacter,
      '$name accepts digits only, got "$data"',
    );
  }
}

/// Validates [data] against [length] data digits plus an optional check
/// digit and returns the full string including the check digit.
String _withCheckDigit(String data, int length, String name) {
  _requireDigits(data, name);
  if (data.length == length) {
    return '$data${gs1CheckDigit(data)}';
  }
  if (data.length == length + 1) {
    final expected = gs1CheckDigit(data.substring(0, length));
    if (data.codeUnitAt(length) - 0x30 != expected) {
      throw BarcodeException(
        BarcodeErrorKind.invalidCheckDigit,
        '$name check digit should be $expected in "$data"',
      );
    }
    return data;
  }
  throw BarcodeException(
    BarcodeErrorKind.invalidLength,
    '$name needs $length or ${length + 1} digits, got ${data.length}',
  );
}

/// Splits "main+addon" or "main addon".
(String, String?) _splitAddOn(String data) {
  final i = data.indexOf(RegExp('[+ ]'));
  if (i < 0) return (data, null);
  return (data.substring(0, i), data.substring(i + 1));
}

/// Returns the 5-digit EAN add-on checksum used to select its parity.
int ean5Checksum(String digits) {
  final d = _digits(digits);
  return (3 * (d[0] + d[2] + d[4]) + 9 * (d[1] + d[3])) % 10;
}

String _addOnPattern(String data) {
  _requireDigits(data, 'Add-on');
  final String parity;
  if (data.length == 2) {
    parity = const ['AA', 'AB', 'BA', 'BB'][int.parse(data) % 4];
  } else if (data.length == 5) {
    parity = _ean5Parity[ean5Checksum(data)];
  } else {
    throw BarcodeException(
      BarcodeErrorKind.invalidLength,
      'An add-on has 2 or 5 digits, got ${data.length}',
    );
  }
  final d = _digits(data);
  final b = StringBuffer('1011');
  for (var i = 0; i < d.length; i++) {
    if (i > 0) b.write('01');
    b.write(_digitPattern(d[i], parity[i]));
  }
  return b.toString();
}

/// Appends an optional add-on to a main EAN/UPC symbol.
BarcodeModules _build({
  required String mainPattern,
  required String text,
  required List<ModuleSpan> guards,
  required List<HriSegment> segments,
  required int quietLeft,
  required int quietRight,
  String? addOn,
}) {
  if (addOn == null) {
    return BarcodeModules.fromPattern(
      mainPattern,
      text: text,
      guards: guards,
      textSegments: segments,
      quietZoneLeft: quietLeft,
      quietZoneRight: quietRight,
    );
  }
  final addOnPattern = _addOnPattern(addOn);
  final start = mainPattern.length + _addOnGap;
  final span = ModuleSpan(start, start + addOnPattern.length);
  return BarcodeModules.fromPattern(
    '$mainPattern${'0' * _addOnGap}$addOnPattern',
    text: '$text $addOn',
    guards: guards,
    textSegments: [...segments, HriSegment(addOn, span)],
    addOn: span,
    quietZoneLeft: quietLeft,
    quietZoneRight: 5,
  );
}

String _encodeSide(List<int> digits, String parity) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    b.write(_digitPattern(digits[i], parity[i]));
  }
  return b.toString();
}

/// EAN-13 encoder (ISO/IEC 15420). Accepts 12 digits (the check digit is
/// computed) or 13 digits (the check digit is verified), optionally
/// followed by `+` or a space and a 2- or 5-digit add-on.
class Ean13Encoder extends BarcodeType {
  /// Creates an EAN-13 encoder.
  const Ean13Encoder();

  @override
  String get name => 'EAN-13';

  @override
  BarcodeModules encode(String data) {
    final (main, addOn) = _splitAddOn(data);
    final full = _withCheckDigit(main, 12, name);
    final d = _digits(full);
    final pattern = '$_normalGuard'
        '${_encodeSide(d.sublist(1, 7), _ean13Parity[d[0]])}'
        '$_centreGuard'
        '${_encodeSide(d.sublist(7), 'CCCCCC')}'
        '$_normalGuard';
    return _build(
      mainPattern: pattern,
      text: full,
      guards: const [ModuleSpan(0, 3), ModuleSpan(45, 50), ModuleSpan(92, 95)],
      segments: [
        HriSegment(full[0], const ModuleSpan(-8, -1)),
        HriSegment(full.substring(1, 7), const ModuleSpan(3, 45)),
        HriSegment(full.substring(7), const ModuleSpan(50, 92)),
      ],
      quietLeft: 11,
      quietRight: 7,
      addOn: addOn,
    );
  }
}

/// EAN-8 encoder (ISO/IEC 15420). Accepts 7 or 8 digits. Add-ons are not
/// defined for EAN-8.
class Ean8Encoder extends BarcodeType {
  /// Creates an EAN-8 encoder.
  const Ean8Encoder();

  @override
  String get name => 'EAN-8';

  @override
  BarcodeModules encode(String data) {
    final full = _withCheckDigit(data, 7, name);
    final d = _digits(full);
    final pattern = '$_normalGuard'
        '${_encodeSide(d.sublist(0, 4), 'AAAA')}'
        '$_centreGuard'
        '${_encodeSide(d.sublist(4), 'CCCC')}'
        '$_normalGuard';
    return _build(
      mainPattern: pattern,
      text: full,
      guards: const [ModuleSpan(0, 3), ModuleSpan(31, 36), ModuleSpan(64, 67)],
      segments: [
        HriSegment(full.substring(0, 4), const ModuleSpan(3, 31)),
        HriSegment(full.substring(4), const ModuleSpan(36, 64)),
      ],
      quietLeft: 7,
      quietRight: 7,
    );
  }
}

/// UPC-A encoder (ISO/IEC 15420). Accepts 11 or 12 digits, optionally with
/// an add-on. The number system and check digit bars extend like guards.
class UpcAEncoder extends BarcodeType {
  /// Creates a UPC-A encoder.
  const UpcAEncoder();

  @override
  String get name => 'UPC-A';

  @override
  BarcodeModules encode(String data) {
    final (main, addOn) = _splitAddOn(data);
    final full = _withCheckDigit(main, 11, name);
    final d = _digits(full);
    final pattern = '$_normalGuard'
        '${_encodeSide(d.sublist(0, 6), 'AAAAAA')}'
        '$_centreGuard'
        '${_encodeSide(d.sublist(6), 'CCCCCC')}'
        '$_normalGuard';
    return _build(
      mainPattern: pattern,
      text: full,
      guards: const [ModuleSpan(0, 10), ModuleSpan(45, 50), ModuleSpan(85, 95)],
      segments: [
        HriSegment(full[0], const ModuleSpan(-8, -1)),
        HriSegment(full.substring(1, 6), const ModuleSpan(10, 45)),
        HriSegment(full.substring(6, 11), const ModuleSpan(50, 85)),
        HriSegment(full[11], const ModuleSpan(96, 103)),
      ],
      quietLeft: 9,
      quietRight: 9,
      addOn: addOn,
    );
  }
}

/// Expands a UPC-E number to its 12-digit UPC-A equivalent.
///
/// Accepts 6 digits (number system 0 assumed), 7 digits (number system +
/// 6 digits) or 8 digits (with check digit, which is verified). The number
/// system must be 0 or 1. Throws [BarcodeException] otherwise.
String upcEToUpcA(String upcE) {
  _requireDigits(upcE, 'UPC-E');
  final String ns;
  final String body;
  String? check;
  switch (upcE.length) {
    case 6:
      ns = '0';
      body = upcE;
    case 7:
      ns = upcE[0];
      body = upcE.substring(1);
    case 8:
      ns = upcE[0];
      body = upcE.substring(1, 7);
      check = upcE[7];
    default:
      throw BarcodeException(
        BarcodeErrorKind.invalidLength,
        'UPC-E needs 6, 7 or 8 digits, got ${upcE.length}',
      );
  }
  if (ns != '0' && ns != '1') {
    throw BarcodeException(
      BarcodeErrorKind.invalidData,
      'UPC-E number system must be 0 or 1, got $ns',
    );
  }
  final b = body;
  final String upcA11;
  switch (b[5]) {
    case '0' || '1' || '2':
      upcA11 = '$ns${b[0]}${b[1]}${b[5]}0000${b[2]}${b[3]}${b[4]}';
    case '3':
      upcA11 = '$ns${b[0]}${b[1]}${b[2]}00000${b[3]}${b[4]}';
    case '4':
      upcA11 = '$ns${b[0]}${b[1]}${b[2]}${b[3]}00000${b[4]}';
    default:
      upcA11 = '$ns${b.substring(0, 5)}0000${b[5]}';
  }
  final expected = gs1CheckDigit(upcA11);
  if (check != null && int.parse(check) != expected) {
    throw BarcodeException(
      BarcodeErrorKind.invalidCheckDigit,
      'UPC-E check digit should be $expected in "$upcE"',
    );
  }
  return '$upcA11$expected';
}

/// Compresses a UPC-A number (11 or 12 digits) to its 8-digit UPC-E form
/// (number system, 6 digits, check digit), or returns `null` when the
/// number cannot be zero-suppressed.
///
/// Throws [BarcodeException] when [upcA] itself is invalid.
String? upcAToUpcE(String upcA) {
  final full = _withCheckDigit(upcA, 11, 'UPC-A');
  final ns = full[0];
  if (ns != '0' && ns != '1') return null;
  final m = full.substring(1, 6);
  final p = full.substring(6, 11);
  String? body;
  if ('012'.contains(m[2]) && m.endsWith('00') && p.startsWith('00')) {
    body = '${m[0]}${m[1]}${p.substring(2)}${m[2]}';
  } else if (m.endsWith('00') && p.startsWith('000')) {
    body = '${m.substring(0, 3)}${p.substring(3)}3';
  } else if (m.endsWith('0') && p.startsWith('0000')) {
    body = '${m.substring(0, 4)}${p[4]}4';
  } else if (p.startsWith('0000') && '56789'.contains(p[4])) {
    body = '$m${p[4]}';
  }
  if (body == null) return null;
  final candidate = '$ns$body${full[11]}';
  return upcEToUpcA(candidate) == full ? candidate : null;
}

/// UPC-E encoder (ISO/IEC 15420). Accepts 6, 7 or 8 digits, or an 11/12
/// digit UPC-A that can be zero-suppressed, optionally with an add-on.
class UpcEEncoder extends BarcodeType {
  /// Creates a UPC-E encoder.
  const UpcEEncoder();

  @override
  String get name => 'UPC-E';

  @override
  BarcodeModules encode(String data) {
    final (main, addOn) = _splitAddOn(data);
    _requireDigits(main, name);
    final String e8;
    if (main.length == 11 || main.length == 12) {
      final c = upcAToUpcE(main);
      if (c == null) {
        throw BarcodeException(
          BarcodeErrorKind.invalidData,
          'UPC-A "$main" cannot be compressed to UPC-E',
        );
      }
      e8 = c;
    } else {
      final a = upcEToUpcA(main);
      final ns = main.length == 6 ? '0' : main[0];
      final body = main.length == 6 ? main : main.substring(1, 7);
      e8 = '$ns$body${a[11]}';
    }
    final check = int.parse(e8[7]);
    var parity = _upcEParity[check];
    if (e8[0] == '1') {
      parity = parity.split('').map((c) => c == 'A' ? 'B' : 'A').join();
    }
    final pattern = '$_normalGuard'
        '${_encodeSide(_digits(e8.substring(1, 7)), parity)}'
        '$_upcEEndGuard';
    return _build(
      mainPattern: pattern,
      text: e8,
      guards: const [ModuleSpan(0, 3), ModuleSpan(45, 51)],
      segments: [
        HriSegment(e8[0], const ModuleSpan(-8, -1)),
        HriSegment(e8.substring(1, 7), const ModuleSpan(3, 45)),
        HriSegment(e8[7], const ModuleSpan(52, 59)),
      ],
      quietLeft: 9,
      quietRight: 7,
      addOn: addOn,
    );
  }
}

/// Stand-alone 2-digit EAN/UPC add-on.
class Ean2Encoder extends BarcodeType {
  /// Creates an EAN-2 add-on encoder.
  const Ean2Encoder();

  @override
  String get name => 'EAN-2';

  @override
  BarcodeModules encode(String data) => _standaloneAddOn(data, 2);
}

/// Stand-alone 5-digit EAN/UPC add-on.
class Ean5Encoder extends BarcodeType {
  /// Creates an EAN-5 add-on encoder.
  const Ean5Encoder();

  @override
  String get name => 'EAN-5';

  @override
  BarcodeModules encode(String data) => _standaloneAddOn(data, 5);
}

BarcodeModules _standaloneAddOn(String data, int length) {
  _requireDigits(data, 'EAN-$length');
  if (data.length != length) {
    throw BarcodeException(
      BarcodeErrorKind.invalidLength,
      'EAN-$length needs $length digits, got ${data.length}',
    );
  }
  final pattern = _addOnPattern(data);
  final span = ModuleSpan(0, pattern.length);
  return BarcodeModules.fromPattern(
    pattern,
    text: data,
    textSegments: [HriSegment(data, span)],
    addOn: span,
    quietZoneLeft: 7,
    quietZoneRight: 5,
  );
}
