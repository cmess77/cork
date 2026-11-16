# Cork

Personal wine tasting journal for Android.

## Commits

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org):
`type(scope)!: description`, for example `feat(feed): sort by rating`.

- `feat` bumps the minor version, `fix` and `perf` the patch.
- `!` after the type, or a `BREAKING CHANGE: ` footer, marks a break: the
  major version from 1.0.0 on, the minor before it.
- `refactor`, `docs`, `test`, `build`, `ci`, `chore`, `style`, and `revert`
  release nothing.

Enable the commit-msg hook once per clone:

```bash
git config core.hooksPath .githooks
```

CI rejects any commit since the last release that doesn't parse.

## Releasing

Versions follow [Semantic Versioning](https://semver.org) and come from the
commits, not by hand:

```bash
dart tool/release.dart plan      # preview the next version and its notes
dart tool/release.dart cut       # write CHANGELOG.md and pubspec, commit, tag
git push --follow-tags origin main
```

`cut --version 1.0.0` picks the version yourself, for a deliberate 1.0.0.
The tag builds a signed APK on Forgejo and, through the push mirror, GitHub,
with the CHANGELOG.md section as the release notes.
