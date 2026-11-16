import 'dart:io';

import 'package:cork/app/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appVersion matches the pubspec version', () {
    final line = File(
      'pubspec.yaml',
    ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final pubspec = line.split(':').last.trim().split('+').first;
    expect(appVersion, pubspec, reason: 'update lib/app/version.dart');
  });
}
