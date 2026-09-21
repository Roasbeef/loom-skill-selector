# Loom skill selector

An opt-in Loom extension that proactively loads relevant skill instructions with
[Jev](https://docs.typesafe.ai/), using the typed
[Jevelin](https://github.com/Roasbeef/jevelin) client. No manual skill invocation
or model-visible selector tool is needed.

The extension ranks the catalogue previews supplied by Loom with one batch of
independent Noul questions. It returns up to three candidates scoring at least
0.85. Loom resolves those names to captured documents, adds source attribution,
and enforces the shared count/token limits. Selection does not execute a script,
approve a tool call, or override `disable-model-invocation`.

## Install

Requires Loom's `select_skills` hook (protocol 045, linked in the integration PR).
An older Loom rejects the manifest instead of silently ignoring the hook.

Set `JEV_AUTHORIZATION` in the **daemon's** environment to the complete
`Bearer <your TypeSafe API key>` header value before starting it. Use your normal
secret manager; the manifest contains only the variable name. The broker inserts
that value for `api.typesafe.ai`, and the satellite never receives the variable.

```sh
loomd ext install https://github.com/Roasbeef/loom-skill-selector --rev <reviewed-commit>
```

Review the install's hook and egress permissions. Open a new session so it picks
up the extension. Ask an ordinary task such as “review this change for bugs”
with a relevant `review` skill in a supported skill directory. Loom discovers
skills from `~/.agents/skills`, `~/.agents/skill`, `~/.claude/skills` and
`~/.Claude/skills`; this extension does not add other discovery locations.

For a local install, create a clean source tree with
`scripts/package.sh /absolute/path/to/new-directory`, then install that path.
Do not install a development directory containing build caches.

## Disclosure and failure behavior

Loom sends the extension the projected messages and at most 64 eligible skill
previews. The external Jev request contains only the last 4,096 graphemes of the
latest user text plus names, descriptions and 512-grapheme skill previews. Tool
results, assistant text and older messages are not sent by this policy. Mixed
image/text messages contribute only their text. Installing this extension
therefore authorizes task and preview disclosure to TypeSafe under its egress
policy; do not install it for sessions where that disclosure is unwanted.

Native notes, distilled-memory digests and imported hook notes are filtered by
their existing attribution prefixes. This is a relevance/disclosure policy over
projected messages, not a provenance boundary: another installed context hook
can modify those messages before this selector sees them.

One latest-wins memory cell caches the decision by operation, exact task and
previews. Concurrent operations can evict each other's entry without reusing
one another's result. No background process or retries are added. Failed service
calls cache no selection for that identity; oversized memory records can miss.
The existing five-second hook deadline applies. HTTP errors, malformed replies,
no qualifying candidates and missing credentials leave ordinary skill use
available. A fatal hook deadline can retire the satellite for that session under
Loom's existing hook-host rules.

Full skill instructions are recreated on each provider projection, so previous
transient injections do not accumulate in the durable transcript. This is not a
permanent activation state: a changed task or operation is selected again.
The 0.85 threshold is a heuristic, not a calibrated accuracy guarantee.

## Development and dependency provenance

```sh
scripts/check.sh /absolute/path/to/loom-with-protocol-045
scripts/verify-jevelin.sh /absolute/path/to/jevelin
```

Jevelin is source-vendored at
`73634519e4846047769726a24a1f6bc3dec6966d`. The verification script compares every
vendored module to that public revision (omit the path to fetch it). Vendoring
lets Loom vet every pure module and build offline from its existing capability
seed; no new library is privileged inside the harness. `cap` and `ext` resolve
from Loom's seed during installation. The development manifest paths are only
local conveniences; the check script replaces them in a disposable package.

For the real install → jailed satellite → brokered TLS → provider test:

```sh
scripts/package.sh /absolute/path/to/clean-selector-source
cd /absolute/path/to/loom-with-protocol-045
make binaries codemode-seed
LOOM_SKILL_SELECTOR_SOURCE=/absolute/path/to/clean-selector-source \
  bash scripts/test.sh client --match skill_selector_reaches_provider
```

The supplied source opts into a mandatory test: missing prerequisites fail.
The test changes only the endpoint/manifest origin to a local TLS fixture. It
uses the actual library decoder and extension policy, verifies credential
confinement and confirms full skill text reaches a runtime provider request.
It proves integration, not live Jev quality. No authenticated inference result
is claimed. Start relevance evaluation with positive tasks, near misses,
quoted skill names, overlapping skills and tasks that require no skill.
