import 'dart:ui' as ui;

import 'package:barcode_gen/barcode_gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    );

BarcodePainter _painterOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(BarcodeView),
      matching: find.byType(CustomPaint),
    ),
  );
  return paint.painter! as BarcodePainter;
}

void main() {
  group('BarcodeView rendering', () {
    testWidgets('natural size from moduleWidth', (tester) async {
      await tester.pumpWidget(_host(const BarcodeView(
        type: BarcodeType.ean13(),
        data: '4006381333931',
        moduleWidth: 2,
        height: 100,
      )));
      expect(tester.getSize(find.byType(BarcodeView)), const Size(226, 100));
    });

    testWidgets('fills the available width when moduleWidth is null',
        (tester) async {
      await tester.pumpWidget(_host(const SizedBox(
        width: 300,
        child: BarcodeView(
          type: BarcodeType.ean13(),
          data: '4006381333931',
          height: 80,
        ),
      )));
      expect(tester.getSize(find.byType(BarcodeView)), const Size(300, 80));
    });

    testWidgets('paints background then bars in the given colours',
        (tester) async {
      await tester.pumpWidget(_host(const BarcodeView(
        type: BarcodeType.code128(),
        data: 'ABC',
        moduleWidth: 1,
        height: 40,
        hriPosition: HriPosition.none,
        barColor: Color(0xFFFF0000),
        backgroundColor: Color(0xFF00FF00),
      )));
      final m = const Code128Encoder().encode('ABC');
      expect(
        find.byType(BarcodeView),
        paints
          ..rect(color: const Color(0xFF00FF00))
          ..rect(
            rect: const Rect.fromLTWH(10, 0, 2, 40),
            color: const Color(0xFFFF0000),
          ),
      );
      expect(find.byType(BarcodeView),
          paintsExactlyCountTimes(#drawRect, m.bars.length + 1));
    });

    testWidgets('modules are snapped to whole device pixels', (tester) async {
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_host(const SizedBox(
        width: 300,
        child: BarcodeView(type: BarcodeType.ean13(), data: '4006381333931'),
      )));
      final painter = _painterOf(tester);
      expect(painter.devicePixelRatio, 2.75);
      final layout = painter.computeLayout(const Size(300, 100));
      final px = layout.moduleWidth * 2.75;
      expect((px - px.round()).abs(), lessThan(1e-9));
      expect(px.round(), greaterThanOrEqualTo(1));
      for (final r in layout.bars) {
        final l = r.left * 2.75;
        expect((l - l.round()).abs(), lessThan(1e-6));
      }
    });
  });

  group('HRI', () {
    testWidgets('EAN-13 digits are split around the guard bars',
        (tester) async {
      await tester.pumpWidget(_host(const BarcodeView(
        type: BarcodeType.ean13(),
        data: '4006381333931',
        moduleWidth: 2,
      )));
      expect(
          find.byType(BarcodeView), paintsExactlyCountTimes(#drawParagraph, 3));
    });

    testWidgets('single line layout and no HRI', (tester) async {
      await tester.pumpWidget(_host(const BarcodeView(
        type: BarcodeType.ean13(),
        data: '4006381333931',
        moduleWidth: 2,
        hriLayout: HriLayout.singleLine,
      )));
      expect(
          find.byType(BarcodeView), paintsExactlyCountTimes(#drawParagraph, 1));

      await tester.pumpWidget(_host(const BarcodeView(
        type: BarcodeType.ean13(),
        data: '4006381333931',
        moduleWidth: 2,
        hriPosition: HriPosition.none,
      )));
      expect(
          find.byType(BarcodeView), paintsExactlyCountTimes(#drawParagraph, 0));
    });

    testWidgets('guard bars extend below the data bars', (tester) async {
      await tester.pumpWidget(_host(const BarcodeView(
        type: BarcodeType.ean13(),
        data: '4006381333931',
        moduleWidth: 2,
        height: 100,
        hriStyle: TextStyle(fontSize: 20, height: 1),
      )));
      final layout = _painterOf(tester).computeLayout(const Size(226, 100));
      expect(layout.bars.first.bottom, 90); // guard: 100 - 20 / 2
      expect(layout.bars[2].bottom, 80); // data bar: 100 - 20
      expect(layout.texts, hasLength(3));
    });

    testWidgets('HRI above', (tester) async {
      await tester.pumpWidget(_host(const BarcodeView(
        type: BarcodeType.code128(),
        data: 'ABC',
        moduleWidth: 2,
        height: 60,
        hriPosition: HriPosition.above,
        hriStyle: TextStyle(fontSize: 10, height: 1),
      )));
      final layout = _painterOf(tester).computeLayout(const Size(0, 60));
      expect(layout.texts.single.top, 0);
      expect(layout.bars.first.top, 10);
    });
  });

  group('quiet zones', () {
    testWidgets('default quiet zone offsets the first bar', (tester) async {
      await tester.pumpWidget(_host(const BarcodeView(
        type: BarcodeType.ean13(),
        data: '4006381333931',
        moduleWidth: 2,
        height: 50,
        hriPosition: HriPosition.none,
      )));
      expect(
        find.byType(BarcodeView),
        paints
          ..rect(color: _white)
          ..rect(rect: const Rect.fromLTWH(22, 0, 2, 50), color: _black),
      );
    });

    testWidgets('quietZoneModules: 0 removes it', (tester) async {
      await tester.pumpWidget(_host(const BarcodeView(
        type: BarcodeType.ean13(),
        data: '4006381333931',
        moduleWidth: 2,
        height: 50,
        hriPosition: HriPosition.none,
        quietZoneModules: 0,
      )));
      expect(tester.getSize(find.byType(BarcodeView)), const Size(190, 50));
      expect(
        find.byType(BarcodeView),
        paints
          ..rect(color: _white)
          ..rect(rect: const Rect.fromLTWH(0, 0, 2, 50), color: _black),
      );
    });
  });

  group('errors', () {
    testWidgets('errorBuilder receives the exception', (tester) async {
      BarcodeException? seen;
      await tester.pumpWidget(_host(BarcodeView(
        type: const BarcodeType.ean13(),
        data: '4006381333932',
        errorBuilder: (context, error) {
          seen = error;
          return const Text('bad code');
        },
      )));
      expect(find.text('bad code'), findsOneWidget);
      expect(seen?.kind, BarcodeErrorKind.invalidCheckDigit);
      expect(find.byType(CustomPaint), findsNothing);
    });

    testWidgets('default error widget shows the message', (tester) async {
      await tester.pumpWidget(_host(const BarcodeView(
        type: BarcodeType.ean13(),
        data: 'abc',
      )));
      expect(find.textContaining('digits only'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('semantics', () {
    testWidgets('default label names the symbology and the data',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const BarcodeView(
        type: BarcodeType.ean13(),
        data: '400638133393',
      )));
      expect(
        tester.getSemantics(find.byType(BarcodeView)),
        matchesSemantics(label: 'EAN-13 barcode: 4006381333931', isImage: true),
      );
      handle.dispose();
    });

    testWidgets('custom label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const BarcodeView(
        type: BarcodeType.code128(),
        data: 'ABC',
        semanticsLabel: 'Order number',
      )));
      expect(
        tester.getSemantics(find.byType(BarcodeView)),
        matchesSemantics(label: 'Order number', isImage: true),
      );
      handle.dispose();
    });
  });

  group('BarcodePainter', () {
    test('natural size', () {
      final p = BarcodePainter(
        modules: const Ean13Encoder().encode('4006381333931'),
        moduleWidth: 2,
      );
      expect(p.naturalSize(100), const Size(226, 100));
    });

    test('shouldRepaint only when inputs change', () {
      final m = const Code128Encoder().encode('A');
      final a = BarcodePainter(modules: m, moduleWidth: 1);
      expect(
          a.shouldRepaint(BarcodePainter(modules: m, moduleWidth: 1)), isFalse);
      expect(
          a.shouldRepaint(BarcodePainter(modules: m, moduleWidth: 2)), isTrue);
      expect(
        a.shouldRepaint(
          BarcodePainter(
              modules: const Code128Encoder().encode('B'), moduleWidth: 1),
        ),
        isTrue,
      );
    });

    testWidgets('toImage renders bars at the requested pixel ratio',
        (tester) async {
      final p = BarcodePainter(
        modules: const Code128Encoder().encode('ABC'),
        moduleWidth: 1,
        hriPosition: HriPosition.none,
      );
      final size = p.naturalSize(20);
      final bytes = await tester.runAsync(() async {
        final image = await p.toImage(size, pixelRatio: 2);
        expect(image.width, (size.width * 2).round());
        expect(image.height, 40);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!;
      });
      int pixel(int x, int y) =>
          bytes!.getUint32((y * (size.width * 2).round() + x) * 4);
      // Quiet zone (10 modules = 20 px) is white, the start bar is black.
      expect(pixel(5, 10), 0xFFFFFFFF);
      expect(pixel(20, 10), 0x000000FF);
      expect(pixel(23, 10), 0x000000FF); // start bar is 2 modules wide
    });

    testWidgets('toPngBytes produces a PNG', (tester) async {
      final p = BarcodePainter(
        modules: const Ean8Encoder().encode('96385074'),
        moduleWidth: 2,
      );
      final png = await tester.runAsync(() => p.toPngBytes(p.naturalSize(60)));
      expect(png!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    });
  });
}
