# barcode_gen

A maintained 1D barcode generator for Dart and Flutter. The encoders are pure
Dart and have module-exact tests. The widget snaps every module to whole device
pixels, and you can export to SVG or PNG.

[![pub package](https://img.shields.io/pub/v/barcode_gen.svg)](https://pub.dev/packages/barcode_gen)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Features

- **EAN-13, EAN-8, UPC-A, UPC-E** (ISO/IEC 15420): check digits are computed
  or verified. UPC-E ↔ UPC-A expansion and compression follow the four GS1
  zero-suppression rules (`upcEToUpcA`, `upcAToUpcE`). Number system 0 and 1 are
  both supported. **2- and 5-digit add-ons** can be written as
  `4006381333931+12`, or stand alone.
- **Code 128** (ISO/IEC 15417) picks code sets A, B and C, including Shift,
  by dynamic programming. This gives the **fewest symbol characters**. FNC1 is
  supported.
- **GS1-128** takes AI parsing input such as
  `(01)09501101530003(17)250101(10)ABC123`. It validates lengths, character
  set 82, and check digits for AIs 00, 01, 02, 402 and 410-417. FNC1
  separators are inserted only after elements whose length is not predefined.
- **Code 39** (ISO/IEC 16388) supports full-ASCII mode and the optional
  modulo-43 check character.
- **Code 93** has both check characters and uses automatic full-ASCII shifts.
- **ITF** (ISO/IEC 16390) and **ITF-14**, the latter with a GS1 check digit and
  frame or horizontal **bearer bars**.
- **Codabar** lets you choose the A/B/C/D start and stop characters.
- **MSI Plessey** supports no check digit, mod 10, or mod 10/10.
- **`BarcodeModules`**: the output of every encoder. It holds bar/space widths
  in modules, the HRI text, the guard-bar spans (so EAN guards extend down),
  the HRI segments, the add-on span, the recommended quiet zones and the bearer
  bars.
- **`barcodeToSvg`**: SVG export in pure Dart.
- **`BarcodeView`** widget with:
  - type, data, height and module width;
  - bar and background colours;
  - quiet zones;
  - HRI position (below, above, none);
  - HRI style;
  - EAN-style split digits or one line;
  - `errorBuilder`;
  - a semantics label.
- **`BarcodePainter`** has `toImage` and `toPngBytes`. **Modules are snapped
  to whole pixels**, so no bar is anti-aliased into grey.

## Install

```yaml
dependencies:
  barcode_gen: ^0.1.0
```

## Usage

### Widget

```dart
import 'package:barcode_gen/barcode_gen.dart';

BarcodeView(
  type: const BarcodeType.ean13(),
  data: '400638133393', // check digit is computed: 4006381333931
  height: 100,
);

BarcodeView(
  type: const BarcodeType.gs1128(),
  data: '(01)09501101530003(17)250101(10)ABC123',
  moduleWidth: 2, // logical px per module, rounded to device pixels
  hriPosition: HriPosition.below,
  hriStyle: const TextStyle(fontSize: 12),
  errorBuilder: (context, error) => Text(error.message),
  semanticsLabel: 'Pallet label',
);
```

With no `moduleWidth`, the barcode fills the available width. It uses the
largest whole number of device pixels per module that fits. `quietZoneModules`
overrides the recommended quiet zone, and `0` removes it.

### Encoders (pure Dart)

```dart
final modules = const BarcodeType.code128().encode('ab12345678cd');
print(modules.widths); // [2, 1, 1, 2, 1, 4, ...] bar first, in modules
print(modules.pattern); // '11010010000...'

const Code128Encoder().codewords('12345678'); // [105, 12, 34, 56, 78, 47, 106]
upcEToUpcA('0123456'); // '012345000065'
upcAToUpcE('012345000065'); // '01234565'
gs1CheckDigit('400638133393'); // 1

try {
  const BarcodeType.ean13().encode('4006381333932');
} on BarcodeException catch (e) {
  print(e.kind); // BarcodeErrorKind.invalidCheckDigit
}
```

### SVG and PNG

```dart
final svg = barcodeToSvg(
  const BarcodeType.ean13().encode('4006381333931'),
  moduleWidth: 2,
  height: 100,
);

final painter = BarcodePainter(
  modules: const BarcodeType.itf14().encode('1540014128876'),
  moduleWidth: 3,
);
final png = await painter.toPngBytes(painter.naturalSize(150));
```

## Migrating from barcode_widget

`barcode_widget` (last released May 2023) and the `barcode` package it wraps
(last released January 2025) map as follows.

| barcode_widget | barcode_gen |
| --- | --- |
| `BarcodeWidget(barcode: Barcode.code128(), data: d)` | `BarcodeView(type: const BarcodeType.code128(), data: d)` |
| `Barcode.ean13()` / `ean8()` / `upcA()` / `upcE()` | `BarcodeType.ean13()` / `ean8()` / `upcA()` / `upcE()` |
| `Barcode.ean2()` / `ean5()` | `BarcodeType.ean2()` / `ean5()`, or `'<ean>+12'` attached to the main symbol |
| `Barcode.gs128()` | `BarcodeType.gs1128()` with `(AI)value` input |
| `Barcode.code39()` / `code93()` | `BarcodeType.code39(fullAscii:, checkDigit:)` / `code93()` |
| `Barcode.itf()` / `itf14()` | `BarcodeType.itf()` / `itf14(bearerBars:)` |
| `Barcode.codabar()` | `BarcodeType.codabar(start:, stop:)` |
| `color` / `backgroundColor` | `barColor` / `backgroundColor` |
| `width` | `moduleWidth` (per module), or wrap in a `SizedBox` to fill a width |
| `drawText: false` | `hriPosition: HriPosition.none` |
| `style` | `hriStyle` |
| `errorBuilder: (context, String error)` | `errorBuilder: (context, BarcodeException error)` (`error.message`, `error.kind`) |
| `padding` / `margin` / `decoration` | wrap `BarcodeView` in `Padding` / `Container` |
| `Barcode.toSvg(...)` | `barcodeToSvg(type.encode(data), ...)` |

Behaviour differences:

- The width is always a whole number of device pixels per module, so a
  fixed `width` may render slightly narrower. The barcode is centred.
- EAN/UPC digits are split around the guard bars by default. Use
  `hriLayout: HriLayout.singleLine` for one line of text.
- Quiet zones are drawn by default. Pass `quietZoneModules: 0` to match a
  borderless `BarcodeWidget`.
- Code 128 input is ASCII only (no FNC4/Latin-1). Use `Code128Encoder.fnc1`
  (`\xF1`) for FNC1.

## Validation

- **Module-exact tests** compare full bit patterns against symbol character
  tables written out by hand from the standards. Test values include:
  - EAN-13 `4006381333931`
  - EAN-8 `96385074`
  - UPC-A `036000291452`
  - UPC-E `01234565`, with NS 0 and NS 1 parity
  - EAN-5 `52495` and EAN-2
  - Code 128 `12345678`
  - Code 39, ITF, Codabar and MSI examples
- **Code 128 code-set switching and check symbols** are tested against
  hand-worked value sequences with the arithmetic written in the test:
  - `Wikipedia` gives check 88.
  - `ab12345678cd` gives B → C → B with check 73.
  - `a\nb` uses Shift.
  - `\tAB` starts in set A.
  - GS1-128 starts with Start C + FNC1.
- **Invalid-input tests** cover wrong lengths, bad check digits and illegal
  characters for every symbology, and bad GS1 element strings.
- **Widget tests** cover:
  - size, colours and pixel snapping;
  - HRI split, single line, none and above;
  - guard-bar extension and quiet zones;
  - `errorBuilder` and the default error widget;
  - semantics;
  - `toImage` pixels and PNG output.
- **Optional decode tests** (tag `decode`) render PNGs through `BarcodePainter`
  and decode them with [ZBar](https://github.com/mchehab/zbar)'s `zbarimg`.
  They skip themselves when `zbarimg` is not on `PATH`. With zbarimg 0.23.93,
  26 cases decode correctly. They cover:
  - EAN-13/8, UPC-A/E, and EAN-2/5 add-ons;
  - Code 128 (including control characters and mixed code sets);
  - GS1-128 (the FNC1 separator arrives as GS, 0x1D);
  - Code 39 (plain, mod 43 and full ASCII);
  - Code 93 (including shifted lowercase);
  - ITF and ITF-14 with bearers;
  - Codabar.

```sh
flutter test                 # everything, decode tests included if zbarimg exists
flutter test -x decode       # skip decoder tests
flutter test -t decode       # only decoder tests
```

Install zbar with your package manager, e.g. `pacman -S zbar`,
`apt install zbar-tools` or `brew install zbar`.

## Limitations

- 1D linear symbologies only. There is no QR, Data Matrix, PDF417 or
  GS1 DataBar.
- Code 128 encodes ASCII 0-127 and FNC1. FNC2-4 and extended Latin-1 are
  not supported.
- The GS1-128 AI table covers common AIs: 00, 01, 02, 10, 11, 12, 13, 15,
  16, 17, 20, 21, 22, 30, 31nn-36nn (measures), 37, 240, 241, 242, 243, 250,
  251, 254, 400-403, 410-417, 420, 422, 424, 426, 7001, 7002, 7003, 8001,
  8002, 8004, 8005, 8012, 8020, 8200 and 90-99. It does not cover
  every AI in the GS1 General Specifications. Others are rejected unless you
  pass `allowUnknownAis: true`, which only checks character set 82.
- Wide elements (Code 39, ITF, Codabar) use a fixed 3:1 wide/narrow ratio.
- ITF-14 bearer bars default to 5 modules thick (`bearerThickness`). Check
  the value your printing process needs against the GS1 General
  Specifications.
- **Not verified by a decoder:**
  - MSI Plessey: zbar does not read it. Only the module-exact and check-digit
    tests cover it.
  - UPC-E with number system 1: zbarimg 0.23.93 does not report it. Its
    parity follows the standard (the inverse of number system 0) and has a
    module-exact test.

## Standards

- ISO/IEC 15420, *Bar code symbology specification: EAN/UPC*
- ISO/IEC 15417, *Bar code symbology specification: Code 128*
- ISO/IEC 16388, *Bar code symbology specification: Code 39*
- ISO/IEC 16390, *Bar code symbology specification: Interleaved 2 of 5*
- GS1 General Specifications: GTIN check digits, UPC-E zero suppression,
  add-ons, GS1-128, Application Identifiers, ITF-14
- The Code 93 and Codabar character tables are the widely published ones
  (AIM USS Code 93; ANSI/AIM BC3 for Codabar). Both were confirmed by
  decoding with zbar.

## License

MIT. See [LICENSE](LICENSE).

Made by [Abdeldjalil Chougui](https://abdeldjalilchougui.biz/).
