#!/usr/bin/env bash
# Test in a disposable package against an explicit Loom SDK checkout.
set -euo pipefail
cd "$(dirname "$0")/.."
loom="${1:?usage: scripts/check.sh /absolute/path/to/loom}"
loom="$(cd "$loom" && pwd)"
gleam format --check src test
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
cp -R src test gleam.toml "$scratch/"
python3 - "$scratch/gleam.toml" "$loom" <<'PY'
import json, pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
for package in ('cap', 'ext'):
    target = json.dumps(str(pathlib.Path(sys.argv[2]) / 'packages' / package))
    text = re.sub(rf'^{package} = .*$', f'{package} = {{ path = {target} }}', text, flags=re.M)
path.write_text(text)
PY
(cd "$scratch" && gleam build --warnings-as-errors && gleam test)
