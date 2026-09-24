import 'barcode_exception.dart';
import 'barcode_modules.dart';
import 'barcode_type.dart';
import 'check_digits.dart';
import 'code128.dart';

/// One GS1 element: an Application Identifier and its data field.
class Gs1Element {
  /// Creates an element for [ai] carrying [value].
  const Gs1Element(this.ai, this.value);

  /// The Application Identifier, e.g. `01`.
  final String ai;

  /// The data field, without the AI.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is Gs1Element && other.ai == ai && other.value == value;

  @override
  int get hashCode => Object.hash(ai, value);

  @override
  String toString() => '($ai)$value';
}

/// Format of an AI data field.
class _AiFormat {
  const _AiFormat(this.min, this.max,
      {this.numeric = false, this.check = false});
  final int min;
  final int max;
  final bool numeric;

  /// Last digit is a GS1 mod-10 check digit over the field.
  final bool check;
}

const _n6 = _AiFormat(6, 6, numeric: true);
const _x20 = _AiFormat(1, 20);
const _x30 = _AiFormat(1, 30);

/// Formats of commonly used AIs, from the GS1 General Specifications
/// section 3 (AI definitions). Weight/measure AIs 31nn-36nn are handled by
/// prefix in [_formatFor].
const _formats = <String, _AiFormat>{
  '00': _AiFormat(18, 18, numeric: true, check: true),
  '01': _AiFormat(14, 14, numeric: true, check: true),
  '02': _AiFormat(14, 14, numeric: true, check: true),
  '10': _x20,
  '11': _n6,
  '12': _n6,
  '13': _n6,
  '15': _n6,
  '16': _n6,
  '17': _n6,
  '20': _AiFormat(2, 2, numeric: true),
  '21': _x20,
  '22': _x20,
  '30': _AiFormat(1, 8, numeric: true),
  '37': _AiFormat(1, 8, numeric: true),
  '240': _x30,
  '241': _x30,
  '242': _AiFormat(1, 6, numeric: true),
  '243': _x20,
  '250': _x30,
  '251': _x30,
  '254': _x20,
  '400': _x30,
  '401': _x30,
  '402': _AiFormat(17, 17, numeric: true, check: true),
  '403': _x30,
  '410': _AiFormat(13, 13, numeric: true, check: true),
  '411': _AiFormat(13, 13, numeric: true, check: true),
  '412': _AiFormat(13, 13, numeric: true, check: true),
  '413': _AiFormat(13, 13, numeric: true, check: true),
  '414': _AiFormat(13, 13, numeric: true, check: true),
  '415': _AiFormat(13, 13, numeric: true, check: true),
  '416': _AiFormat(13, 13, numeric: true, check: true),
  '417': _AiFormat(13, 13, numeric: true, check: true),
  '420': _x20,
  '422': _AiFormat(3, 3, numeric: true),
  '424': _AiFormat(3, 3, numeric: true),
  '426': _AiFormat(3, 3, numeric: true),
  '7001': _AiFormat(13, 13, numeric: true),
  '7002': _x30,
  '7003': _AiFormat(10, 10, numeric: true),
  '8001': _AiFormat(14, 14, numeric: true),
  '8002': _x20,
  '8004': _x30,
  '8005': _AiFormat(6, 6, numeric: true),
  '8012': _x20,
  '8020': _AiFormat(1, 25),
  '8200': _AiFormat(1, 70),
  '90': _x30,
  '91': _AiFormat(1, 90),
  '92': _AiFormat(1, 90),
  '93': _AiFormat(1, 90),
  '94': _AiFormat(1, 90),
  '95': _AiFormat(1, 90),
  '96': _AiFormat(1, 90),
  '97': _AiFormat(1, 90),
  '98': _AiFormat(1, 90),
  '99': _AiFormat(1, 90),
};

/// Element strings whose total length (AI + data) is predefined, keyed by
/// the first two AI digits (GS1 General Specifications, "element strings
/// with predefined length"). Only these may be followed by another element
/// without an FNC1 separator.
const _predefinedLength = <String, int>{
  '00': 20, '01': 16, '02': 16, '03': 16, '04': 18, //
  '11': 8, '12': 8, '13': 8, '14': 8, '15': 8, '16': 8, '17': 8, '18': 8,
  '19': 8, '20': 4, '31': 10, '32': 10, '33': 10, '34': 10, '35': 10,
  '36': 10, '41': 16,
};

_AiFormat? _formatFor(String ai) {
  final f = _formats[ai];
  if (f != null) return f;
  if (ai.length == 4) {
    final p = int.parse(ai.substring(0, 3));
    if ((p >= 310 && p <= 316) ||
        (p >= 320 && p <= 329) ||
        (p >= 330 && p <= 337) ||
        (p >= 340 && p <= 349) ||
        (p >= 350 && p <= 357) ||
        (p >= 360 && p <= 369)) {
      return _n6;
    }
  }
  return null;
}

// GS1 AI encodable character set 82.
bool _isCset82(int c) =>
    c == 0x21 ||
    c == 0x22 ||
    (c >= 0x25 && c <= 0x3F) ||
    (c >= 0x41 && c <= 0x5A) ||
    c == 0x5F ||
    (c >= 0x61 && c <= 0x7A);

final _aiPattern = RegExp(r'\((\d{2,4})\)');

/// Parses a GS1 element string written with parenthesised AIs, such as
/// `(01)09501101530003(17)250101(10)ABC123`, and validates every field.
///
/// Unknown AIs are rejected unless [allowUnknownAis] is true; they are then
/// only checked against GS1 character set 82.
///
/// A `(` followed by 2-4 digits and `)` always starts a new element, so data
/// fields cannot contain that sequence.
List<Gs1Element> parseGs1(String input, {bool allowUnknownAis = false}) {
  final matches = _aiPattern.allMatches(input).toList();
  if (matches.isEmpty || matches.first.start != 0) {
    throw BarcodeException(
      BarcodeErrorKind.invalidData,
      'GS1 data must start with a parenthesised AI, e.g. (01): "$input"',
    );
  }
  final out = <Gs1Element>[];
  for (var k = 0; k < matches.length; k++) {
    final ai = matches[k].group(1)!;
    final end = k + 1 < matches.length ? matches[k + 1].start : input.length;
    final value = input.substring(matches[k].end, end);
    _validate(ai, value, allowUnknownAis);
    out.add(Gs1Element(ai, value));
  }
  return out;
}

void _validate(String ai, String value, bool allowUnknown) {
  final f = _formatFor(ai);
  if (f == null && !allowUnknown) {
    throw BarcodeException(
      BarcodeErrorKind.invalidData,
      'Unknown or unsupported Application Identifier ($ai)',
    );
  }
  for (final c in value.codeUnits) {
    if (!_isCset82(c) || (f != null && f.numeric && (c < 0x30 || c > 0x39))) {
      throw BarcodeException(
        BarcodeErrorKind.invalidCharacter,
        'Invalid character "${String.fromCharCode(c)}" in AI ($ai)',
      );
    }
  }
  final min = f?.min ?? 1;
  final max = f?.max ?? 90;
  if (value.length < min || value.length > max) {
    throw BarcodeException(
      BarcodeErrorKind.invalidLength,
      'AI ($ai) needs ${min == max ? '$min' : '$min-$max'} characters, '
      'got ${value.length}',
    );
  }
  if (f != null && f.check) {
    final expected = gs1CheckDigit(value.substring(0, value.length - 1));
    if (value.codeUnitAt(value.length - 1) - 0x30 != expected) {
      throw BarcodeException(
        BarcodeErrorKind.invalidCheckDigit,
        'AI ($ai) check digit should be $expected in "$value"',
      );
    }
  }
}

/// Serialises [elements] for Code 128: a leading FNC1, then AI + data,
/// with an FNC1 separator after every element that is not of predefined
/// length and is not last. FNC1 is written as [Code128Encoder.fnc1].
String gs1ToCode128Data(List<Gs1Element> elements) {
  final b = StringBuffer(Code128Encoder.fnc1);
  for (var i = 0; i < elements.length; i++) {
    final e = elements[i];
    b
      ..write(e.ai)
      ..write(e.value);
    final predefined = _predefinedLength[e.ai.substring(0, 2)];
    if (i < elements.length - 1 && predefined == null) {
      b.write(Code128Encoder.fnc1);
    }
  }
  return b.toString();
}

/// GS1-128 encoder: Code 128 with a leading FNC1 and GS1 element strings
/// (GS1 General Specifications section 5.4). Input uses parenthesised AIs,
/// e.g. `(01)09501101530003(17)250101(10)ABC123`, which is also the HRI.
class Gs1128Encoder extends BarcodeType {
  /// Creates a GS1-128 encoder. See [parseGs1] for [allowUnknownAis].
  const Gs1128Encoder({this.allowUnknownAis = false});

  /// Accept AIs that are not in the built-in table.
  final bool allowUnknownAis;

  @override
  String get name => 'GS1-128';

  /// Full Code 128 value sequence for [data].
  List<int> codewords(String data) => const Code128Encoder().codewords(
        gs1ToCode128Data(parseGs1(data, allowUnknownAis: allowUnknownAis)),
      );

  @override
  BarcodeModules encode(String data) {
    final elements = parseGs1(data, allowUnknownAis: allowUnknownAis);
    return Code128Encoder.modulesFromCodewords(
      const Code128Encoder().codewords(gs1ToCode128Data(elements)),
      elements.join(),
    );
  }
}
