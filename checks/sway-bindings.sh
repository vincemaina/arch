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

# ----------------------------------------------------------------------
# Key repeat
# ----------------------------------------------------------------------
#
# sway repeats a binding for as long as the key is held unless --no-repeat says
# otherwise, and this machine sets repeat_rate 40. That combination turns a
# fractionally-long press on $mod+q into every window on the workspace closing.
#
# So the policy is: repeat off by default, on by exception, and the exceptions
# are the bindings where holding the key IS the gesture. A binding added without
# --no-repeat and not on this list is a mistake that is invisible until someone
# holds the key a beat too long, which is exactly the kind of thing this
# repository checks rather than remembers.
REPEATABLE=(
    '$mod+Shift+$left' '$mod+Shift+$down' '$mod+Shift+$up' '$mod+Shift+$right'
    '$left' '$down' '$up' '$right'
    'XF86AudioLowerVolume' 'XF86AudioRaiseVolume'
    'XF86MonBrightnessDown' 'XF86MonBrightnessUp'
)

repeating=0
while IFS= read -r line; do
    # The key combo is the first field that is not a flag.
    combo="$(sed -E 's/^[[:space:]]*bindsym([[:space:]]+--[a-z-]+)*[[:space:]]+//; s/[[:space:]].*//' <<<"$line")"
    # A pointer button cannot repeat, so --no-repeat on one is meaningless.
    #
    # sway(5): the command "will be run repeatedly when the key is held,
    # according to the repeat settings specified in the input configuration" -
    # that is keyboard repeat_delay and repeat_rate, which a pointer has no
    # equivalent of. A scroll wheel emits discrete clicks and a button emits one
    # press and one release; there is nothing to repeat and no rate to repeat at.
    #
    # Without this, $mod+scroll to resize a window fails the check, and the only
    # ways to satisfy it are a meaningless flag or a whitelist entry claiming
    # holding it is the gesture. Both would be lies written to make a check
    # green, which is worse than the check not knowing.
    if [[ "$combo" == *button[0-9]* ]]; then
        continue
    fi

    allowed=false
    for k in "${REPEATABLE[@]}"; do
        [[ "$combo" == "$k" ]] && allowed=true && break
    done
    $allowed && continue
    printf '  repeats: %-24s %s\n' "$combo" "$(sed -E 's/^[[:space:]]*bindsym([[:space:]]+--[a-z-]+)*[[:space:]]+[^[:space:]]+[[:space:]]+//' <<<"$line" | cut -c1-44)"
    repeating=$((repeating + 1))
done < <(grep -hE '^[[:space:]]*bindsym' "$SWAY_DIR/config" "$SWAY_DIR"/config.d/*.conf 2>/dev/null | grep -v -- '--no-repeat')

if [[ $repeating -gt 0 ]]; then
    echo
    echo "$repeating binding(s) repeat while held and are not on the whitelist."
    echo "Add --no-repeat, or add the key to REPEATABLE here if holding it is the point."
    exit 1
fi

echo "Every binding either does not repeat, or is one where holding it is the gesture."
