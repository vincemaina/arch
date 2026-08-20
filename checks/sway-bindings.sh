#!/usr/bin/env bash
set -uo pipefail

# Prints every key binding the sway config defines, and fails if any combination
# is defined twice.
#
# sway does not complain about a duplicate: the later definition silently wins.
# That is how $mod+b and $mod+e came to launch a browser and a file manager
# while the split and layout-toggle commands they replaced simply stopped
# existing, with nothing anywhere saying so.
#
# Bindings inside a mode are scoped to that mode, so they are compared only
# against others in the same mode.
#
# Reads the repository, not the running system, so it works anywhere.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWAY_DIR="$REPO_ROOT/setup/dotfiles/dot_config/sway"

declare -A seen=()
duplicates=0
count=0

# Sort the modifiers so that $mod+Shift+q and Shift+$mod+q are recognised as the
# same combination rather than as two different ones.
normalise() {
    tr '+' '\n' <<<"$1" | sort | paste -sd+ -
}

current_mode="default"

while IFS= read -r line; do
    # Track mode scope. A mode block opens with `mode "name" {` and closes on a
    # line that is just a brace.
    if [[ "$line" =~ ^[[:space:]]*mode[[:space:]]+\"([^\"]+)\"[[:space:]]*\{ ]]; then
        current_mode="${BASH_REMATCH[1]}"
        continue
    fi
    if [[ "$line" =~ ^[[:space:]]*\}[[:space:]]*$ ]]; then
        current_mode="default"
        continue
    fi

    [[ "$line" =~ ^[[:space:]]*bindsym[[:space:]] ]] || continue

    # Drop the keyword, then any --flags, leaving the combination and command.
    rest="${line#"${line%%bindsym*}"}"
    rest="${rest#bindsym}"
    read -ra words <<<"$rest"

    idx=0
    while [[ $idx -lt ${#words[@]} && "${words[$idx]}" == --* ]]; do
        idx=$((idx + 1))
    done

    combo="${words[$idx]:-}"
    [[ -n "$combo" ]] || continue
    command="${words[*]:$((idx + 1))}"

    key="$current_mode|$(normalise "$combo")"
    count=$((count + 1))

    if [[ -n "${seen[$key]:-}" ]]; then
        duplicates=$((duplicates + 1))
        echo "  DUPLICATE  [$current_mode] $combo"
        echo "               first:  ${seen[$key]}"
        echo "               second: $command"
    else
        seen[$key]="$command"
        if [[ "$current_mode" == "default" ]]; then
            printf '  %-28s %s\n' "$combo" "$command"
        else
            printf '  [%s] %-22s %s\n' "$current_mode" "$combo" "$command"
        fi
    fi
done < <(
    # Expand `set` variables so $mod+b and Mod4+b compare equal, using the same
    # substitution approach as checks/sway-commands.sh, and read the fragments in
    # the order sway loads them.
    config="$(cat "$SWAY_DIR/config" "$SWAY_DIR"/config.d/*.conf)"
    expanded="$config"
    while IFS= read -r def; do
        [[ "$def" =~ ^[[:space:]]*set[[:space:]]+(\$[A-Za-z0-9_]+)[[:space:]]+(.*)$ ]] || continue
        expanded="${expanded//"${BASH_REMATCH[1]}"/${BASH_REMATCH[2]}}"
    done < <(grep -E '^[[:space:]]*set[[:space:]]+\$' <<<"$config")
    printf '%s\n' "$expanded"
)

echo
echo "$count bindings defined"

if [[ $duplicates -gt 0 ]]; then
    echo "$duplicates duplicate binding(s): the later definition silently wins."
    exit 1
fi

echo "No binding is defined twice."
