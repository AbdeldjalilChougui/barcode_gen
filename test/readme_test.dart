import 'package:barcode_gen/barcode_gen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Keeps the README examples honest.
void main() {
  test('encoder examples', () {
    final modules = const BarcodeType.code128().encode('ab12345678cd');
    expect(modules.widths.sublist(0, 6), [2, 1, 1, 2, 1, 4]);
    expect(modules.pattern, startsWith('11010010000'));
    expect(const Code128Encoder().codewords('12345678'),
        [105, 12, 34, 56, 78, 47, 106]);
    expect(upcEToUpcA('0123456'), '012345000065');
    expect(upcAToUpcE('012345000065'), '01234565');
    expect(gs1CheckDigit('400638133393'), 1);
    expect(
      () => const BarcodeType.ean13().encode('4006381333932'),
      throwsA(isA<BarcodeException>()
          .having((e) => e.kind, 'kind', BarcodeErrorKind.invalidCheckDigit)),
    );
    final svg = barcodeToSvg(
      const BarcodeType.ean13().encode('4006381333931'),
      moduleWidth: 2,
      height: 100,
    );
    expect(svg, contains('<svg'));
  });

  testWidgets('widget examples build', (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [
        const BarcodeView(
          type: BarcodeType.ean13(),
          data: '400638133393',
          height: 100,
        ),
        BarcodeView(
          type: const BarcodeType.gs1128(),
          data: '(01)09501101530003(17)250101(10)ABC123',
          moduleWidth: 2,
          hriPosition: HriPosition.below,
          hriStyle: const TextStyle(fontSize: 12),
          errorBuilder: (context, error) => Text(error.message),
          semanticsLabel: 'Pallet label',
        ),
      ]),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsNWidgets(2));
  });
}
