#!/usr/bin/env bash
# Builds the signed release APK for the tag being released, into
# dist/cork-<version>.apk. Shared by the Forgejo and GitHub release
# workflows so both forges publish byte-for-byte the same version.
#
# Needs: a vX.Y.Z tag checked out with full history, and the secrets
# CORK_KEYSTORE_BASE64 and CORK_KEYSTORE_PASSWORD in the environment. The
# keystore is PKCS12, where the key password must equal the store password,
# and its one key is aliased "cork", so neither is a separate secret.
set -euo pipefail

tag="${GITHUB_REF_NAME:?run from a tag push}"
case "$tag" in
  v[0-9]*) ;;
  *) echo "tag '$tag' is not vX.Y.Z" >&2; exit 1 ;;
esac
version="${tag#v}"
# Commit count is identical on both forges, so versionCode always matches.
build_number="$(git rev-list --count HEAD)"

for name in CORK_KEYSTORE_BASE64 CORK_KEYSTORE_PASSWORD; do
  if [ -z "${!name:-}" ]; then
    echo "missing secret $name" >&2
    exit 1
  fi
done

keystore="${RUNNER_TEMP:-/tmp}/cork-release.jks"
printf '%s' "$CORK_KEYSTORE_BASE64" | base64 -d > "$keystore"
trap 'rm -f "$keystore"' EXIT
export CORK_KEYSTORE="$keystore"
export CORK_KEY_ALIAS=cork
export CORK_KEY_PASSWORD="$CORK_KEYSTORE_PASSWORD"

# Fail fast, before the slow build, if the secrets don't open the key.
# The fingerprint and length identify a bad paste without revealing it.
echo "keystore sha256 $(sha256sum < "$keystore" | cut -c1-16), $(wc -c < "$keystore") bytes; password ${#CORK_KEYSTORE_PASSWORD} chars"
if ! keytool -list -keystore "$keystore" -storepass:env CORK_KEYSTORE_PASSWORD \
    -alias "$CORK_KEY_ALIAS" > /dev/null; then
  echo "CORK_KEYSTORE_BASE64 / CORK_KEYSTORE_PASSWORD do not open key '$CORK_KEY_ALIAS'" >&2
  exit 1
fi

flutter config --no-analytics
flutter pub get
flutter build apk --release \
  --build-name="$version" \
  --build-number="$build_number"

mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk "dist/cork-$version.apk"
echo "Built dist/cork-$version.apk (versionCode $build_number)"
