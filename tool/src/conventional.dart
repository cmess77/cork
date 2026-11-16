/// Conventional Commits parsing and the semantic version bump they imply.
/// See https://www.conventionalcommits.org/en/v1.0.0/ and https://semver.org.
library;

/// Commit types Cork accepts. Only [releaseTypes] change the version.
const commitTypes = {
  'feat': 'Features',
  'fix': 'Fixes',
  'perf': 'Performance',
  'refactor': null,
  'docs': null,
  'test': null,
  'build': null,
  'ci': null,
  'chore': null,
  'style': null,
  'revert': null,
};

const releaseTypes = {'feat', 'fix', 'perf'};

final _header = RegExp(r'^([a-z]+)(?:\(([\w./-]+)\))?(!)?: (\S.*)$');
final _breakingFooter = RegExp(r'^BREAKING[ -]CHANGE: ', multiLine: true);

final class Commit {
  const Commit({
    required this.type,
    required this.description,
    this.scope,
    this.breaking = false,
    this.hash = '',
  });

  final String type;
  final String? scope;
  final bool breaking;
  final String description;
  final String hash;

  Bump get bump => breaking
      ? Bump.major
      : switch (type) {
          'feat' => Bump.minor,
          'fix' || 'perf' => Bump.patch,
          _ => Bump.none,
        };
}

/// A parsed [Commit], or the reason the message is not a Conventional Commit.
sealed class ParseResult {}

final class Parsed extends ParseResult {
  Parsed(this.commit);
  final Commit commit;
}

final class Rejected extends ParseResult {
  Rejected(this.reason);
  final String reason;
}

ParseResult parseCommit(String message, {String hash = ''}) {
  final lines = message.replaceAll('\r\n', '\n').split('\n');
  final subject = lines.first.trimRight();
  final match = _header.firstMatch(subject);
  if (match == null) {
    return Rejected(
      'subject "$subject" is not "type(scope)!: description", '
      'e.g. "feat(feed): sort by rating"',
    );
  }
  final type = match[1]!;
  if (!commitTypes.containsKey(type)) {
    return Rejected(
      'type "$type" is not one of ${commitTypes.keys.join(', ')}',
    );
  }
  if (subject.length > 100) {
    return Rejected('subject is ${subject.length} characters, over 100');
  }
  if (lines.length > 1 && lines[1].trim().isNotEmpty) {
    return Rejected('the subject must be followed by a blank line');
  }
  final body = lines.skip(1).join('\n');
  return Parsed(
    Commit(
      type: type,
      scope: match[2],
      breaking: match[3] != null || _breakingFooter.hasMatch(body),
      description: match[4]!,
      hash: hash,
    ),
  );
}

/// Git-generated messages a person never types and the hook lets through.
bool isGenerated(String message) =>
    RegExp(r'^(Merge |Revert "|fixup! |squash! |amend! )').hasMatch(message);

enum Bump { none, patch, minor, major }

final class Version implements Comparable<Version> {
  const Version(this.major, this.minor, this.patch);

  static Version parse(String text) {
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(text.trim());
    if (match == null) throw FormatException('not X.Y.Z', text);
    return Version(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
  }

  final int major;
  final int minor;
  final int patch;

  /// Below 1.0.0 the public API is not yet stable (semver item 4), so a
  /// breaking change bumps the minor, as feat does, rather than reaching 1.0.0
  /// by accident. Going to 1.0.0 is a deliberate `cut --version 1.0.0`.
  Version bumped(Bump bump) => switch (bump) {
    Bump.none => this,
    Bump.major when major == 0 => Version(0, minor + 1, 0),
    Bump.major => Version(major + 1, 0, 0),
    Bump.minor => Version(major, minor + 1, 0),
    Bump.patch => Version(major, minor, patch + 1),
  };

  @override
  int compareTo(Version other) => major != other.major
      ? major - other.major
      : minor != other.minor
      ? minor - other.minor
      : patch - other.patch;

  @override
  bool operator ==(Object other) => other is Version && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

Bump bumpFor(Iterable<Commit> commits) => commits.fold(
  Bump.none,
  (most, c) => c.bump.index > most.index ? c.bump : most,
);

/// The CHANGELOG.md section for [version]: breaking changes first, then each
/// release type. Commits that change no version (docs, chore, ...) are left out.
String changelogSection(Version version, String date, List<Commit> commits) {
  String line(Commit c) {
    final scope = c.scope == null ? '' : '**${c.scope}:** ';
    final hash = c.hash.isEmpty ? '' : ' (${c.hash})';
    return '- $scope${c.description}$hash';
  }

  final out = StringBuffer('## $version ($date)\n');
  final breaking = commits.where((c) => c.breaking).toList();
  if (breaking.isNotEmpty) {
    out.write('\n### Breaking changes\n\n');
    breaking.map(line).forEach(out.writeln);
  }
  for (final type in releaseTypes) {
    final ofType = commits.where((c) => c.type == type && !c.breaking).toList();
    if (ofType.isEmpty) continue;
    out.write('\n### ${commitTypes[type]}\n\n');
    ofType.map(line).forEach(out.writeln);
  }
  return out.toString();
}
