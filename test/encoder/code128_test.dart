import 'package:barcode_gen/barcode_gen.dart';
import 'package:barcode_gen/src/encoder/code128.dart' show code128Patterns;
import 'package:flutter_test/flutter_test.dart';

Matcher _throwsKind(BarcodeErrorKind kind) => throwsA(
      isA<BarcodeException>().having((e) => e.kind, 'kind', kind),
    );

const _fnc1 = Code128Encoder.fnc1;

void main() {
  group('Code 128 symbol table (ISO/IEC 15417 Table 1)', () {
    test('107 symbols: 11 modules each, 13 for stop, even bar modules', () {
      expect(code128Patterns, hasLength(107));
      for (var v = 0; v < 107; v++) {
        final w = code128Patterns[v].split('').map(int.parse).toList();
        final total = w.fold<int>(0, (a, b) => a + b);
        expect(total, v == 106 ? 13 : 11, reason: 'value $v');
        var bars = 0;
        for (var i = 0; i < w.length; i += 2) {
          bars += w[i];
        }
        expect(bars.isEven, isTrue, reason: 'value $v bar modules $bars');
        expect(w.every((x) => x >= 1 && x <= 4), isTrue, reason: 'value $v');
      }
      expect(code128Patterns.toSet(), hasLength(107));
    });

    test('spot values', () {
      expect(code128Patterns[0], '212222');
      expect(code128Patterns[103], '211412'); // Start A
      expect(code128Patterns[104], '211214'); // Start B
      expect(code128Patterns[105], '211232'); // Start C
      expect(code128Patterns[106], '2331112'); // Stop
    });
  });

  group('Code 128 code-set selection and check symbol', () {
    const enc = Code128Encoder();

    test('all digits, even count: Start C only', () {
      // check = (105 + 1*12 + 2*34 + 3*56 + 4*78) mod 103 = 665 mod 103 = 47
      expect(enc.codewords('12345678'), [105, 12, 34, 56, 78, 47, 106]);
    });

    test('"Wikipedia" in code set B, check symbol 88', () {
      // 104 + 55 + 2*73 + 3*75 + 4*73 + 5*80 + 6*69 + 7*68 + 8*73 + 9*65
      // = 3281; 3281 mod 103 = 88.
      expect(enc.codewords('Wikipedia'),
          [104, 55, 73, 75, 73, 80, 69, 68, 73, 65, 88, 106]);
    });

    test('B -> C -> B for a digit run in the middle', () {
      // 104+65+132+297+48+170+336+546+800+603+680 = 3781; mod 103 = 73.
      expect(enc.codewords('ab12345678cd'),
          [104, 65, 66, 99, 12, 34, 56, 78, 100, 67, 68, 73, 106]);
    });

    test('Shift for a single control character inside set B', () {
      // 104 + 65 + 2*98 + 3*74 + 4*66 = 851; 851 mod 103 = 27.
      expect(enc.codewords('a\nb'), [104, 65, 98, 74, 66, 27, 106]);
    });

    test('Start A when the data begins with control characters', () {
      // 103 + 73 + 2*33 + 3*34 = 344; 344 mod 103 = 35.
      expect(enc.codewords('\tAB'), [103, 73, 33, 34, 35, 106]);
    });

    test('short digit runs stay in B', () {
      expect(enc.codewords('a12b'), [
        104,
        65,
        17,
        18,
        66,
        _check(104, [65, 17, 18, 66]),
        106
      ]);
    });

    test('odd digit count uses the minimum number of symbols', () {
      // Either "1 CodeC 23 45" or "12 34 CodeB 5": 4 data symbols.
      expect(enc.codewords('12345'), hasLength(1 + 4 + 2));
      expect(enc.codewords('1234567'), hasLength(1 + 5 + 2));
    });

    test('FNC1 is value 102 in any code set', () {
      expect(enc.codewords('${_fnc1}12'), [
        105,
        102,
        12,
        _check(105, [102, 12]),
        106
      ]);
    });

    test('shortest encoding is never longer than pure set B', () {
      for (final s in [
        'HELLO world 123',
        '0000000000x',
        'x0000000000',
        'AB\x01\x02cd',
        '1a2b3c4d',
        '999999a99999',
      ]) {
        final cw = enc.codewords(s);
        expect(cw.length - 3, lessThanOrEqualTo(s.length + 2), reason: s);
      }
    });

    test('check symbol matches the weighted sum for arbitrary data', () {
      for (final s in ['Code 128', 'abc\x7f', '1234abcd5678', '\x00\x1f']) {
        final cw = enc.codewords(s);
        final data = cw.sublist(1, cw.length - 2);
        expect(cw[cw.length - 2], _check(cw.first, data), reason: s);
        expect(cw.last, 106);
      }
    });

    test('module-exact output for 12345678', () {
      final m = enc.encode('12345678');
      expect(
        m.widths.join(),
        '211232' '112232' '131123' '331121' '241112' '133121' '2331112',
      );
      expect(m.moduleCount, 11 * 6 + 13);
      expect(m.text, '12345678');
      expect(m.quietZoneLeft, 10);
      expect(m.quietZoneRight, 10);
    });

    test('invalid input', () {
      expect(() => enc.encode(''), _throwsKind(BarcodeErrorKind.invalidLength));
      expect(() => enc.encode('café'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
      expect(() => enc.encode('\u{1F600}'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
    });
  });

  group('GS1 element strings', () {
    test('parses parenthesised AIs', () {
      final e = parseGs1('(01)09501101530003(17)250101(10)ABC123');
      expect(e.map((x) => x.ai), ['01', '17', '10']);
      expect(e.map((x) => x.value), ['09501101530003', '250101', 'ABC123']);
    });

    test('FNC1 separator only after variable-length AIs that are not last', () {
      expect(
        gs1ToCode128Data(parseGs1('(01)09501101530003(17)250101(10)ABC123')),
        '${_fnc1}01095011015300031725010110ABC123',
      );
      expect(
        gs1ToCode128Data(parseGs1('(10)ABC(17)250101')),
        '${_fnc1}10ABC${_fnc1}17250101',
      );
      // AI 402 is fixed length but not in the predefined-length table,
      // so it still needs a separator.
      expect(
        gs1ToCode128Data(parseGs1('(402)12345678901234560(21)X')),
        '${_fnc1}40212345678901234560${_fnc1}21X',
      );
    });

    test('invalid element strings', () {
      expect(() => parseGs1('(01)09501101530004'),
          _throwsKind(BarcodeErrorKind.invalidCheckDigit));
      expect(() => parseGs1('(01)0950110153000'),
          _throwsKind(BarcodeErrorKind.invalidLength));
      expect(() => parseGs1('(17)25010A'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
      expect(() => parseGs1('(10)ABCDEFGHIJKLMNOPQRSTU'),
          _throwsKind(BarcodeErrorKind.invalidLength));
      expect(
          () => parseGs1('(10)'), _throwsKind(BarcodeErrorKind.invalidLength));
      expect(() => parseGs1('(10)AB~'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
      expect(
          () => parseGs1('(23)123'), _throwsKind(BarcodeErrorKind.invalidData));
      expect(() => parseGs1('0109501101530003'),
          _throwsKind(BarcodeErrorKind.invalidData));
      expect(() => parseGs1(''), _throwsKind(BarcodeErrorKind.invalidData));
    });

    test('unknown AIs can be allowed explicitly', () {
      final e = parseGs1('(23)123(10)A', allowUnknownAis: true);
      expect(e.map((x) => x.ai), ['23', '10']);
      expect(gs1ToCode128Data(e), '${_fnc1}23123${_fnc1}10A');
    });
  });

  group('GS1-128', () {
    const enc = Gs1128Encoder();

    test('codewords start with Start C, FNC1 and the digit run in set C', () {
      final cw = enc.codewords('(01)09501101530003(17)250101(10)ABC123');
      expect(cw.sublist(0, 15),
          [105, 102, 1, 9, 50, 11, 1, 53, 0, 3, 17, 25, 1, 1, 10]);
      expect(cw[15], 100); // Code B for "ABC"
      expect(cw.sublist(16, 19), [33, 34, 35]);
      expect(cw.last, 106);
      final data = cw.sublist(1, cw.length - 2);
      expect(cw[cw.length - 2], _check(105, data));
    });

    test('HRI keeps the parentheses', () {
      final m = enc.encode('(01)09501101530003(17)250101(10)ABC123');
      expect(m.text, '(01)09501101530003(17)250101(10)ABC123');
    });

    test('invalid input is reported', () {
      expect(() => enc.encode('(01)09501101530004'),
          _throwsKind(BarcodeErrorKind.invalidCheckDigit));
    });
  });

  test('BarcodeType factories', () {
    expect(const BarcodeType.code128(), isA<Code128Encoder>());
    expect(const BarcodeType.gs1128(), isA<Gs1128Encoder>());
    expect(const BarcodeType.gs1128().name, 'GS1-128');
  });
}

int _check(int start, List<int> data) {
  var sum = start;
  for (var i = 0; i < data.length; i++) {
    sum += (i + 1) * data[i];
  }
  return sum % 103;
}
