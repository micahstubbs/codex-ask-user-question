# codex-ask-user-question

A [Codex CLI](https://github.com/openai/codex) skill that ports the
[Claude Code](https://claude.com/claude-code) `AskUserQuestion` interview
pattern onto Codex's native `request_user_input` tool.

Say something like...

```console
interview me about the caching layer
```

... or "ask me questions about ...", and the Codex agent will explore your repo,
then ask one structured question at a time with: 

- a short header
- two to four mutually exclusive options (each with a one-line tradeoff statement),
- a recommended option that is shown first
  
The skill waits for your answer before asking the next one, and stops
when there is enough clarity to plan or build.

## Why

While Codex has no `AskUserQuestion` like Claude Code, it _does_ have 
`request_user_input`, which renders the same kind of selectable-option 
prompt but is only offered in Plan mode by default. Left to itself the 
model tends to fall back to a wall of prose questions, or to skip asking 
and guess. This skill does three things:

- **Prefers the native tool whenever it is listed**, regardless of what the
  collaboration mode is called, and tells the model not to infer that the
  tool is missing just because the session is in Default mode.
- **Fixes the question shape** so answers are easy to give: header of at most
  12 characters, short labels, recommended option first, no hand-rolled
  "Other" (Codex adds free-form Other itself).
- **Falls back to one concise Markdown question** only when the tool is
  absent or the runtime rejects the call, and says so once.

## Contents

| Path | What it is |
| --- | --- |
| `skills/ask-user-question/SKILL.md` | The skill: interview workflow, question-design rules, Codex tool usage, Markdown fallback |
| `skills/ask-user-question/agents/openai.yaml` | Codex skill manifest (display name, picker description, default prompt) |
| `install.sh` | Symlinks or copies the skill into a Codex config dir; `--uninstall` removes only what it installed |
| `scripts/enable-request-user-input.sh` | Turns on the Default-mode feature flag via `codex features enable`; `--check` and `--dry-run` never change anything |
| `tests/run-tests.sh` | Plain-bash smoke tests: skill structure, manifest, installer, enable script, path-leak scan |

## Install

Requires Codex CLI and `bash` 4.0+.

```bash
git clone https://github.com/micahstubbs/codex-ask-user-question.git
cd codex-ask-user-question
./install.sh
```

That symlinks the skill into `~/.codex/skills/ask-user-question/`, so
`git pull` updates it. Other options:

```bash
./install.sh /path/to/.codex    # a different config directory
./install.sh --copy             # independent files instead of a symlink
./install.sh --uninstall        # remove what install.sh installed, nothing else
```

Then enable `request_user_input` in Default mode and restart Codex:

```bash
scripts/enable-request-user-input.sh          # runs: codex features enable default_mode_request_user_input
scripts/enable-request-user-input.sh --check  # exit 0 if already on
```

The flag is read when a Codex process starts. Plan mode exposes the tool
without it.

## How the port maps

| Claude Code | Codex |
| --- | --- |
| `AskUserQuestion` tool | `request_user_input` |
| Up to 4 questions per call | One question per call |
| `header` (max 12 chars), `options[].label`, `options[].description` | Same fields, same limits |
| "Other" added automatically | "Other" added automatically; do not add one |
| Always available | Plan mode, or Default mode with `features.default_mode_request_user_input` |

## Development

```bash
npm test          # or: bash tests/run-tests.sh
```

Tests run inside a `mktemp -d` scratch directory and never touch your real
`~/.codex`. One test greps the shipped files for absolute home paths; if it
fails, something machine-specific leaked in.

## Pre-open-source review checklist

This repo is private until the items below are done.

- [x] **License: Apache-2.0.** `LICENSE` file added and `package.json` updated.
- [ ] **Read every file once more before flipping public.** The scrub gate
      checks paths and identifiers, not judgment.
- [ ] **Keep or trim the scaffolding.** `CLAUDE.md` mentions the beads issue
      tracker, which this repo does not ship. Either keep the short note or
      remove it. `.beads/` is gitignored and was never committed.
- [ ] **Decide whether to ship the Claude Code variant** of the same skill
      alongside this one, or leave this repo Codex-only.

## Related

- [Codex CLI skills documentation](https://developers.openai.com/codex/skills)
- The same interview pattern for Claude Code is built into its
  `AskUserQuestion` tool; this repo is the Codex side.
