import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/conventional.dart';

Commit parsed(String message) => switch (parseCommit(message)) {
  Parsed(:final commit) => commit,
  Rejected(:final reason) => fail('rejected "$message": $reason'),
};

void main() {
  group('parseCommit', () {
    test('reads type, scope, and description', () {
      final c = parsed('feat(feed): sort by rating');
      expect(
        (c.type, c.scope, c.description, c.breaking),
        ('feat', 'feed', 'sort by rating', false),
      );
    });

    test('marks a break from "!" or a BREAKING CHANGE footer', () {
      expect(parsed('refactor!: drop the v1 store').breaking, isTrue);
      expect(
        parsed(
          'fix: new backup format\n\nBREAKING CHANGE: old backups fail',
        ).breaking,
        isTrue,
      );
    });

    test('rejects messages that are not conventional', () {
      for (final message in [
        'Sort the journal by date',
        'feature: sort',
        'feat:missing space',
        'feat: subject\nno blank line',
        'feat: ${'x' * 100}',
      ]) {
        expect(parseCommit(message), isA<Rejected>(), reason: message);
      }
    });
  });

  group('version bump', () {
    final v = Version.parse('v0.5.0');
    Version next(List<String> messages) =>
        v.bumped(bumpFor(messages.map(parsed)));

    test('fix and perf bump the patch, feat the minor', () {
      expect(next(['fix: a', 'perf: b']), Version(0, 5, 1));
      expect(next(['fix: a', 'feat: b']), Version(0, 6, 0));
    });

    test('a break bumps the minor before 1.0.0 and the major after', () {
      expect(next(['feat!: a']), Version(0, 6, 0));
      expect(Version(1, 2, 3).bumped(Bump.major), Version(2, 0, 0));
    });

    test('docs, chore, and the like release nothing', () {
      expect(next(['docs: a', 'chore: b', 'ci: c']), v);
    });
  });

  test('changelog lists breaking changes first and skips chores', () {
    final section = changelogSection(Version(0, 6, 0), '2026-11-16', [
      parsed('feat(feed): sort by rating'),
      parsed('chore: bump deps'),
      parsed('fix!: new backup format'),
    ]);
    expect(section, '''
## 0.6.0 (2026-11-16)

### Breaking changes

- new backup format

### Features

- **feed:** sort by rating
''');
  });
}
