#!/usr/bin/env bash
# Verify vendored files against the exact public commit; never modify source.
set -euo pipefail
cd "$(dirname "$0")/.."
revision=73634519e4846047769726a24a1f6bc3dec6966d
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
if [ "$#" -eq 1 ]; then
  git -C "$1" archive "$revision" src | tar -x -C "$scratch"
else
  curl --fail --silent --show-error --location \
    "https://codeload.github.com/Roasbeef/jevelin/tar.gz/$revision" \
    -o "$scratch/source.tar.gz"
  tar -xzf "$scratch/source.tar.gz" --strip-components=1 -C "$scratch"
fi
diff -u "$scratch/src/jevelin.gleam" src/jevelin.gleam
diff -ru "$scratch/src/jevelin" src/jevelin
printf 'Jevelin source matches %s\n' "$revision"
