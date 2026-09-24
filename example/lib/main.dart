import 'package:barcode_gen/barcode_gen.dart';
import 'package:flutter/material.dart';

void main() => runApp(const BarcodeGenExampleApp());

/// Gallery of every symbology plus a playground.
class BarcodeGenExampleApp extends StatelessWidget {
  /// Creates the example app.
  const BarcodeGenExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'barcode_gen',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const GalleryPage(),
    );
  }
}

class _Sample {
  const _Sample(this.type, this.data);
  final BarcodeType type;
  final String data;
}

const _samples = [
  _Sample(BarcodeType.ean13(), '4006381333931'),
  _Sample(BarcodeType.ean13(), '9780306406157+52495'),
  _Sample(BarcodeType.ean8(), '96385074'),
  _Sample(BarcodeType.upcA(), '036000291452'),
  _Sample(BarcodeType.upcE(), '01234565+12'),
  _Sample(BarcodeType.code128(), 'Hello, barcode_gen 2026'),
  _Sample(BarcodeType.gs1128(), '(01)09501101530003(17)250101(10)ABC123'),
  _Sample(BarcodeType.code39(checkDigit: true), 'CODE39'),
  _Sample(BarcodeType.code93(), 'WIKIPEDIA'),
  _Sample(BarcodeType.itf14(), '1540014128876'),
  _Sample(BarcodeType.codabar(), '40156'),
  _Sample(BarcodeType.msi(), '1234567'),
];

/// Shows every sample and a field to try your own data.
class GalleryPage extends StatefulWidget {
  /// Creates the gallery.
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  BarcodeType _type = const BarcodeType.code128();
  String _data = 'Type here';
  late final _controller = TextEditingController(text: _data);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _types = <BarcodeType>[
    BarcodeType.ean13(),
    BarcodeType.ean8(),
    BarcodeType.upcA(),
    BarcodeType.upcE(),
    BarcodeType.code128(),
    BarcodeType.gs1128(),
    BarcodeType.code39(fullAscii: true),
    BarcodeType.code93(),
    BarcodeType.itf(),
    BarcodeType.itf14(),
    BarcodeType.codabar(),
    BarcodeType.msi(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('barcode_gen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Playground', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          DropdownButton<BarcodeType>(
            value: _type,
            isExpanded: true,
            items: [
              for (final t in _types)
                DropdownMenuItem(value: t, child: Text(t.name)),
            ],
            onChanged: (t) => setState(() => _type = t!),
          ),
          TextField(
            decoration: const InputDecoration(labelText: 'Data'),
            controller: _controller,
            onChanged: (v) => setState(() => _data = v),
          ),
          const SizedBox(height: 12),
          BarcodeView(
            type: _type,
            data: _data,
            height: 120,
            errorBuilder: (context, error) => Container(
              height: 120,
              alignment: Alignment.center,
              color: Theme.of(context).colorScheme.errorContainer,
              child: Text('${error.kind.name}: ${error.message}'),
            ),
          ),
          const Divider(height: 32),
          for (final s in _samples)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.type.name}  ·  ${s.data}'),
                  const SizedBox(height: 4),
                  BarcodeView(type: s.type, data: s.data, height: 110),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
