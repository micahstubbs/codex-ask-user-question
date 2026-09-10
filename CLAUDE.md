# CLAUDE.md

Guidance for Claude Code and Codex agents working in this repository.

## What this repo is

`codex-ask-user-question` is a single Codex CLI skill that ports Claude Code's
`AskUserQuestion` interview pattern onto Codex's native `request_user_input`
tool, plus an installer, a feature-flag helper, and tests. It is headed for
public release. Keep it that way: no private paths, no machine-specific
assumptions, no references to skills or tooling that do not ship here or
install from here.

## Issue tracking

The author tracks work on this repo with the
[beads](https://github.com/selfcuration/beads_rust) issue tracker (`br`).
It is not required to use or contribute to the skill. `.beads/` is gitignored
on purpose: the tracker's export embeds absolute source paths, which would
leak a home directory into a public tree.

## Conventions

- **Markdown, YAML, and bash only. No runtime dependencies.** `package.json`
  exists for `npm test` and metadata; never add npm dependencies.
- **The SKILL.md front-matter `name` must equal its directory name.** Codex
  resolves skills by that name. There is a test for this.
- **`agents/openai.yaml` is the skill manifest.** Its `short_description` is
  what the skill picker shows; keep it a complete sentence under 80
  characters. A test checks that it is not cut off mid-quote.
- **The skill prefers the native tool.** Any edit to SKILL.md must keep
  `request_user_input` as the default and the Markdown fallback as the
  exception. Do not describe `AskUserQuestion` as something Codex has.
- **Deterministic logic goes in `scripts/`, judgment goes in SKILL.md.**
- **Installers never remove what they did not install.** `install.sh` checks
  symlink targets and byte-identity before removing anything. The enable
  script never edits `config.toml` directly; it shells out to
  `codex features enable` and only after `--check` says the flag is off.
- **Guard non-zero exits under `set -euo pipefail`.** `grep`, `diff`, and
  `awk` exit 1 on legitimate outcomes.
- Support bash 4.0+ and both GNU and BSD/macOS userland.

## Keeping copies in step

The same SKILL.md is also vendored by its author into a personal Codex config
and a superpowers fork. When editing the skill here, the other copies need the
same change; this repo is the canonical source.

## Before committing

```bash
./tests/run-tests.sh     # must be 0 failures
```

Tests are plain bash with no framework. Anything touching the filesystem must
work inside a `mktemp -d` scratch directory. `install.sh` and the enable
script both take a config location (argument or `CODEX_HOME`) specifically
so tests can point them somewhere harmless.

One test greps the shipped files for absolute home paths. If it fails,
something machine-specific leaked in; parameterize it rather than deleting
the test.
