import 'barcode_exception.dart';
import 'barcode_modules.dart';
import 'barcode_type.dart';
import 'wide_narrow.dart';

// Seven elements (bar, space, ... bar) per character.
const _patterns = {
  '0': 'nnnnnww', '1': 'nnnnwwn', '2': 'nnnwnnw', '3': 'wwnnnnn', //
  '4': 'nnwnnwn', '5': 'wnnnnwn', '6': 'nwnnnnw', '7': 'nwnnwnn',
  '8': 'nwwnnnn', '9': 'wnnwnnn', '-': 'nnnwwnn', r'$': 'nnwwnnn',
  ':': 'wnnnwnw', '/': 'wnwnnnw', '.': 'wnwnwnn', '+': 'nnwnwnw',
  'A': 'nnwwnwn', 'B': 'nwnwnnw', 'C': 'nnnwnww', 'D': 'nnnwwwn',
};

const _startStopChars = 'ABCD';

/// Codabar encoder. Data may contain `0-9 - $ : / . +`; the [start] and
/// [stop] characters (A, B, C or D) are added around it.
class CodabarEncoder extends BarcodeType {
  /// Creates a Codabar encoder.
  const CodabarEncoder({
    this.start = 'A',
    this.stop = 'B',
    this.showStartStop = false,
  });

  /// Start character, one of A, B, C, D.
  final String start;

  /// Stop character, one of A, B, C, D.
  final String stop;

  /// Include the start and stop characters in the HRI text.
  final bool showStartStop;

  @override
  String get name => 'Codabar';

  @override
  BarcodeModules encode(String data) {
    for (final c in [start, stop]) {
      if (c.length != 1 || !_startStopChars.contains(c)) {
        throw BarcodeException(
          BarcodeErrorKind.invalidCharacter,
          'Codabar start/stop must be A, B, C or D, got "$c"',
        );
      }
    }
    if (data.isEmpty) {
      throw const BarcodeException(
        BarcodeErrorKind.invalidLength,
        'Codabar data must not be empty',
      );
    }
    for (final c in data.split('')) {
      if (_startStopChars.contains(c) || !_patterns.containsKey(c)) {
        throw BarcodeException(
          BarcodeErrorKind.invalidCharacter,
          'Codabar cannot encode "$c" in the data',
        );
      }
    }
    final widths = <int>[];
    final chars = '$start$data$stop'.split('');
    for (var i = 0; i < chars.length; i++) {
      if (i > 0) widths.add(1);
      widths.addAll(nwToWidths(_patterns[chars[i]]!));
    }
    return BarcodeModules(
      widths: widths,
      text: showStartStop ? '$start$data$stop' : data,
    );
  }
}
