import 'dart:io';

import 'package:cork/domain/aroma_wheel.dart';
import 'package:cork/domain/aroma_wheel_data.dart';
import 'package:cork/domain/ids.dart';
import 'package:flutter_test/flutter_test.dart';

const _golden = 'test/golden/descriptor_ids.txt';

void main() {
  test('descriptor ids are unique', () {
    final ids = [
      for (final c in aromaWheel.categories)
        for (final d in c.descriptors) d.id.value,
    ];
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('every id ever shipped is still known (append-only vocabulary)', () {
    final shipped = File(
      _golden,
    ).readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
    final current = {for (final d in aromaWheel.descriptors) d.id.value};
    expect(
      current.containsAll(shipped),
      isTrue,
      reason:
          'A shipped descriptor id disappeared. Ids are stored in '
          'journals: keep the old id and add a new one instead.',
    );
    final added = current.difference(shipped.toSet());
    expect(
      added,
      isEmpty,
      reason: 'New descriptor ids: append them to $_golden.',
    );
  });

  test('one category per aroma family, in family order', () {
    expect(aromaWheel.categories.map((c) => c.family), AromaFamily.values);
  });

  test('an unknown id still resolves to a readable label', () {
    final d = aromaWheel.resolve(
      const DescriptorId('spice.exotic.long-pepper'),
    );
    expect(d.label, 'Long pepper');
    expect(d.family, AromaFamily.spice);
    expect(aromaWheel.knows(d.id), isFalse);
  });
}
