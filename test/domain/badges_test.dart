import 'package:cork/domain/badges.dart';
import 'package:cork/domain/journal.dart';
import 'package:cork/domain/wine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/builders.dart';

BadgeStatus status(Journal j, String id) =>
    deriveBadges(j.feed).firstWhere((s) => s.rule.id == id);

void main() {
  test('earnedAt is when the tasting that crossed the line was tasted', () {
    final w = indexWine(1);
    final pairs = [
      for (var i = 1; i <= 12; i++)
        (w, tasting(w, at: DateTime.utc(2026, 1, i))),
    ];
    final j = journalOf(pairs);
    expect(status(j, 'first').earnedAt, DateTime.utc(2026, 1, 1));
    expect(status(j, 't10').earnedAt, DateTime.utc(2026, 1, 10));
    expect(status(j, 't50').earnedAt, isNull);
    expect(status(j, 't50').progress, 12);
    expect(status(j, 't10').progress, 10);
  });

  test('deleting a tasting re-derives: the badge drops back to progress', () {
    final grapes = ['Syrah', 'Merlot', 'Riesling', 'Malbec', 'Gamay'];
    final wines = [
      for (var i = 0; i < grapes.length; i++)
        indexWine(i + 1, grapes: [grapes[i]]),
    ];
    final pairs = [for (final w in wines) (w, tasting(w))];
    final j = journalOf(pairs);
    expect(status(j, 'g5').earned, isTrue);
    expect(status(j, 'g5').counted, hasLength(5));

    final fewer = j.apply([DeleteTasting(pairs.last.$2.id)]);
    expect(status(fewer, 'g5').earned, isFalse);
    expect(status(fewer, 'g5').progress, 4);
    expect(newlyEarned(fewer, j).map((r) => r.id), contains('g5'));
    expect(newlyEarned(j, j), isEmpty);
  });

  test('earnedAt moves when an edit changes the crossing order', () {
    final early = indexWine(1, grapes: ['Syrah']);
    final pairs = [
      for (var i = 0; i < 10; i++)
        (early, tasting(early, at: DateTime.utc(2026, 2, i + 1))),
    ];
    final j = journalOf(pairs);
    expect(status(j, 'g10').earnedAt, DateTime.utc(2026, 2, 10));
    final moved = j.apply([DeleteTasting(pairs.first.$2.id)]);
    expect(status(moved, 'g10').earned, isFalse);
    expect(status(moved, 'g10').progress, 9);
  });

  test('Full flight needs all six wine types', () {
    final wines = [
      for (final type in WineType.values) indexWine(type.index + 1, type: type),
    ];
    final pairs = [for (final w in wines) (w, tasting(w))];
    final j = journalOf(pairs);
    expect(status(j, 'types').rule.target, 6);
    expect(status(j, 'types').earned, isTrue);
    final missing = j.apply([DeleteTasting(pairs.first.$2.id)]);
    expect(status(missing, 'types').progress, 5);
  });

  test('every rule id is unique', () {
    final ids = badgeRules.map((r) => r.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });
}
