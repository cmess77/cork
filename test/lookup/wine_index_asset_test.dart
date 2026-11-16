import 'dart:io';

import 'package:cork/lookup/wine_index.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wineIndexAssetVersion names the committed index asset', () {
    final digest = sha256.convert(File(wineIndexAssetKey).readAsBytesSync());
    expect(
      wineIndexAssetVersion,
      digest.toString().substring(0, 12),
      reason: 'assets/wine_index.db changed: update wineIndexAssetVersion',
    );
  });
}
