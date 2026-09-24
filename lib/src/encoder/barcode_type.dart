import 'barcode_exception.dart';
import 'barcode_modules.dart';
import 'codabar.dart';
import 'code128.dart';
import 'code39.dart';
import 'code93.dart';
import 'ean_upc.dart';
import 'gs1.dart';
import 'itf.dart';
import 'msi.dart';

/// A 1D symbology that turns a data string into [BarcodeModules].
///
/// Use the named constructors to pick one, e.g. `BarcodeType.ean13()` or
/// `BarcodeType.code128()`. Every encoder is pure Dart.
abstract class BarcodeType {
  /// Base constructor for subclasses.
  const BarcodeType();

  /// EAN-13 (ISO/IEC 15420), optionally with a 2- or 5-digit add-on.
  const factory BarcodeType.ean13() = Ean13Encoder;

  /// EAN-8 (ISO/IEC 15420).
  const factory BarcodeType.ean8() = Ean8Encoder;

  /// UPC-A (ISO/IEC 15420), optionally with an add-on.
  const factory BarcodeType.upcA() = UpcAEncoder;

  /// UPC-E (ISO/IEC 15420), optionally with an add-on.
  const factory BarcodeType.upcE() = UpcEEncoder;

  /// Stand-alone EAN/UPC 2-digit add-on.
  const factory BarcodeType.ean2() = Ean2Encoder;

  /// Stand-alone EAN/UPC 5-digit add-on.
  const factory BarcodeType.ean5() = Ean5Encoder;

  /// Code 128 (ISO/IEC 15417) with automatic code-set selection.
  const factory BarcodeType.code128() = Code128Encoder;

  /// GS1-128: Code 128 carrying GS1 Application Identifiers.
  const factory BarcodeType.gs1128({bool allowUnknownAis}) = Gs1128Encoder;

  /// Code 39 (ISO/IEC 16388), optionally full ASCII and with a mod-43
  /// check character.
  const factory BarcodeType.code39({bool fullAscii, bool checkDigit}) =
      Code39Encoder;

  /// Code 93 with its two check characters.
  const factory BarcodeType.code93() = Code93Encoder;

  /// Interleaved 2 of 5 (ISO/IEC 16390).
  const factory BarcodeType.itf({BearerBars bearerBars, int bearerThickness}) =
      ItfEncoder;

  /// ITF-14 (GTIN-14 in ITF) with bearer bars.
  const factory BarcodeType.itf14({
    BearerBars bearerBars,
    int bearerThickness,
  }) = Itf14Encoder;

  /// Codabar with configurable start/stop characters.
  const factory BarcodeType.codabar({
    String start,
    String stop,
    bool showStartStop,
  }) = CodabarEncoder;

  /// MSI Plessey.
  const factory BarcodeType.msi({MsiCheckDigit checkDigit}) = MsiEncoder;

  /// Display name of the symbology, e.g. `EAN-13`.
  String get name;

  /// Encodes [data]. Throws [BarcodeException] when it is not valid.
  BarcodeModules encode(String data);

  /// Whether [data] can be encoded.
  bool isValid(String data) {
    try {
      encode(data);
      return true;
    } on BarcodeException {
      return false;
    }
  }

  @override
  String toString() => 'BarcodeType($name)';
}
