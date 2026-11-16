#!/usr/bin/env bash
# Builds the signed release APK for the tag being released, into
# dist/cork-<version>.apk. Shared by the Forgejo and GitHub release
# workflows so both forges publish byte-for-byte the same version.
#
# Needs: a vX.Y.Z tag checked out with full history, and the secrets
# CORK_KEYSTORE_BASE64, CORK_KEYSTORE_PASSWORD, CORK_KEY_ALIAS,
# CORK_KEY_PASSWORD in the environment.
set -euo pipefail

tag="${GITHUB_REF_NAME:?run from a tag push}"
case "$tag" in
  v[0-9]*) ;;
  *) echo "tag '$tag' is not vX.Y.Z" >&2; exit 1 ;;
esac
version="${tag#v}"
# Commit count is identical on both forges, so versionCode always matches.
build_number="$(git rev-list --count HEAD)"

for name in CORK_KEYSTORE_BASE64 CORK_KEYSTORE_PASSWORD CORK_KEY_ALIAS CORK_KEY_PASSWORD; do
  if [ -z "${!name:-}" ]; then
    echo "missing secret $name" >&2
    exit 1
  fi
done

keystore="${RUNNER_TEMP:-/tmp}/cork-release.jks"
printf '%s' "$CORK_KEYSTORE_BASE64" | base64 -d > "$keystore"
trap 'rm -f "$keystore"' EXIT
export CORK_KEYSTORE="$keystore"

flutter config --no-analytics
flutter pub get
flutter build apk --release \
  --build-name="$version" \
  --build-number="$build_number"

mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk "dist/cork-$version.apk"
echo "Built dist/cork-$version.apk (versionCode $build_number)"
