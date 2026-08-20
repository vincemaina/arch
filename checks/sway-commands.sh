#!/usr/bin/env bash
set -euo pipefail

# Verifies that every external command the sway session invokes is provided by
# a package this repository declares in setup/packages/.
#
# This exists because the config and the manifests could drift apart with
# nothing noticing: media keys called playerctl, which was never installed, so
# pressing them did nothing and no error appeared anywhere.
#
# Runs on an installed Arch machine, since resolving a command to its owning
# package needs the local package database.
#
# Three surfaces are checked:
#
#   * `exec` targets in the sway config, with `set` variables expanded
#   * absolute ExecStart/ExecReload paths in the session units
#   * commands declared in a `# requires:` header by helper scripts
#
# Helper scripts are declared rather than parsed, because working out what an
# arbitrary shell script might run is not something to guess at. The check
# enforces the convention: a helper with no `# requires:` header is a failure.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES="$REPO_ROOT/setup/dotfiles"
SWAY_DIR="$DOTFILES/dot_config/sway"
UNIT_DIR="$DOTFILES/dot_config/systemd/user"
BIN_DIR="$DOTFILES/dot_local/bin"

FAILURES=0

fail() {
    echo "  FAIL  $*"
    FAILURES=$((FAILURES + 1))
}

ok() {
    echo "  ok    $*"
}

for cmd in pacman pactree; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Required command not found: $cmd" >&2
        echo "This check runs on an installed Arch system." >&2
        [[ "$cmd" == "pactree" ]] && echo "pactree comes from pacman-contrib." >&2
        exit 1
    fi
done

# ----------------------------------------------------------------------
# What the repository declares
# ----------------------------------------------------------------------

mapfile -t DECLARED < <(
    grep -hEv '^[[:space:]]*(#|$)' "$REPO_ROOT"/setup/packages/*.txt | sort -u
)

echo "==> ${#DECLARED[@]} packages declared"

# A command may legitimately come from a dependency rather than a declared
# package: `date` belongs to coreutils, which arrives with base. Resolve the
# full dependency closure so those are accepted, while something pulled in by
# nothing we declare is still caught.
echo "==> Resolving dependency closure"

ALLOWED="$(
    {
        printf '%s\n' "${DECLARED[@]}"
        for pkg in "${DECLARED[@]}"; do
            pactree -lu "$pkg" 2>/dev/null || true
        done
    } | sort -u
)"

echo "    $(printf '%s\n' "$ALLOWED" | grep -c .) packages reachable from the manifests"

# ----------------------------------------------------------------------
# Commands the session invokes
# ----------------------------------------------------------------------

collect_sway_commands() {
    # Expand `set $var value` definitions, then take the word after `exec`.
    local config
    config="$(cat "$SWAY_DIR/config" "$SWAY_DIR"/config.d/*.conf)"

    local expanded="$config"
    while IFS= read -r line; do
        [[ "$line" =~ ^set[[:space:]]+(\$[A-Za-z0-9_]+)[[:space:]]+(.*)$ ]] || continue
        local name="${BASH_REMATCH[1]}" value="${BASH_REMATCH[2]}"
        expanded="${expanded//"$name"/$value}"
    done < <(grep -E '^[[:space:]]*set[[:space:]]+\$' <<<"$config")

    grep -oE '\bexec(_always)?[[:space:]]+[^[:space:]]+' <<<"$expanded" |
        awk '{print $2}'
}

collect_unit_commands() {
    grep -hoE '^Exec(Start|Reload)=[^[:space:]]+' "$UNIT_DIR"/*.service |
        cut -d= -f2-
}

collect_declared_requirements() {
    local script
    for script in "$BIN_DIR"/*; do
        [[ -f "$script" ]] || continue
        if ! grep -qE '^# requires:' "$script"; then
            fail "$(basename "$script") has no '# requires:' header"
            continue
        fi
        grep -E '^# requires:' "$script" | sed -E 's/^# requires:[[:space:]]*//' | tr ' ' '\n'
    done
}

echo "==> Collecting commands"

mapfile -t COMMANDS < <(
    {
        collect_sway_commands
        collect_unit_commands
        collect_declared_requirements
    } | grep -vE '^[[:space:]]*$' | sort -u
)

echo "    ${#COMMANDS[@]} distinct commands referenced"
echo

# ----------------------------------------------------------------------
# Resolve each one
# ----------------------------------------------------------------------

for cmd in "${COMMANDS[@]}"; do
    # Paths belonging to this repository are ours, not a package's.
    if [[ "$cmd" == *"/.local/bin/"* || "$cmd" == "%h/"* ]]; then
        name="${cmd##*/}"
        if [[ -f "$BIN_DIR/executable_$name" ]]; then
            ok "$name (this repository)"
        else
            fail "$cmd refers to a helper this repository does not ship"
        fi
        continue
    fi

    path="$(command -v "$cmd" 2>/dev/null || true)"
    if [[ -z "$path" ]]; then
        fail "$cmd is not installed"
        continue
    fi

    owner="$(pacman -Qoq "$path" 2>/dev/null || true)"
    if [[ -z "$owner" ]]; then
        fail "$cmd ($path) is owned by no package"
        continue
    fi

    if grep -qxF "$owner" <<<"$ALLOWED"; then
        ok "$cmd -> $owner"
    else
        fail "$cmd -> $owner, which nothing in setup/packages/ declares or depends on"
    fi
done

echo
if [[ $FAILURES -eq 0 ]]; then
    echo "All referenced commands are accounted for."
else
    echo "$FAILURES problem(s) found."
    exit 1
fi
