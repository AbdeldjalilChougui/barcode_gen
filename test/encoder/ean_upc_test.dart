import 'package:barcode_gen/barcode_gen.dart';
import 'package:flutter_test/flutter_test.dart';

// Symbol character patterns written out by hand from ISO/IEC 15420 Table 1
// (number sets A = L, B = G, C = R), independently of the encoder tables.
const _l = {
  '0': '0001101', '1': '0011001', '2': '0010011', '3': '0111101', //
  '4': '0100011', '5': '0110001', '6': '0101111', '7': '0111011',
  '8': '0110111', '9': '0001011',
};
const _g = {
  '0': '0100111', '1': '0110011', '2': '0011011', '3': '0100001', //
  '4': '0011101', '5': '0111001', '6': '0000101', '7': '0010001',
  '8': '0001001', '9': '0010111',
};
const _r = {
  '0': '1110010', '1': '1100110', '2': '1101100', '3': '1000010', //
  '4': '1011100', '5': '1001110', '6': '1010000', '7': '1000100',
  '8': '1001000', '9': '1110100',
};

Matcher _throwsKind(BarcodeErrorKind kind) => throwsA(
      isA<BarcodeException>().having((e) => e.kind, 'kind', kind),
    );

void main() {
  group('GS1 mod-10 check digit', () {
    test('known values', () {
      expect(gs1CheckDigit('400638133393'), 1); // EAN-13 4006381333931
      expect(gs1CheckDigit('9638507'), 4); // EAN-8 96385074
      expect(gs1CheckDigit('03600029145'), 2); // UPC-A 036000291452
      expect(gs1CheckDigit('0950110153000'), 3); // GTIN-14 09501101530003
    });
    test('rejects non-digits', () {
      expect(() => gs1CheckDigit('12a'), throwsArgumentError);
    });
  });

  group('EAN-13', () {
    const enc = Ean13Encoder();

    test('4006381333931 is module-exact (first digit 4 -> LGLLGG)', () {
      final expected = '101'
          '${_l['0']}${_g['0']}${_l['6']}${_l['3']}${_g['8']}${_g['1']}'
          '01010'
          '${_r['3']}${_r['3']}${_r['3']}${_r['9']}${_r['3']}${_r['1']}'
          '101';
      final m = enc.encode('4006381333931');
      expect(m.pattern, expected);
      expect(m.moduleCount, 95);
      expect(m.text, '4006381333931');
    });

    test('computes the check digit from 12 digits', () {
      expect(enc.encode('400638133393').text, '4006381333931');
      expect(
        enc.encode('400638133393').pattern,
        enc.encode('4006381333931').pattern,
      );
    });

    test('guard bars and HRI segments follow the EAN layout', () {
      final m = enc.encode('4006381333931');
      expect(m.guards, const [
        ModuleSpan(0, 3),
        ModuleSpan(45, 50),
        ModuleSpan(92, 95),
      ]);
      expect(m.textSegments.map((s) => s.text), ['4', '006381', '333931']);
      expect(m.textSegments[0].span.end, lessThanOrEqualTo(0));
      expect(m.textSegments[1].span, const ModuleSpan(3, 45));
      expect(m.textSegments[2].span, const ModuleSpan(50, 92));
      expect(m.quietZoneLeft, 11);
      expect(m.quietZoneRight, 7);
    });

    test('invalid input', () {
      expect(() => enc.encode('4006381333932'),
          _throwsKind(BarcodeErrorKind.invalidCheckDigit));
      expect(() => enc.encode('40063813339'),
          _throwsKind(BarcodeErrorKind.invalidLength));
      expect(() => enc.encode('40063813339311'),
          _throwsKind(BarcodeErrorKind.invalidLength));
      expect(() => enc.encode('40063813339A'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
      expect(() => enc.encode(''), _throwsKind(BarcodeErrorKind.invalidLength));
    });

    test('isValid mirrors encode', () {
      expect(enc.isValid('4006381333931'), isTrue);
      expect(enc.isValid('4006381333930'), isFalse);
    });
  });

  group('EAN-8', () {
    const enc = Ean8Encoder();
    test('96385074 is module-exact', () {
      final expected = '101'
          '${_l['9']}${_l['6']}${_l['3']}${_l['8']}'
          '01010'
          '${_r['5']}${_r['0']}${_r['7']}${_r['4']}'
          '101';
      final m = enc.encode('96385074');
      expect(m.pattern, expected);
      expect(m.moduleCount, 67);
      expect(enc.encode('9638507').text, '96385074');
      expect(m.guards, const [
        ModuleSpan(0, 3),
        ModuleSpan(31, 36),
        ModuleSpan(64, 67),
      ]);
      expect(m.textSegments.map((s) => s.text), ['9638', '5074']);
      expect(m.quietZoneLeft, 7);
      expect(m.quietZoneRight, 7);
    });
    test('invalid input', () {
      expect(() => enc.encode('96385075'),
          _throwsKind(BarcodeErrorKind.invalidCheckDigit));
      expect(() => enc.encode('963850'),
          _throwsKind(BarcodeErrorKind.invalidLength));
      expect(() => enc.encode('9638 074'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
    });
  });

  group('UPC-A', () {
    const enc = UpcAEncoder();
    test('036000291452 is module-exact', () {
      final expected = '101'
          '${_l['0']}${_l['3']}${_l['6']}${_l['0']}${_l['0']}${_l['0']}'
          '01010'
          '${_r['2']}${_r['9']}${_r['1']}${_r['4']}${_r['5']}${_r['2']}'
          '101';
      final m = enc.encode('036000291452');
      expect(m.pattern, expected);
      expect(enc.encode('03600029145').text, '036000291452');
    });
    test('first and last symbol characters extend like guard bars', () {
      final m = enc.encode('036000291452');
      expect(m.guards, const [
        ModuleSpan(0, 10),
        ModuleSpan(45, 50),
        ModuleSpan(85, 95),
      ]);
      expect(m.textSegments.map((s) => s.text), ['0', '36000', '29145', '2']);
      expect(m.textSegments.first.span.end, lessThanOrEqualTo(0));
      expect(m.textSegments.last.span.start, greaterThanOrEqualTo(95));
      expect(m.quietZoneLeft, 9);
      expect(m.quietZoneRight, 9);
    });
    test('invalid input', () {
      expect(() => enc.encode('036000291453'),
          _throwsKind(BarcodeErrorKind.invalidCheckDigit));
      expect(() => enc.encode('0360002914'),
          _throwsKind(BarcodeErrorKind.invalidLength));
    });
  });

  group('UPC-E <-> UPC-A', () {
    test('expansion follows the four GS1 rules on the last digit', () {
      expect(upcEToUpcA('0123450'), '012000003455');
      expect(upcEToUpcA('0123453'), '012300000451');
      expect(upcEToUpcA('0123454'), '012340000053');
      expect(upcEToUpcA('0123456'), '012345000065');
      // Six digits assume number system 0; eight digits are checked.
      expect(upcEToUpcA('123456'), '012345000065');
      expect(upcEToUpcA('01234565'), '012345000065');
      expect(upcEToUpcA('1123456'), '112345000062');
    });

    test('expansion rejects bad input', () {
      expect(() => upcEToUpcA('01234566'),
          _throwsKind(BarcodeErrorKind.invalidCheckDigit));
      expect(() => upcEToUpcA('2123456'),
          _throwsKind(BarcodeErrorKind.invalidData));
      expect(() => upcEToUpcA('12345'),
          _throwsKind(BarcodeErrorKind.invalidLength));
    });

    test('compression is the inverse of expansion', () {
      for (final e in [
        '0123450', '0123451', '0123452', '0123453', '0123454', //
        '0123455', '0123459', '1987654', '0000000', '0100003',
      ]) {
        final a = upcEToUpcA(e);
        final back = upcAToUpcE(a);
        expect(back, isNotNull, reason: a);
        expect(upcEToUpcA(back!), a, reason: '$e -> $a -> $back');
      }
    });

    test('compression prefers the canonical form', () {
      expect(upcAToUpcE('012000003455'), '01234505');
      expect(upcAToUpcE('012300000451'), '01234531');
      expect(upcAToUpcE('012345000065'), '01234565');
    });

    test('non-compressible UPC-A returns null', () {
      expect(upcAToUpcE('036000291452'), isNull);
      expect(upcAToUpcE('212345000069'), isNull); // number system 2
    });
  });

  group('UPC-E', () {
    const enc = UpcEEncoder();
    test('01234565 is module-exact (NS 0, check 5 -> EOOEEO)', () {
      final expected = '101'
          '${_g['1']}${_l['2']}${_l['3']}${_g['4']}${_g['5']}${_l['6']}'
          '010101';
      final m = enc.encode('01234565');
      expect(m.pattern, expected);
      expect(m.moduleCount, 51);
      expect(m.text, '01234565');
    });
    test('number system 1 inverts the parity', () {
      // 1123456 -> UPC-A 112345000062, check 2 -> NS1 pattern OOEEOE.
      final expected = '101'
          '${_l['1']}${_l['2']}${_g['3']}${_g['4']}${_l['5']}${_g['6']}'
          '010101';
      expect(enc.encode('1123456').pattern, expected);
    });
    test('accepts 6, 7 and 8 digits and a compressible UPC-A', () {
      final p = enc.encode('01234565').pattern;
      expect(enc.encode('123456').pattern, p);
      expect(enc.encode('0123456').pattern, p);
      expect(enc.encode('012345000065').pattern, p);
    });
    test('layout', () {
      final m = enc.encode('01234565');
      expect(m.guards, const [ModuleSpan(0, 3), ModuleSpan(45, 51)]);
      expect(m.textSegments.map((s) => s.text), ['0', '123456', '5']);
      expect(m.quietZoneLeft, 9);
      expect(m.quietZoneRight, 7);
    });
    test('invalid input', () {
      expect(() => enc.encode('036000291452'),
          _throwsKind(BarcodeErrorKind.invalidData));
      expect(() => enc.encode('01234566'),
          _throwsKind(BarcodeErrorKind.invalidCheckDigit));
      expect(() => enc.encode('12345'),
          _throwsKind(BarcodeErrorKind.invalidLength));
      expect(() => enc.encode('12345x'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
    });
  });

  group('Add-ons', () {
    test('EAN-5 52495 (checksum 1 -> GLGLL) is module-exact', () {
      expect(ean5Checksum('52495'), 1);
      final expected = '1011'
          '${_g['5']}01${_l['2']}01${_g['4']}01${_l['9']}01${_l['5']}';
      final m = const Ean5Encoder().encode('52495');
      expect(m.pattern, expected);
      expect(m.moduleCount, 47);
    });
    test('EAN-2 parity follows value mod 4', () {
      expect(const Ean2Encoder().encode('12').pattern,
          '1011${_l['1']}01${_l['2']}'); // 12 % 4 = 0 -> LL
      expect(const Ean2Encoder().encode('05').pattern,
          '1011${_l['0']}01${_g['5']}'); // 1 -> LG
      expect(const Ean2Encoder().encode('34').pattern,
          '1011${_g['3']}01${_l['4']}'); // 2 -> GL
      expect(const Ean2Encoder().encode('99').pattern,
          '1011${_g['9']}01${_g['9']}'); // 3 -> GG
    });
    test('add-on attached to EAN-13 after a 9-module gap', () {
      final m = const Ean13Encoder().encode('4006381333931+12');
      final main = const Ean13Encoder().encode('4006381333931');
      final addon = const Ean2Encoder().encode('12');
      expect(m.pattern, '${main.pattern}${'0' * 9}${addon.pattern}');
      expect(m.addOn, const ModuleSpan(104, 124));
      expect(m.text, '4006381333931 12');
      expect(m.textSegments.last.text, '12');
      expect(m.textSegments.last.span, const ModuleSpan(104, 124));
      expect(m.quietZoneRight, 5);
      // A space separator is accepted too.
      expect(
          const Ean13Encoder().encode('4006381333931 12').pattern, m.pattern);
    });
    test('add-on on UPC-A and UPC-E', () {
      expect(const UpcAEncoder().encode('036000291452 52495').addOn,
          const ModuleSpan(104, 151));
      expect(const UpcEEncoder().encode('01234565+12').addOn,
          const ModuleSpan(60, 80));
    });
    test('invalid add-ons', () {
      expect(() => const Ean13Encoder().encode('4006381333931+123'),
          _throwsKind(BarcodeErrorKind.invalidLength));
      expect(() => const Ean5Encoder().encode('5249A'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
      expect(() => const Ean2Encoder().encode('1'),
          _throwsKind(BarcodeErrorKind.invalidLength));
      expect(() => const Ean8Encoder().encode('96385074+12'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
    });
  });

  group('BarcodeType factories', () {
    test('return the matching encoders', () {
      expect(const BarcodeType.ean13(), isA<Ean13Encoder>());
      expect(const BarcodeType.ean8(), isA<Ean8Encoder>());
      expect(const BarcodeType.upcA(), isA<UpcAEncoder>());
      expect(const BarcodeType.upcE(), isA<UpcEEncoder>());
      expect(const BarcodeType.ean2(), isA<Ean2Encoder>());
      expect(const BarcodeType.ean5(), isA<Ean5Encoder>());
      expect(const BarcodeType.ean13().name, 'EAN-13');
    });
  });
}
