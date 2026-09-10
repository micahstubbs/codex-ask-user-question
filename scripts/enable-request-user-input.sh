#!/usr/bin/env bash
# Enable Codex's request_user_input tool in Default mode.
#
#   scripts/enable-request-user-input.sh            # enable via the codex CLI
#   scripts/enable-request-user-input.sh --check    # report current state, change nothing
#   scripts/enable-request-user-input.sh --dry-run  # print what would run
#
# The skill in this repo prefers the native request_user_input tool over a
# Markdown question. Codex exposes that tool in Plan mode unconditionally and
# in Default mode only when the feature flag below is on. The flag is read at
# process start, so restart or reopen the Codex session after enabling it.
#
# Honors CODEX_HOME (default ~/.codex) when checking config.toml, and CODEX_BIN
# (default: the `codex` on PATH) for the CLI.

set -euo pipefail

FLAG="default_mode_request_user_input"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CODEX_BIN="${CODEX_BIN:-codex}"
CONFIG="$CODEX_HOME/config.toml"

CHECK=false
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) CHECK=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *) echo "enable-request-user-input.sh: unknown option '$1'" >&2; exit 2 ;;
    esac
done

# Reports whether config.toml already carries `<flag> = true` under [features].
flag_enabled() {
    [[ -f "$CONFIG" ]] || return 1
    awk -v flag="$FLAG" '
        /^\[/ { in_features = ($0 == "[features]") }
        in_features && $1 == flag && $2 == "=" && $3 == "true" { found = 1 }
        END { exit !found }
    ' "$CONFIG"
}

if flag_enabled; then
    echo "enabled  $FLAG ($CONFIG)"
    exit 0
fi

if [[ "$CHECK" == true ]]; then
    echo "disabled $FLAG ($CONFIG)"
    exit 1
fi

CMD=("$CODEX_BIN" features enable "$FLAG")

if [[ "$DRY_RUN" == true ]]; then
    echo "would run: ${CMD[*]}"
    exit 0
fi

if ! command -v "$CODEX_BIN" >/dev/null 2>&1; then
    echo "error: '$CODEX_BIN' not found on PATH; install Codex CLI or set CODEX_BIN" >&2
    exit 1
fi

"${CMD[@]}"
echo "enabled  $FLAG. Restart your Codex session for it to take effect."
