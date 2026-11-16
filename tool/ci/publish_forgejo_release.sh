#!/usr/bin/env bash
# Publishes dist/cork-<version>.apk as the Forgejo release for TAG, with the
# CHANGELOG.md section as its notes. Needs TOKEN, the workflow's token.
set -euo pipefail

tag="${1:?usage: publish_forgejo_release.sh TAG}"
version="${tag#v}"
apk="dist/cork-$version.apk"
prerelease=false
case "$version" in *-*) prerelease=true ;; esac
api="$GITHUB_SERVER_URL/api/v1/repos/$GITHUB_REPOSITORY"
body="$(dart tool/release.dart notes "$version" --json)"
release_id="$(curl -fsS -X POST "$api/releases" \
  -H "Authorization: token $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"tag_name\":\"$tag\",\"name\":\"Cork $version\",\"body\":$body,\"prerelease\":$prerelease}" \
  | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)"
curl -fsS -X POST "$api/releases/$release_id/assets?name=cork-$version.apk" \
  -H "Authorization: token $TOKEN" \
  -F "attachment=@$apk" > /dev/null
echo "Published $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/tag/$tag"
