import 'package:barcode_gen/barcode_gen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ean = const Ean13Encoder().encode('4006381333931');

  group('fitModulePixels', () {
    test('uses whole device pixels per module', () {
      expect(fitModulePixels(226, 1, 113), 2);
      expect(fitModulePixels(300, 2.75, 113), 7); // floor(825 / 113)
      expect(fitModulePixels(10, 1, 113), 1); // never below one pixel
    });
  });

  group('BarcodeLayout', () {
    test('EAN-13 geometry with quiet zones and HRI below', () {
      final l = BarcodeLayout.compute(
        modules: ean,
        moduleWidth: 2,
        height: 100,
        textHeight: 12,
      );
      expect(l.width, (11 + 95 + 7) * 2);
      expect(l.height, 100);
      expect(l.symbolLeft, 22);
      final first = l.bars.first;
      expect(first.left, 22);
      expect(first.width, 2);
      expect(first.top, 0);
      // Guard bars extend half the text height below the others.
      expect(first.bottom, 94);
      final normal = l.bars[2]; // first data bar after the start guard
      expect(normal.bottom, 88);
      expect(l.texts.map((t) => t.text), ['4', '006381', '333931']);
      expect(l.texts.first.centerX, 22 + (-8 + -1) / 2 * 2);
      expect(l.texts.first.top, 88);
    });

    test('bars are merged runs, one rect per bar', () {
      final l = BarcodeLayout.compute(modules: ean, moduleWidth: 1, height: 50);
      expect(l.bars, hasLength(ean.bars.length));
    });

    test('rect edges fall on device pixels when snapped', () {
      const dpr = 2.75;
      final px = fitModulePixels(300, dpr, 113);
      final l = BarcodeLayout.compute(
        modules: ean,
        moduleWidth: px / dpr,
        height: 80,
        availableWidth: 300,
        devicePixelRatio: dpr,
      );
      for (final r in l.bars) {
        final left = r.left * dpr;
        final right = (r.left + r.width) * dpr;
        expect((left - left.round()).abs(), lessThan(1e-6));
        expect((right - right.round()).abs(), lessThan(1e-6));
      }
      // Centred in the available width.
      expect(l.width, 300);
      expect(l.symbolLeft, greaterThan(11 * px / dpr - 1e-9));
    });

    test('no quiet zone and no text: bars span the full height from x 0', () {
      final m = const Code128Encoder().encode('ABC');
      final l = BarcodeLayout.compute(
        modules: m,
        moduleWidth: 1,
        height: 40,
        quietZoneLeft: 0,
        quietZoneRight: 0,
      );
      expect(l.bars.first.left, 0);
      expect(l.width, m.moduleCount);
      expect(l.bars.every((b) => b.top == 0 && b.bottom == 40), isTrue);
      expect(l.texts, isEmpty);
    });

    test('text overhanging the quiet zone widens the margin', () {
      final m = const UpcAEncoder().encode('036000291452');
      final l = BarcodeLayout.compute(
        modules: m,
        moduleWidth: 1,
        height: 60,
        textHeight: 10,
        quietZoneLeft: 0,
        quietZoneRight: 0,
      );
      expect(l.symbolLeft, 8);
      expect(l.width, 8 + 95 + 8);
    });

    test('HRI above puts text first and bars below it', () {
      final m = const Code128Encoder().encode('ABC');
      final l = BarcodeLayout.compute(
        modules: m,
        moduleWidth: 1,
        height: 60,
        textHeight: 10,
        hriPosition: HriPosition.above,
      );
      expect(l.texts.single.top, 0);
      expect(l.bars.first.top, greaterThanOrEqualTo(10));
      expect(l.bars.first.bottom, 60);
    });

    test('single-line HRI layout ignores EAN segments', () {
      final l = BarcodeLayout.compute(
        modules: ean,
        moduleWidth: 1,
        height: 60,
        textHeight: 10,
        hriLayout: HriLayout.singleLine,
      );
      expect(l.texts.single.text, '4006381333931');
      expect(l.bars.every((b) => b.bottom == 50), isTrue);
    });

    test('add-on bars start below the add-on text', () {
      final m = const Ean13Encoder().encode('4006381333931+12');
      final l = BarcodeLayout.compute(
        modules: m,
        moduleWidth: 1,
        height: 60,
        textHeight: 10,
      );
      final addOnBars =
          l.bars.where((b) => b.left >= l.symbolLeft + m.addOn!.start);
      expect(addOnBars, isNotEmpty);
      expect(addOnBars.every((b) => b.top >= 10), isTrue);
      expect(l.texts.last.text, '12');
      expect(l.texts.last.top, 0);
    });

    test('ITF-14 frame bearer bars surround the quiet zones', () {
      final m = const Itf14Encoder().encode('15400141288763');
      final l = BarcodeLayout.compute(modules: m, moduleWidth: 1, height: 60);
      expect(l.bearers, hasLength(4));
      final t = m.bearerThickness.toDouble();
      expect(l.width, t + 10 + m.moduleCount + 10 + t);
      expect(l.bars.first.top, t);
      expect(l.bars.first.bottom, 60 - t);
    });
  });
}
