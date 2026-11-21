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
commits. Releasing is automatic: once CI passes on a push to main with a
`feat`, `fix`, or `perf` commit since the last release, it runs
`dart tool/release.dart cut`, which writes CHANGELOG.md and the version,
commits `chore(release): vX.Y.Z`, and tags it. CI then builds the signed APK,
pushes that commit and tag, and publishes the APK on Forgejo; a failed build
pushes nothing. The push mirror carries the tag to GitHub, which publishes the
same APK. If publishing fails, re-run CI on main from the Actions page: it
finishes the release without cutting a new one. Pull after a release to pick
up the release commit.

```bash
dart tool/release.dart plan      # preview the next version and its notes
```

To choose the version yourself, as for a deliberate 1.0.0, cut it locally
and push the tag:

```bash
dart tool/release.dart cut --version 1.0.0
git push --follow-tags origin main
```
