#!/usr/bin/env bash
# Install the ask-user-question skill into a Codex CLI configuration directory.
#
#   ./install.sh                    # symlink into ~/.codex
#   ./install.sh /path/to/.codex    # install into a different config dir
#   ./install.sh --copy             # copy instead of symlinking
#   ./install.sh --uninstall        # remove what this script installed
#
# The skill lands in <config>/skills/ask-user-question/. Symlinks are the
# default so `git pull` updates the installed skill; pass --copy if you would
# rather have independent files you can edit in place.
#
# The skill uses Codex's native request_user_input tool. In Default mode that
# tool is behind a feature flag; scripts/enable-request-user-input.sh turns it
# on. This installer never edits your Codex config.

set -euo pipefail

REPO_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKILLS=(ask-user-question)

MODE=symlink
UNINSTALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --copy) MODE=copy; shift ;;
        --symlink) MODE=symlink; shift ;;
        --uninstall) UNINSTALL=true; shift ;;
        -h|--help) sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        -*) echo "install.sh: unknown option '$1'" >&2; exit 2 ;;
        *) break ;;
    esac
done

CONFIG_DIR="${1:-$HOME/.codex}"
SKILLS_DIR="$CONFIG_DIR/skills"

# True when $1 is a symlink pointing at $2, or a byte-identical copy of $2.
installed_by_us() {
    local target="$1" src="$2"
    if [[ -L "$target" ]]; then
        [[ "$(readlink "$target")" == "$src" ]]
    elif [[ -e "$target" && -e "$src" ]]; then
        diff -r -q "$src" "$target" >/dev/null 2>&1
    else
        return 1
    fi
}

if [[ "$UNINSTALL" == true ]]; then
    for skill in "${SKILLS[@]}"; do
        target="$SKILLS_DIR/$skill"
        src="$REPO_DIR/skills/$skill"
        if [[ ! -e "$target" && ! -L "$target" ]]; then
            echo "absent   $target"
        elif installed_by_us "$target" "$src"; then
            rm -rf "$target"
            echo "removed  $target"
        else
            echo "skipped  $target (modified, or not installed by this script)"
        fi
    done
    echo
    echo "Left alone: $CONFIG_DIR/config.toml (feature flags are yours to manage)"
    exit 0
fi

mkdir -p "$SKILLS_DIR"

install_one() {
    local src="$1" target="$2"

    if [[ -e "$target" || -L "$target" ]]; then
        if installed_by_us "$target" "$src"; then
            echo "ok       $target (already installed)"
            return 0
        fi
        echo "error: $target already exists and was not installed by this script." >&2
        echo "       Move it aside, or install into another config dir:" >&2
        echo "         ./install.sh /path/to/.codex" >&2
        return 1
    fi

    if [[ "$MODE" == copy ]]; then
        cp -R "$src" "$target"
        echo "copied   $target"
    else
        ln -s "$src" "$target"
        echo "linked   $target -> $src"
    fi
}

failed=0
for skill in "${SKILLS[@]}"; do
    install_one "$REPO_DIR/skills/$skill" "$SKILLS_DIR/$skill" || failed=1
done

if [[ "$failed" -ne 0 ]]; then
    echo >&2
    echo "install.sh: one or more items were not installed (see errors above)" >&2
    exit 1
fi

echo
echo "Installed into $CONFIG_DIR."
echo "To use request_user_input in Default mode, run: scripts/enable-request-user-input.sh"
echo "Then start a new Codex session and say \"interview me about ...\"."
