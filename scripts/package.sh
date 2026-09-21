#!/usr/bin/env bash
# Stage only installable source; local build caches must not enter acquisition.
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:?usage: scripts/package.sh NEW_OUTPUT_DIRECTORY}"
mkdir "$out"
cp -R src "$out/src"
cp extension.toml gleam.toml "$out/"
for file in README.md LICENSE; do
  if [ -f "$file" ]; then cp "$file" "$out/"; fi
done
