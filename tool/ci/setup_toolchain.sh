#!/usr/bin/env bash
# Installs the Android SDK command-line tools and the pinned Flutter into
# $HOME (reused when already present) and puts both on the job's PATH.
# Used by the Forgejo workflows, whose runner cannot resolve
# android-actions/setup-android or subosito/flutter-action.
set -euo pipefail

sdk="$HOME/android-sdk"
if [ ! -x "$sdk/cmdline-tools/latest/bin/sdkmanager" ]; then
  mkdir -p "$sdk/cmdline-tools"
  curl -fsSL -o "$sdk/cmdline-tools.zip" \
    https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q -o "$sdk/cmdline-tools.zip" -d "$sdk/cmdline-tools"
  rm -rf "$sdk/cmdline-tools/latest"
  mv "$sdk/cmdline-tools/cmdline-tools" "$sdk/cmdline-tools/latest"
fi
set +o pipefail
yes | "$sdk/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null
set -o pipefail

flutter_dir="$HOME/flutter-$FLUTTER_VERSION"
if [ ! -x "$flutter_dir/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$flutter_dir"
fi

env_file="${FORGEJO_ENV:-${GITHUB_ENV:-}}"
path_file="${FORGEJO_PATH:-${GITHUB_PATH:-}}"
{
  echo "ANDROID_HOME=$sdk"
  echo "ANDROID_SDK_ROOT=$sdk"
} >> "$env_file"
{
  echo "$sdk/cmdline-tools/latest/bin"
  echo "$sdk/platform-tools"
  echo "$flutter_dir/bin"
} >> "$path_file"
