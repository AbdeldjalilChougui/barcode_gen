import 'package:barcode_gen/barcode_gen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BarcodeModules', () {
    test('expands widths into a bar-first pattern', () {
      final m = BarcodeModules(widths: const [1, 2, 3, 1], text: 'x');
      expect(m.pattern, '1001110');
      expect(m.moduleCount, 7);
      expect(m.bits, [true, false, false, true, true, true, false]);
    });

    test('fromPattern round-trips', () {
      final m = BarcodeModules.fromPattern('1101000111', text: 'y');
      expect(m.widths, [2, 1, 1, 3, 3]);
      expect(m.pattern, '1101000111');
    });

    test('rejects a pattern that starts with a space or has zero widths', () {
      expect(() => BarcodeModules.fromPattern('01', text: ''),
          throwsArgumentError);
      expect(() => BarcodeModules(widths: const [1, 0, 1], text: ''),
          throwsArgumentError);
    });

    test('bars lists the module span of every bar', () {
      final m = BarcodeModules(widths: const [1, 2, 3, 1, 1], text: '');
      expect(
          m.bars, const [ModuleSpan(0, 1), ModuleSpan(3, 6), ModuleSpan(7, 8)]);
    });

    test('widths list is unmodifiable', () {
      final m = BarcodeModules(widths: [1, 1, 1], text: '');
      expect(() => m.widths.add(1), throwsUnsupportedError);
    });

    test('isGuard reports modules inside guard spans', () {
      final m = BarcodeModules.fromPattern('10101',
          text: '', guards: const [ModuleSpan(0, 2)]);
      expect(m.isGuard(0), isTrue);
      expect(m.isGuard(1), isTrue);
      expect(m.isGuard(2), isFalse);
    });
  });
}
