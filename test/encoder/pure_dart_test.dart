@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encoder, export and layout never import Flutter or dart:ui', () {
    final dirs = [
      Directory('lib/src/encoder'),
      Directory('lib/src/export'),
      Directory('lib/src/layout'),
    ];
    final offenders = <String>[];
    for (final dir in dirs) {
      expect(dir.existsSync(), isTrue, reason: '${dir.path} missing');
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final src = f.readAsStringSync();
        if (src.contains('package:flutter') || src.contains('dart:ui')) {
          offenders.add(f.path);
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
