#!/usr/bin/env bash
set -uo pipefail

# Every keyboard shortcut this setup defines, grouped by the context it applies
# in, and derived from the actual configuration rather than a list maintained by
# hand — a hand-written list is wrong the first time someone changes a binding
# and forgets to update it.
#
# This is a report, not a check, which is why it lives in tools/ rather than
# checks/. It answers questions a per-tool view cannot: does the same action use
# the same key in different tools, does a key mean something contradictory in the
# terminal and the compositor, and is anything bound in two places at once.
#
# A key meaning different things in different contexts is not automatically
# wrong. The point is to see it and decide, rather than meet it by surprise.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

heading() { printf '\n\033[1m%s\033[0m\n%s\n' "$1" "$(printf '%.0s─' $(seq 1 ${#1}))"; }

# Canonical form so a sway binding and a zsh binding can be compared at all:
# lower case, modifiers sorted, Mod4 spelled Super.
canon() {
    tr '[:upper:]' '[:lower:]' <<<"$1" |
        sed -e 's/mod4/super/g' -e 's/mod1/alt/g' -e 's/control/ctrl/g' |
        tr '+' '\n' | sort | paste -sd+ -
}

declare -A CONTEXT_OF=()
declare -A ACTION_OF=()

record() {  # context, key, action
    local key canonical
    canonical="$(canon "$2")"
    if [[ -n "${CONTEXT_OF[$canonical]:-}" && "${CONTEXT_OF[$canonical]}" != "$1" ]]; then
        CONTEXT_OF[$canonical]="${CONTEXT_OF[$canonical]}, $1"
        ACTION_OF[$canonical]="${ACTION_OF[$canonical]} | $1: $3"
    else
        CONTEXT_OF[$canonical]="$1"
        ACTION_OF[$canonical]="$1: $3"
    fi
}

# ----------------------------------------------------------------------
heading "Window management and system — sway"

# Reuses the binding check rather than parsing the config a second time, so the
# two cannot disagree about what is bound.
sway_out="$("$REPO_ROOT/checks/sway-bindings.sh" 2>/dev/null)"

while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]+([^[:space:]]+)[[:space:]]+(.*)$ ]] || continue
    key="${BASH_REMATCH[1]}"
    action="${BASH_REMATCH[2]}"
    [[ "$key" == "DUPLICATE" || "$key" == "first:" || "$key" == "second:" ]] && continue
    [[ "$key" == \[* ]] && continue      # mode-scoped, listed separately below
    printf '  %-26s %s\n' "$key" "$action"
    record "sway" "$key" "$action"
done <<<"$sway_out"

modes="$(grep -E '^\s+\[' <<<"$sway_out" || true)"
if [[ -n "$modes" ]]; then
    heading "Modes — sway (only active inside the mode)"
    sed 's/^  /  /' <<<"$modes"
fi

# ----------------------------------------------------------------------
heading "Terminal — zsh"

# Derived by difference: what an interactive shell binds, minus what a shell
# started with no configuration binds. Whatever remains is what this repository
# added, without needing a list of it.
if ! command -v zsh &>/dev/null; then
    echo "  zsh is not installed, so its bindings cannot be read"
else
    # Compared as key-and-widget pairs, not keys alone. fzf rebinds Ctrl+R,
    # which zsh already binds to its own history search, so filtering on the key
    # would hide the single most useful shortcut the shell config adds.
    default_pairs="$(zsh -f -c 'bindkey' 2>/dev/null | sort -u)"
    ours="$(zsh -i -c 'bindkey' 2>/dev/null)"

    if [[ -z "$ours" ]]; then
        echo "  could not read bindings from an interactive zsh"
    else
        while IFS= read -r line; do
            [[ "$line" =~ ^\"([^\"]+)\"[[:space:]]+(.*)$ ]] || continue
            seq="${BASH_REMATCH[1]}"
            widget="${BASH_REMATCH[2]}"
            grep -qxF "$line" <<<"$default_pairs" && continue

            # ^R -> ctrl+r, \ec -> alt+c. Anything else is left as written,
            # since a raw escape sequence is more honest than a wrong guess.
            pretty="$seq"
            if [[ "$seq" =~ ^\^([A-Za-z])$ ]]; then
                pretty="Ctrl+${BASH_REMATCH[1]}"
            elif [[ "$seq" =~ ^\\e([A-Za-z])$ ]]; then
                pretty="Alt+${BASH_REMATCH[1]}"
            fi
            printf '  %-26s %s\n' "$pretty" "$widget"
            record "zsh" "$pretty" "$widget"
        done <<<"$ours"
    fi
fi

# ----------------------------------------------------------------------
heading "Keys used in more than one context"

overlaps=0
for key in "${!CONTEXT_OF[@]}"; do
    [[ "${CONTEXT_OF[$key]}" == *,* ]] || continue
    overlaps=$((overlaps + 1))
    printf '  %-26s %s\n' "$key" "${ACTION_OF[$key]}"
done

if [[ $overlaps -eq 0 ]]; then
    echo "  None. Every key means one thing."
else
    echo
    echo "  Not necessarily wrong: an application may reasonably claim a key the"
    echo "  compositor also uses. Worth knowing which wins, and whether it should."
fi

# ----------------------------------------------------------------------
heading "Not covered yet"

covered_note() { printf '  %-14s %s\n' "$1" "$2"; }
covered_note "qutebrowser" "no config in this repository, so it uses its own defaults"
covered_note "neovim"      "no config in this repository, so it uses its own defaults"
covered_note "wofi"        "launcher keys are built in and not configurable here"
covered_note "foot"        "no keybindings overridden; foot defaults apply"
echo
echo "  Each becomes coverable by giving it a config this repository owns."
