#!/usr/bin/env bash
# Smoke tests for codex-ask-user-question. No test framework required:
#   ./tests/run-tests.sh
#
# Everything that touches the filesystem works inside a mktemp -d scratch
# directory, so the tests never see or modify your real ~/.codex.

set -uo pipefail

REPO_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() {
    FAIL=$((FAIL + 1))
    printf '  FAIL %s\n' "$1"
    [[ $# -gt 1 ]] && printf '       %s\n' "$2"
    return 0
}

assert_eq() {
    local desc="$1" actual="$2" expected="$3"
    if [[ "$actual" == "$expected" ]]; then pass "$desc"
    else fail "$desc" "expected '$expected', got '$actual'"; fi
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then pass "$desc"
    else fail "$desc" "expected to contain '$needle', got: $haystack"; fi
}

assert_not_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if [[ "$haystack" != *"$needle"* ]]; then pass "$desc"
    else fail "$desc" "expected NOT to contain '$needle'"; fi
}

assert_status() {
    local desc="$1" expected="$2"; shift 2
    "$@" >/dev/null 2>&1
    assert_eq "$desc" "$?" "$expected"
}

SCRATCH="$(mktemp -d)"
cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT

# ---------------------------------------------------------------- shell syntax

echo "== shell syntax =="
for f in "$REPO_DIR/install.sh" "$REPO_DIR/scripts/"*.sh "$REPO_DIR/tests/run-tests.sh"; do
    assert_status "bash -n $(basename "$f")" 0 bash -n "$f"
done

# ------------------------------------------------------------ skill structure

echo "== skill structure =="
SKILL_DIR="$REPO_DIR/skills/ask-user-question"
SKILL_MD="$SKILL_DIR/SKILL.md"
MANIFEST="$SKILL_DIR/agents/openai.yaml"

if [[ -f "$SKILL_MD" ]]; then pass "SKILL.md exists"; else fail "SKILL.md exists" "missing"; fi
if [[ -f "$MANIFEST" ]]; then pass "agents/openai.yaml exists"; else fail "agents/openai.yaml exists" "missing"; fi

# Codex resolves a skill by its front-matter name; it must equal the
# directory name or the skill is invocable only under a name nobody will guess.
assert_eq "front matter starts at line 1" "$(head -1 "$SKILL_MD")" "---"
declared="$(awk 'NR>1 && /^---$/{exit} /^name:/{print $2}' "$SKILL_MD")"
assert_eq "front matter name matches directory" "$declared" "ask-user-question"
if awk 'NR>1 && /^---$/{exit} /^description:/{found=1} END{exit !found}' "$SKILL_MD"; then
    pass "front matter declares a description"
else
    fail "front matter declares a description" "no description: line"
fi

body="$(cat "$SKILL_MD")"
assert_contains "skill names the native Codex tool" "$body" "request_user_input"
assert_contains "skill names the Default-mode feature flag" "$body" "default_mode_request_user_input"
assert_contains "skill carries a Markdown fallback" "$body" "## Markdown Fallback"
assert_not_contains "skill does not name a Claude-only tool as native to Codex" "$body" "native \`AskUserQuestion\`"

# The manifest's short_description is what the skill picker shows. An earlier
# version was cut off mid-word by a copy step; guard against that recurring.
short="$(sed -n 's/^ *short_description: *"\(.*\)"$/\1/p' "$MANIFEST")"
escaped_quotes="$(printf '%s' "$short" | grep -o '\\"' | wc -l)"
if [[ -n "$short" && $((escaped_quotes % 2)) -eq 0 && "$short" != *" use" && ${#short} -le 80 ]]; then
    pass "openai.yaml short_description is complete and under 80 chars"
else
    fail "openai.yaml short_description is complete and under 80 chars" "got '$short'"
fi
assert_contains "openai.yaml default_prompt invokes the skill by name" \
    "$(cat "$MANIFEST")" '$ask-user-question'

# ------------------------------------------------------------------- scrubbing

echo "== no machine-specific paths =="
LEAKS="$(grep -rInE '/home/[a-z]|~/wk/|~/keys/|/Users/[a-z]' \
    "$REPO_DIR/skills" "$REPO_DIR/scripts" "$REPO_DIR/install.sh" \
    "$REPO_DIR/README.md" "$REPO_DIR/CLAUDE.md" "$REPO_DIR/docs" 2>/dev/null || true)"
assert_eq "no absolute home paths in shipped files" "$LEAKS" ""

# -------------------------------------------------------------------- install

echo "== install.sh =="
CONFIG="$SCRATCH/config"

out="$("$REPO_DIR/install.sh" "$CONFIG" 2>&1)"
assert_eq "install exits 0" "$?" "0"
assert_contains "install reports linking" "$out" "linked"
if [[ -f "$CONFIG/skills/ask-user-question/SKILL.md" ]]; then
    pass "installed skill resolves to a SKILL.md"
else
    fail "installed skill resolves to a SKILL.md" "missing"
fi
if [[ -f "$CONFIG/skills/ask-user-question/agents/openai.yaml" ]]; then
    pass "installed skill carries its openai.yaml"
else
    fail "installed skill carries its openai.yaml" "missing"
fi

out="$("$REPO_DIR/install.sh" "$CONFIG" 2>&1)"
assert_contains "re-install is idempotent" "$out" "already installed"

# A skill the user put there themselves must not be clobbered.
mkdir -p "$SCRATCH/config2/skills/ask-user-question"
echo "mine" > "$SCRATCH/config2/skills/ask-user-question/SKILL.md"
out="$("$REPO_DIR/install.sh" "$SCRATCH/config2" 2>&1)"
assert_eq "install refuses to clobber a foreign skill" "$?" "1"
assert_eq "foreign skill left untouched" \
    "$(cat "$SCRATCH/config2/skills/ask-user-question/SKILL.md")" "mine"

out="$("$REPO_DIR/install.sh" --uninstall "$CONFIG" 2>&1)"
assert_contains "uninstall reports removal" "$out" "removed"
if [[ -e "$CONFIG/skills/ask-user-question" || -L "$CONFIG/skills/ask-user-question" ]]; then
    fail "uninstall removes the installed skill" "still present"
else
    pass "uninstall removes the installed skill"
fi

out="$("$REPO_DIR/install.sh" --uninstall "$SCRATCH/config2" 2>&1)"
assert_contains "uninstall skips foreign files" "$out" "skipped"
assert_eq "foreign skill survives uninstall" \
    "$(cat "$SCRATCH/config2/skills/ask-user-question/SKILL.md")" "mine"

CONFIG3="$SCRATCH/config3"
"$REPO_DIR/install.sh" --copy "$CONFIG3" >/dev/null 2>&1
if [[ -f "$CONFIG3/skills/ask-user-question/SKILL.md" && ! -L "$CONFIG3/skills/ask-user-question" ]]; then
    pass "--copy installs a real directory"
else
    fail "--copy installs a real directory" "missing or still a symlink"
fi

assert_status "unknown option exits 2" 2 "$REPO_DIR/install.sh" --nope

# ---------------------------------------------------- enable-request-user-input

# Offline: the script only shells out to `codex` on a real enable, and every
# case here either finds the flag already set, checks, or dry-runs.
echo "== enable-request-user-input.sh =="
EN="$REPO_DIR/scripts/enable-request-user-input.sh"
FAKE_HOME="$SCRATCH/codex-home"
mkdir -p "$FAKE_HOME"

out="$("$EN" --help 2>&1)"
assert_eq "--help exits 0" "$?" "0"
assert_contains "--help documents --check" "$out" "--check"
assert_status "unknown option exits 2" 2 "$EN" --nope

out="$(CODEX_HOME="$FAKE_HOME" "$EN" --check 2>&1)"
assert_eq "--check with no config exits 1" "$?" "1"
assert_contains "--check reports disabled" "$out" "disabled"

out="$(CODEX_HOME="$FAKE_HOME" CODEX_BIN=/nonexistent/codex "$EN" --dry-run 2>&1)"
assert_eq "--dry-run exits 0 without a codex binary" "$?" "0"
assert_contains "--dry-run prints the enable command" "$out" "features enable default_mode_request_user_input"

printf '[features]\nunified_exec = true\ndefault_mode_request_user_input = true\n' > "$FAKE_HOME/config.toml"
out="$(CODEX_HOME="$FAKE_HOME" "$EN" --check 2>&1)"
assert_eq "--check with the flag set exits 0" "$?" "0"
assert_contains "--check reports enabled" "$out" "enabled"

# The flag under a different table must not count.
printf '[other]\ndefault_mode_request_user_input = true\n' > "$FAKE_HOME/config.toml"
assert_status "flag outside [features] is not enabled" 1 env CODEX_HOME="$FAKE_HOME" "$EN" --check

out="$(CODEX_HOME="$FAKE_HOME" CODEX_BIN=/nonexistent/codex "$EN" 2>&1)"
assert_eq "enable without a codex binary exits 1" "$?" "1"
assert_contains "enable without a codex binary says so" "$out" "not found"

echo
echo "passed: $PASS   failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
