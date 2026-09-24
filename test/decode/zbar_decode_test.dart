@Tags(['decode'])
@TestOn('vm')
library;

import 'dart:io';

import 'package:barcode_gen/barcode_gen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Optional local check: renders each symbol to a PNG with
/// [BarcodePainter.toPngBytes] and decodes it with `zbarimg` (ZBar).
/// Skipped when zbarimg is not installed.
final bool _hasZbar = () {
  try {
    return Process.runSync('zbarimg', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

class _Case {
  const _Case(this.type, this.data, this.expected, {this.hri = true});
  final BarcodeType type;
  final String data;

  /// Expected zbarimg output lines (`SYMBOLOGY:data`).
  final List<String> expected;
  final bool hri;
}

const _zbarArgs = [
  '--quiet',
  '-Supca.enable',
  '-Supce.enable',
  '-Sean2.enable',
  '-Sean5.enable',
  '-Scodabar.enable',
  '-Scode93.enable',
  '-Si25.enable',
];

final _cases = <_Case>[
  const _Case(BarcodeType.ean13(), '4006381333931', ['EAN-13:4006381333931']),
  const _Case(BarcodeType.ean8(), '96385074', ['EAN-8:96385074']),
  const _Case(BarcodeType.upcA(), '036000291452', ['UPC-A:036000291452']),
  const _Case(BarcodeType.upcE(), '01234565', ['UPC-E:01234565']),
  // UPC-E with number system 1 is covered by module-exact tests only:
  // zbarimg 0.23.93 does not report it.
  const _Case(BarcodeType.ean13(), '9780306406157+52495',
      ['EAN-13:9780306406157', 'EAN-5:52495']),
  const _Case(BarcodeType.ean13(), '4006381333931+12',
      ['EAN-13:4006381333931', 'EAN-2:12']),
  const _Case(BarcodeType.code128(), 'Wikipedia', ['CODE-128:Wikipedia']),
  const _Case(BarcodeType.code128(), '12345678', ['CODE-128:12345678']),
  const _Case(BarcodeType.code128(), '12345', ['CODE-128:12345']),
  const _Case(BarcodeType.code128(), 'ab12345678cd', ['CODE-128:ab12345678cd']),
  const _Case(BarcodeType.code128(), 'a\tb', ['CODE-128:a\tb']),
  const _Case(BarcodeType.code128(), 'AB\x01\x02cd', ['CODE-128:AB\x01\x02cd']),
  const _Case(
      BarcodeType.code128(), 'HELLO world 123', ['CODE-128:HELLO world 123']),
  const _Case(BarcodeType.code128(), '999999a99999', ['CODE-128:999999a99999']),
  const _Case(BarcodeType.gs1128(), '(01)09501101530003(17)250101(10)ABC123',
      ['CODE-128:01095011015300031725010110ABC123']),
  const _Case(BarcodeType.gs1128(), '(10)ABC(17)250101',
      ['CODE-128:10ABC\x1d17250101']),
  const _Case(BarcodeType.code39(), 'CODE39', ['CODE-39:CODE39']),
  const _Case(
      BarcodeType.code39(checkDigit: true), 'CODE39', ['CODE-39:CODE39W']),
  const _Case(BarcodeType.code39(fullAscii: true), 'ab', ['CODE-39:+A+B']),
  const _Case(BarcodeType.code93(), 'WIKIPEDIA', ['CODE-93:WIKIPEDIA']),
  const _Case(BarcodeType.code93(), 'TEST-93 \$/+%', ['CODE-93:TEST-93 \$/+%']),
  const _Case(BarcodeType.code93(), 'Lower case!', ['CODE-93:Lower case!']),
  const _Case(BarcodeType.itf(), '12345678', ['I2/5:12345678']),
  const _Case(BarcodeType.itf14(), '1540014128876', ['I2/5:15400141288763']),
  const _Case(BarcodeType.codabar(), '40156', ['Codabar:A40156B']),
  const _Case(BarcodeType.codabar(start: 'C', stop: 'D'), r'0123456789-$:/.+',
      [r'Codabar:C0123456789-$:/.+D']),
];

void main() {
  late Directory dir;
  setUpAll(() => dir = Directory.systemTemp.createTempSync('barcode_gen_'));
  tearDownAll(() => dir.deleteSync(recursive: true));

  for (var i = 0; i < _cases.length; i++) {
    final c = _cases[i];
    testWidgets(
      'zbarimg decodes ${c.type.name} ${c.data.replaceAll(RegExp(r'[\x00-\x1f]'), '?')}',
      (tester) async {
        final result = await tester.runAsync(() async {
          final painter = BarcodePainter(
            modules: c.type.encode(c.data),
            moduleWidth: 3,
            hriPosition: c.hri ? HriPosition.below : HriPosition.none,
          );
          final png = await painter.toPngBytes(painter.naturalSize(150));
          final file = File('${dir.path}/case_$i.png')..writeAsBytesSync(png);
          return Process.run('zbarimg', [..._zbarArgs, file.path]);
        });
        final out = (result!.stdout as String)
            .split('\n')
            .where((l) => l.isNotEmpty)
            .toList();
        expect(out, unorderedEquals(c.expected),
            reason: 'stderr: ${result.stderr}');
      },
      skip: !_hasZbar,
    );
  }
}
