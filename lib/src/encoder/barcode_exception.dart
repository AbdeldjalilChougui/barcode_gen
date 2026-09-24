/// Why an input could not be encoded.
enum BarcodeErrorKind {
  /// The data has a length the symbology does not allow.
  invalidLength,

  /// A supplied check digit does not match the computed one.
  invalidCheckDigit,

  /// The data contains a character the symbology cannot encode.
  invalidCharacter,

  /// The data is well formed character by character but not valid as a
  /// whole, for example a UPC-A that cannot be compressed to UPC-E or a
  /// GS1 element string with an unknown Application Identifier.
  invalidData,
}

/// Thrown by an encoder when its input cannot be encoded.
class BarcodeException implements Exception {
  /// Creates an exception of [kind] with a human-readable [message].
  const BarcodeException(this.kind, this.message);

  /// The category of the failure.
  final BarcodeErrorKind kind;

  /// A human-readable description of the failure.
  final String message;

  @override
  String toString() => 'BarcodeException(${kind.name}): $message';
}
