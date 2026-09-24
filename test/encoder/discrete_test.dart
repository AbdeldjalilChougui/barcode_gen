import 'package:barcode_gen/barcode_gen.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher _throwsKind(BarcodeErrorKind kind) => throwsA(
      isA<BarcodeException>().having((e) => e.kind, 'kind', kind),
    );

void main() {
  group('Code 39 (ISO/IEC 16388)', () {
    test('"A" is module-exact with a 3:1 wide/narrow ratio', () {
      final m = const Code39Encoder().encode('A');
      // * = nwnnwnwnn, A = wnnnnwnnw, separated by a narrow gap.
      expect(m.widths.join(), '131131311' '1' '311113113' '1' '131131311');
      expect(m.text, 'A');
    });

    test('every character is 9 elements with exactly 3 wide', () {
      for (final c
          in '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. \$/+%'.split('')) {
        final w = const Code39Encoder().encode(c).widths;
        final char = w.sublist(10, 19);
        expect(char.where((x) => x == 3), hasLength(3), reason: c);
        expect(char.fold<int>(0, (a, b) => a + b), 15, reason: c);
      }
    });

    test('mod-43 check character', () {
      expect(code39CheckCharacter('CODE39'), 'W'); // 75 mod 43 = 32
      expect(code39CheckCharacter('ABC123'), r'$'); // 39 -> $
      final with_ = const Code39Encoder(checkDigit: true).encode('CODE39');
      final plain = const Code39Encoder().encode('CODE39W');
      expect(with_.widths, plain.widths);
      expect(with_.text, 'CODE39');
    });

    test('full ASCII expansion', () {
      expect(code39FullAscii('a'), '+A');
      expect(code39FullAscii('Ab-1'), 'A+B-1');
      expect(code39FullAscii('\x00\x01\x1b\x7f'), '%U\$A%A%T');
      expect(code39FullAscii('!@[`{'), '/A%V%K%W%P');
      expect(code39FullAscii(':;<=>?'), '/Z%F%G%H%I%J');
      final m = const Code39Encoder(fullAscii: true).encode('ab');
      expect(m.widths, const Code39Encoder().encode('+A+B').widths);
      expect(m.text, 'ab');
    });

    test('invalid input', () {
      expect(() => const Code39Encoder().encode('abc'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
      expect(() => const Code39Encoder().encode('A*B'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
      expect(() => const Code39Encoder().encode(''),
          _throwsKind(BarcodeErrorKind.invalidLength));
      expect(() => const Code39Encoder(fullAscii: true).encode('é'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
    });
  });

  group('Code 93', () {
    test('check characters C and K for WIKIPEDIA', () {
      // C: weights 1..20 from the right: 946 mod 47 = 6 -> '6'.
      // K: weights 1..15 including C: 1120 mod 47 = 39 -> '\$'.
      expect(code93CheckValues('WIKIPEDIA'), [6, 39]);
    });

    test('layout: start, data, C, K, stop and termination bar', () {
      final m = const Code93Encoder().encode('WIKIPEDIA');
      expect(m.moduleCount, 9 * (9 + 4) + 1);
      final w = m.widths;
      expect(w.sublist(0, 6).join(), '111141'); // start
      expect(w.sublist(6, 12).join(), '112122'); // W
      expect(w.sublist(w.length - 7).join(), '1111411'); // stop + bar
      expect(m.text, 'WIKIPEDIA');
    });

    test('every symbol is 9 modules, 3 bars and 3 spaces, widths 1-4', () {
      final m = const Code93Encoder()
          .encode('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. \$/+%');
      final w = m.widths;
      for (var i = 0; i + 6 <= w.length - 1; i += 6) {
        final s = w.sublist(i, i + 6);
        expect(s.fold<int>(0, (a, b) => a + b), 9, reason: 'symbol ${i ~/ 6}');
        expect(s.every((x) => x >= 1 && x <= 4), isTrue);
      }
    });

    test('full ASCII via shift characters', () {
      // 'a' -> (+)A: values 46 and 10.
      final lower = const Code93Encoder().encode('a');
      expect(lower.moduleCount, 9 * (2 + 4) + 1);
      expect(lower.text, 'a');
      // C = (10*1 + 46*2) mod 47 = 8; K = (8 + 10*2 + 46*3) mod 47 = 25.
      expect(code93CheckValues('a'), [8, 25]);
    });

    test('invalid input', () {
      expect(() => const Code93Encoder().encode(''),
          _throwsKind(BarcodeErrorKind.invalidLength));
      expect(() => const Code93Encoder().encode('ü'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
    });
  });

  group('ITF (ISO/IEC 16390) and ITF-14', () {
    test('"12" is module-exact', () {
      // start nnnn, 1 in bars (wnnnw), 2 in spaces (nwnnw), stop wnn.
      expect(const ItfEncoder().encode('12').widths.join(),
          '1111' '3113111133' '311');
    });

    test('odd length or non-digits are rejected', () {
      expect(() => const ItfEncoder().encode('123'),
          _throwsKind(BarcodeErrorKind.invalidLength));
      expect(() => const ItfEncoder().encode(''),
          _throwsKind(BarcodeErrorKind.invalidLength));
      expect(() => const ItfEncoder().encode('12A4'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
    });

    test('ITF-14 computes and verifies the GS1 check digit', () {
      expect(
          const Itf14Encoder().encode('1540014128876').text, '15400141288763');
      expect(() => const Itf14Encoder().encode('15400141288764'),
          _throwsKind(BarcodeErrorKind.invalidCheckDigit));
      expect(() => const Itf14Encoder().encode('154001412887'),
          _throwsKind(BarcodeErrorKind.invalidLength));
    });

    test('ITF-14 has frame bearer bars by default, configurable', () {
      final m = const Itf14Encoder().encode('15400141288763');
      expect(m.bearerBars, BearerBars.frame);
      expect(m.bearerThickness, greaterThan(0));
      expect(
        const Itf14Encoder(bearerBars: BearerBars.horizontal)
            .encode('15400141288763')
            .bearerBars,
        BearerBars.horizontal,
      );
      expect(const ItfEncoder().encode('12').bearerBars, BearerBars.none);
      expect(
        const ItfEncoder(bearerBars: BearerBars.horizontal)
            .encode('12')
            .bearerBars,
        BearerBars.horizontal,
      );
      expect(m.moduleCount, 4 + 7 * 18 + 5);
    });
  });

  group('Codabar', () {
    test('"1" with A/B start/stop is module-exact', () {
      // A = nnwwnwn, 1 = nnnnwwn, B = nwnwnnw, narrow gaps between.
      expect(const CodabarEncoder().encode('1').widths.join(),
          '1133131' '1' '1111331' '1' '1313113');
    });

    test('start and stop characters are configurable', () {
      final m = const CodabarEncoder(start: 'C', stop: 'D').encode('1');
      expect(m.widths.sublist(0, 7).join(), '1113133'); // C = nnnwnww
      expect(m.widths.sublist(m.widths.length - 7).join(), '1113331');
      expect(m.text, '1');
      expect(
        const CodabarEncoder(showStartStop: true).encode('1').text,
        'A1B',
      );
    });

    test('all data characters encode', () {
      final m = const CodabarEncoder().encode(r'0123456789-$:/.+');
      expect(m.widths.length, 7 * 18 + 17);
    });

    test('invalid input', () {
      expect(() => const CodabarEncoder().encode('12A3'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
      expect(() => const CodabarEncoder().encode(''),
          _throwsKind(BarcodeErrorKind.invalidLength));
      expect(() => const CodabarEncoder(start: 'E').encode('1'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
    });
  });

  group('MSI Plessey', () {
    test('Luhn mod-10 check digit', () {
      expect(msiMod10('1234567'), 4);
      expect(msiMod10('12345674'), 1);
    });

    test('"1" without check digit is module-exact', () {
      // start 110, 0001 -> 100 100 100 110, stop 1001.
      expect(
        const MsiEncoder(checkDigit: MsiCheckDigit.none).encode('1').pattern,
        '110' '100100100110' '1001',
      );
    });

    test('check digit modes', () {
      expect(const MsiEncoder().encode('1234567').text, '12345674');
      expect(
        const MsiEncoder(checkDigit: MsiCheckDigit.mod1010)
            .encode('1234567')
            .text,
        '123456741',
      );
      expect(
        const MsiEncoder(checkDigit: MsiCheckDigit.none).encode('1234567').text,
        '1234567',
      );
      expect(const MsiEncoder().encode('1234567').moduleCount, 3 + 8 * 12 + 4);
    });

    test('invalid input', () {
      expect(() => const MsiEncoder().encode('12A'),
          _throwsKind(BarcodeErrorKind.invalidCharacter));
      expect(() => const MsiEncoder().encode(''),
          _throwsKind(BarcodeErrorKind.invalidLength));
    });
  });

  test('BarcodeType factories', () {
    expect(const BarcodeType.code39(), isA<Code39Encoder>());
    expect(const BarcodeType.code93(), isA<Code93Encoder>());
    expect(const BarcodeType.itf(), isA<ItfEncoder>());
    expect(const BarcodeType.itf14(), isA<Itf14Encoder>());
    expect(const BarcodeType.codabar(), isA<CodabarEncoder>());
    expect(const BarcodeType.msi(), isA<MsiEncoder>());
  });
}
