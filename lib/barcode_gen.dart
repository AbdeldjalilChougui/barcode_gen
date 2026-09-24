/// 1D barcode generation: pure-Dart encoders, SVG export and Flutter widgets.
library;

export 'src/encoder/barcode_exception.dart';
export 'src/encoder/barcode_modules.dart';
export 'src/encoder/barcode_type.dart';
export 'src/encoder/check_digits.dart' show gs1CheckDigit;
export 'src/encoder/ean_upc.dart';
export 'src/encoder/code128.dart' show Code128Encoder;
export 'src/encoder/gs1.dart';
export 'src/encoder/codabar.dart';
export 'src/encoder/code39.dart'
    show Code39Encoder, code39CheckCharacter, code39FullAscii;
export 'src/encoder/code93.dart';
export 'src/encoder/itf.dart';
export 'src/encoder/msi.dart';
export 'src/export/svg.dart';
export 'src/layout/barcode_layout.dart';
