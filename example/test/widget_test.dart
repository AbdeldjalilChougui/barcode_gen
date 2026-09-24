import 'package:barcode_gen/barcode_gen.dart';
import 'package:barcode_gen_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gallery renders barcodes without errors', (tester) async {
    await tester.pumpWidget(const BarcodeGenExampleApp());
    expect(find.byType(BarcodeView), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
