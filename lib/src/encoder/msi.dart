import 'barcode_exception.dart';
import 'barcode_modules.dart';
import 'barcode_type.dart';
import 'check_digits.dart';

/// MSI Plessey check digit schemes.
enum MsiCheckDigit {
  /// No check digit.
  none,

  /// One modulo-10 (Luhn) check digit. The most common choice.
  mod10,

  /// Two modulo-10 (Luhn) check digits, the second computed over the data
  /// plus the first.
  mod1010,
}

/// MSI modulo-10 (Luhn) check digit for [digits].
int msiMod10(String digits) {
  var sum = 0;
  var dbl = true;
  for (var i = digits.length - 1; i >= 0; i--) {
    var d = digits.codeUnitAt(i) - 0x30;
    if (dbl) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    dbl = !dbl;
  }
  return (10 - sum % 10) % 10;
}

/// MSI (Modified Plessey) encoder: each digit is four BCD bits, a 0 bit is
/// a 1-module bar and 2-module space, a 1 bit a 2-module bar and 1-module
/// space.
class MsiEncoder extends BarcodeType {
  /// Creates an MSI encoder with the given [checkDigit] scheme.
  const MsiEncoder({this.checkDigit = MsiCheckDigit.mod10});

  /// Check digit scheme.
  final MsiCheckDigit checkDigit;

  @override
  String get name => 'MSI';

  @override
  BarcodeModules encode(String data) {
    if (data.isEmpty) {
      throw const BarcodeException(
        BarcodeErrorKind.invalidLength,
        'MSI data must not be empty',
      );
    }
    if (!isAllDigits(data)) {
      throw BarcodeException(
        BarcodeErrorKind.invalidCharacter,
        'MSI accepts digits only, got "$data"',
      );
    }
    var full = data;
    if (checkDigit != MsiCheckDigit.none) full += '${msiMod10(full)}';
    if (checkDigit == MsiCheckDigit.mod1010) full += '${msiMod10(full)}';
    final b = StringBuffer('110');
    for (final c in full.codeUnits) {
      final d = c - 0x30;
      for (var bit = 3; bit >= 0; bit--) {
        b.write((d >> bit) & 1 == 1 ? '110' : '100');
      }
    }
    b.write('1001');
    return BarcodeModules.fromPattern(b.toString(), text: full);
  }
}
