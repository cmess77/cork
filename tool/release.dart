// Conventional Commits and semantic versioning for Cork.
//
//   dart tool/release.dart check-message FILE  # the commit-msg hook
//   dart tool/release.dart lint                # every commit since the last tag
//   dart tool/release.dart plan                # the next version and its notes
//   dart tool/release.dart cut [--version X.Y.Z]
//   dart tool/release.dart notes X.Y.Z [--json]
//
// `cut` writes CHANGELOG.md and the pubspec version, commits
// "chore(release): vX.Y.Z", and tags it. Pushing the tag runs the release
// workflows on Forgejo and, through the push mirror, GitHub.
import 'dart:convert';
import 'dart:io';

import 'src/conventional.dart';

const _changelog = 'CHANGELOG.md';
const _pubspec = 'pubspec.yaml';

void main(List<String> args) {
  if (args.isEmpty) _usage();
  switch (args.first) {
    case 'check-message' when args.length == 2:
      _checkMessage(args[1]);
    case 'lint':
      _lint();
    case 'plan':
      final (version, section) = _plan(null);
      stdout.writeln('next version: $version\n\n$section');
    case 'cut':
      final i = args.indexOf('--version');
      _cut(i == -1 ? null : Version.parse(args[i + 1]));
    case 'notes' when args.length >= 2:
      final notes = _notes(Version.parse(args[1]));
      stdout.write(args.contains('--json') ? jsonEncode(notes) : notes);
    default:
      _usage();
  }
}

Never _usage() => _fail(
  'usage: dart tool/release.dart '
  '(check-message FILE | lint | plan | cut [--version X.Y.Z] | '
  'notes X.Y.Z [--json])',
);

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

String _git(List<String> args) {
  final result = Process.runSync('git', args);
  if (result.exitCode != 0) {
    _fail('git ${args.join(' ')} failed: ${result.stderr}');
  }
  return (result.stdout as String).trim();
}

void _checkMessage(String path) {
  // Git strips "#" lines after the hook runs, so the hook strips them too.
  final message = File(
    path,
  ).readAsLinesSync().where((l) => !l.startsWith('#')).join('\n').trim();
  if (message.isEmpty || isGenerated(message)) return;
  if (parseCommit(message) case Rejected(:final reason)) {
    _fail(
      'commit message rejected: $reason\n'
      'Use Conventional Commits: feat: / fix: / perf: change the version,\n'
      'refactor: docs: test: build: ci: chore: style: revert: do not.\n'
      'Add "!" after the type, or a "BREAKING CHANGE: " footer, for a break.',
    );
  }
}

/// The last vX.Y.Z tag reachable from HEAD.
(String, Version) _lastTag() {
  final tag = _git(['describe', '--tags', '--abbrev=0', '--match', 'v[0-9]*']);
  return (tag, Version.parse(tag));
}

/// Commits since [tag], oldest first, failing on any that don't parse.
List<Commit> _commitsSince(String tag) {
  final log = _git([
    'log',
    '--no-merges',
    '--reverse',
    '--format=%h%x1f%B%x1e',
    '$tag..HEAD',
  ]);
  final commits = <Commit>[];
  final problems = <String>[];
  for (final record in log.split('\x1e')) {
    if (record.trim().isEmpty) continue;
    final [hash, message] = record.trim().split('\x1f');
    switch (parseCommit(message, hash: hash)) {
      case Parsed(:final commit):
        commits.add(commit);
      case Rejected(:final reason):
        problems.add('$hash: $reason');
    }
  }
  if (problems.isNotEmpty) {
    _fail(
      'commits since $tag that are not Conventional Commits:\n'
      '${problems.join('\n')}',
    );
  }
  return commits;
}

void _lint() {
  final (tag, _) = _lastTag();
  final commits = _commitsSince(tag);
  stdout.writeln('${commits.length} commits since $tag are conventional');
}

(Version, String) _plan(Version? requested) {
  final (tag, current) = _lastTag();
  final commits = _commitsSince(tag);
  final bump = bumpFor(commits);
  final version = requested ?? current.bumped(bump);
  if (version.compareTo(current) <= 0) {
    _fail(
      requested == null
          ? 'nothing to release: no feat, fix, perf, or breaking commit '
                'since $tag'
          : '$version is not above $current',
    );
  }
  final date = DateTime.now().toIso8601String().substring(0, 10);
  return (version, changelogSection(version, date, commits));
}

void _cut(Version? requested) {
  if (_git(['status', '--porcelain']).isNotEmpty) {
    _fail('commit or stash your changes first');
  }
  if (_git(['branch', '--show-current']) != 'main') {
    _fail('release from main');
  }
  final (version, section) = _plan(requested);

  final changelog = File(_changelog);
  final old = changelog.readAsStringSync().replaceAll('\r\n', '\n');
  final at = old.indexOf('\n## ');
  changelog.writeAsStringSync(
    at == -1
        ? '${old.trimRight()}\n\n$section'
        : '${old.substring(0, at + 1)}$section\n${old.substring(at + 1)}',
  );

  // versionCode is the commit count, so the release commit's count is next.
  final build = int.parse(_git(['rev-list', '--count', 'HEAD'])) + 1;
  final pubspec = File(_pubspec);
  pubspec.writeAsStringSync(
    pubspec.readAsStringSync().replaceFirst(
      RegExp(r'^version: .*$', multiLine: true),
      'version: $version+$build',
    ),
  );

  _git(['add', _changelog, _pubspec]);
  _git(['commit', '-m', 'chore(release): v$version']);
  _git(['tag', '-a', 'v$version', '-m', 'Cork $version']);
  stdout.writeln(
    'Tagged v$version (versionCode $build). Publish it with:\n'
    '  git push --follow-tags origin main',
  );
}

String _notes(Version version) {
  final text = File(_changelog).readAsStringSync().replaceAll('\r\n', '\n');
  final start = text.indexOf('## $version ');
  if (start == -1) _fail('$_changelog has no section for $version');
  final end = text.indexOf('\n## ', start);
  final section = text.substring(start, end == -1 ? text.length : end);
  // Drop the "## X.Y.Z (date)" heading: the release title already says it.
  return '${section.substring(section.indexOf('\n') + 1).trim()}\n';
}
