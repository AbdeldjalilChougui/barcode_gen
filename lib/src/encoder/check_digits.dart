/// Computes the GS1 modulo-10 check digit for [digits] (the data without
/// its check digit). Weights alternate 3, 1, ... starting from the
/// rightmost data digit, as in the GS1 General Specifications section 7.9.
///
/// Throws [ArgumentError] if [digits] contains a non-digit.
int gs1CheckDigit(String digits) {
  var sum = 0;
  var weight = 3;
  for (var i = digits.length - 1; i >= 0; i--) {
    final d = digits.codeUnitAt(i) - 0x30;
    if (d < 0 || d > 9) {
      throw ArgumentError.value(digits, 'digits', 'must contain only 0-9');
    }
    sum += d * weight;
    weight = 4 - weight;
  }
  return (10 - sum % 10) % 10;
}

/// Whether every character of [s] is an ASCII digit.
bool isAllDigits(String s) {
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c < 0x30 || c > 0x39) return false;
  }
  return true;
}
