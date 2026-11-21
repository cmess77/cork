#!/usr/bin/env bash
# The Forgejo release for a vX.Y.Z tag, safe to repeat after a crash.
#
#   forgejo_release.sh complete TAG   exit 0 if the release exists with its APK
#   forgejo_release.sh publish TAG    create the release and attach the APK,
#                                     skipping whatever is already there
#
# Needs TOKEN (the workflow's token), GITHUB_SERVER_URL and GITHUB_REPOSITORY.
# `publish` also needs dist/cork-<version>.apk from build_release_apk.sh.
set -euo pipefail

command="${1:?usage: forgejo_release.sh (complete|publish) TAG}"
tag="${2:?usage: forgejo_release.sh (complete|publish) TAG}"
version="${tag#v}"
asset="cork-$version.apk"
api="$GITHUB_SERVER_URL/api/v1/repos/$GITHUB_REPOSITORY"
auth="Authorization: token $TOKEN"
response="$(mktemp)"
trap 'rm -f "$response"' EXIT

# Sets $status and $response for the release of $tag. 404 means none yet;
# any other failure stops the script rather than guessing.
fetch_release() {
  status="$(curl -sS -o "$response" -w '%{http_code}' -H "$auth" \
    "$api/releases/tags/$tag")"
  case "$status" in
    200 | 404) ;;
    *) echo "GET releases/tags/$tag returned HTTP $status" >&2; exit 2 ;;
  esac
}

has_asset() {
  grep -Eq "\"name\": *\"${asset//./\.}\"" "$response"
}

case "$command" in
  complete)
    fetch_release
    [ "$status" = 200 ] && has_asset
    ;;
  publish)
    fetch_release
    if [ "$status" = 404 ]; then
      prerelease=false
      case "$version" in *-*) prerelease=true ;; esac
      body="$(dart tool/release.dart notes "$version" --json)"
      curl -fsS -X POST "$api/releases" -H "$auth" \
        -H 'Content-Type: application/json' \
        -d "{\"tag_name\":\"$tag\",\"name\":\"Cork $version\",\"body\":$body,\"prerelease\":$prerelease}" \
        -o "$response"
    fi
    if ! has_asset; then
      release_id="$(grep -o '"id": *[0-9]*' "$response" | head -1 | grep -o '[0-9]*')"
      curl -fsS -X POST "$api/releases/$release_id/assets?name=$asset" \
        -H "$auth" -F "attachment=@dist/$asset" > /dev/null
    fi
    echo "Published $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/tag/$tag"
    ;;
  *)
    echo "usage: forgejo_release.sh (complete|publish) TAG" >&2
    exit 2
    ;;
esac
