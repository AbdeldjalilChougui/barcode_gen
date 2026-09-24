import 'package:barcode_gen/barcode_gen.dart';
import 'package:flutter_test/flutter_test.dart';

int _count(String s, String needle) => needle.allMatches(s).length;

void main() {
  test('EAN-13 SVG has one rect per bar plus background and three digit groups',
      () {
    final m = const Ean13Encoder().encode('4006381333931');
    final svg = barcodeToSvg(m, moduleWidth: 2, height: 100);
    expect(svg, startsWith('<svg xmlns="http://www.w3.org/2000/svg"'));
    expect(svg, contains('width="226"'));
    expect(svg, contains('height="100"'));
    expect(svg, contains('viewBox="0 0 226 100"'));
    expect(_count(svg, '<rect'), m.bars.length + 1);
    expect(_count(svg, '<text'), 3);
    expect(svg, contains('>006381</text>'));
    expect(svg.trim(), endsWith('</svg>'));
  });

  test('colours, no background and no text', () {
    final m = const Code128Encoder().encode('ABC');
    final svg = barcodeToSvg(
      m,
      barColor: '#112233',
      backgroundColor: null,
      drawText: false,
    );
    expect(svg, contains('fill="#112233"'));
    expect(_count(svg, '<rect'), m.bars.length);
    expect(svg, isNot(contains('<text')));
  });

  test('text is XML-escaped', () {
    final m = const Code128Encoder().encode('a<b&c"');
    final svg = barcodeToSvg(m);
    expect(svg, contains('a&lt;b&amp;c&quot;'));
    expect(svg, isNot(contains('a<b')));
  });

  test('bar x positions follow module offsets', () {
    final m = BarcodeModules(widths: const [1, 2, 3], text: '');
    final svg = barcodeToSvg(
      m,
      moduleWidth: 3,
      height: 10,
      drawText: false,
      backgroundColor: null,
      quietZoneModules: 0,
    );
    expect(svg, contains('<rect x="0" y="0" width="3" height="10"'));
    expect(svg, contains('<rect x="9" y="0" width="9" height="10"'));
  });
}
