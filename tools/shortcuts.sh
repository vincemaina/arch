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

# Two output formats from one parser. The terminal form is what you read; the
# markdown form is what docs/manual/ embeds, so the manual's keyboard reference
# is this table rather than a copy of it that goes stale the first time a
# binding changes. Everything below writes through heading/row/note/para rather
# than printf, so the two formats cannot describe different bindings.
FORMAT=term
case "${1:-}" in
    --markdown) FORMAT=markdown ;;
    "") ;;
    *) echo "usage: shortcuts.sh [--markdown]" >&2; exit 2 ;;
esac

IN_TABLE=0

heading() {
    table_end
    if [[ "$FORMAT" == markdown ]]; then
        printf '\n## %s\n' "$1"
    else
        printf '\n\033[1m%s\033[0m\n%s\n' "$1" "$(printf '%.0s\u2500' $(seq 1 ${#1}))"
    fi
}

# Markdown tables need a header row, and a cell cannot contain a raw pipe - a
# binding whose command pipes something would silently split into extra columns
# - so escape it rather than trust that none ever will.
table_start() {
    [[ "$FORMAT" == markdown ]] || return 0
    printf '\n| %s | %s |\n| --- | --- |\n' "$1" "$2"
    IN_TABLE=1
}

table_end() {
    [[ "$IN_TABLE" == 1 ]] || return 0
    IN_TABLE=0
}

row() {
    if [[ "$FORMAT" == markdown ]]; then
        printf '| `%s` | %s |\n' "${1//|/\\|}" "${2//|/\\|}"
    else
        printf '  %-26s %s\n' "$1" "$2"
    fi
}

# A plain line of prose inside a section.
para() {
    table_end
    if [[ "$FORMAT" == markdown ]]; then
        printf '\n%s\n' "$1"
    else
        printf '  %s\n' "$1"
    fi
}

# Something the reader needs but that is not a binding: set apart in both forms.
note() {
    table_end
    if [[ "$FORMAT" == markdown ]]; then
        printf '\n'
        while IFS= read -r l; do printf '> %s\n' "$l"; done <<<"$1"
    else
        printf '\n\033[2m%s\033[0m\n' "$1"
    fi
}

# Every name below is the modifier a program receives, which is not necessarily
# the key under your finger. keyd swaps left Alt and left Control beneath all of
# this, so "Ctrl" here is physically the key next to the space bar. Reporting
# the logical name is correct - it is what the binding does - but silently
# correct is how a report becomes misleading, so say so.
swap_note() {
    command -v keyd &>/dev/null || return 0
    systemctl is-active --quiet keyd 2>/dev/null || return 0
    grep -qF "leftcontrol = layer(alt)" /etc/keyd/default.conf 2>/dev/null || return 0
    note "keyd is swapping left Alt and left Control, so the modifiers named below
are the ones programs receive, not the keys where they used to be."
}

# The scroll layer, which nothing else here can see.
#
# This tool builds its table by parsing sway's config, so a binding that lives
# below the compositor is invisible to it - and the repository's stated policy
# is that a shortcut nobody knows about is a bug. That applies hardest to the
# ones no config file mentions.
scroll_note() {
    command -v keyd &>/dev/null || return 0
    systemctl is-active --quiet keyd 2>/dev/null || return 0
    # Match the layer name rather than the whole binding. The binding was
    # `capslock = layer(scroll)` and became
    # `capslock = overloadt2(scroll, capslock, 200)` when Caps Lock got its tap
    # back - at which point this guard silently stopped matching and the note
    # vanished from the report, with nothing to say it had. Exactly the coupling
    # CLAUDE.md warns about, in a file whose job is to stop shortcuts being
    # undiscoverable.
    grep -qE '^capslock *=.*\(scroll' /etc/keyd/default.conf 2>/dev/null || return 0
    note "Holding Caps Lock scrolls, underneath every program:

    j / k / h / l   scroll the focused window - these are real wheel events, so
                    they work inside a text field where Page Down would only
                    move the caret. They follow the POINTER, which sway keeps on
                    the focused window (mouse_warping container in 10-input.conf).
    d / u           Page Down / Page Up, by keyboard focus regardless

Tapping Caps Lock still toggles caps. These come from keyd rather than sway, so
they are not in the table below."
}

# The second Escape key, which is invisible for the same reason.
#
# The guard above learned the hard way that asserting a binding string couples
# this file to a config it does not own, and goes quiet when that config is
# reworded. So this one asserts nothing: it READS the key out of the [control]
# layer and reports whichever key is mapped to Escape there. Change the config
# to `semicolon = esc` and this note follows without being touched; take the
# binding out and the note disappears, which is correct. The only way it can
# lie is if it finds no key at all, in which case it says nothing.
escape_note() {
    command -v keyd &>/dev/null || return 0
    systemctl is-active --quiet keyd 2>/dev/null || return 0

    # ALL of them, not the first. Two keys are bound to Escape at once while
    # TASK-110 decides which to keep, and a reader who is told about one of
    # them has been told something true and useless.
    local keys
    keys="$(awk '
        /^\[/     { in_control = ($0 ~ /^\[control(:[A-Z]*)?\]/) ; next }
        !in_control { next }
        /^[a-z0-9]+[[:space:]]*=[[:space:]]*esc(ape)?[[:space:]]*$/ {
            sub(/[[:space:]]*=.*/, ""); print
        }
    ' /etc/keyd/default.conf 2>/dev/null)"
    [[ -n "$keys" ]] || return 0

    # keyd spells keys the way the kernel does. Only the ones a human would not
    # recognise need translating; anything else is printed as keyd names it,
    # which is worse to read than a real name and better than a wrong guess.
    pretty_key() {
        case "$1" in
            semicolon)  printf ';' ;;
            apostrophe) printf "'" ;;
            comma)      printf ',' ;;
            dot)        printf '.' ;;
            slash)      printf '/' ;;
            *)          tr '[:lower:]' '[:upper:]' <<<"$1" | tr -d '\n' ;;
        esac
    }

    local listed="" body="" k p
    while read -r k; do
        [[ -n "$k" ]] || continue
        p="$(pretty_key "$k")"
        listed="${listed:+$listed and }Ctrl+${p}"
        # Align the description at column 21, where the continuation lines
        # below sit. "    Ctrl+" is nine characters, so the pad is what is left
        # after the key name itself.
        body="${body}    Ctrl+${p}"
        body="${body}$(printf '%*s' $((12 - ${#p})) '')a real Escape key event, emitted by keyd at the\n"
        body="${body}                    evdev layer, so nvim, the backlog TUI, rofi, fzf and\n"
        body="${body}                    a browser all see what the Escape key sends.\n"
    done <<<"$keys"

    local trailer=""
    if grep -qx 'k' <<<"$keys"; then
        trailer="
Ctrl+K displaces what that chord meant elsewhere: kill-line in zsh (moved to
Alt+K), the split-above mapping in nvim (removed - use Ctrl+W then k), and
'move up' in fzf, where it now ABORTS instead (use Ctrl+P)."
    fi
    if grep -qx 'semicolon' <<<"$keys"; then
        trailer="${trailer}
Ctrl+; displaces nothing: there is no ASCII control code for semicolon, so no
terminal program can bind it."
    fi
    if [[ "$(grep -c . <<<"$keys")" -gt 1 ]]; then
        trailer="${trailer}

Both are bound while TASK-110 decides which to keep. That is a trial, not the
intended end state."
    fi

    note "$listed $( [[ "$(grep -c . <<<"$keys")" -gt 1 ]] && echo are || echo is ) another Escape, underneath every program:

$(printf '%b' "$body")${trailer}
Like the layer above, these come from keyd rather than sway, so they are not in
the table below."
}

swap_note
scroll_note
escape_note

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
table_start "Key" "What it does"

# Reuses the binding check rather than parsing the config a second time, so the
# two cannot disagree about what is bound.
sway_out="$("$REPO_ROOT/checks/sway-bindings.sh" 2>/dev/null)"

while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]+([^[:space:]]+)[[:space:]]+(.*)$ ]] || continue
    key="${BASH_REMATCH[1]}"
    action="${BASH_REMATCH[2]}"
    [[ "$key" == "DUPLICATE" || "$key" == "first:" || "$key" == "second:" ]] && continue
    [[ "$key" == \[* ]] && continue      # mode-scoped, listed separately below
    row "$key" "$action"
    record "sway" "$key" "$action"
done <<<"$sway_out"

modes="$(grep -E '^\s+\[' <<<"$sway_out" || true)"
if [[ -n "$modes" ]]; then
    heading "Modes — sway (only active inside the mode)"
    table_start "Mode and key" "What it does"
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]+([^[:space:]]+[[:space:]]+[^[:space:]]+)[[:space:]]+(.*)$ ]] || continue
        row "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    done <<<"$modes"
fi

# ----------------------------------------------------------------------
heading "Terminal — zsh"

# Derived by difference: what an interactive shell binds, minus what a shell
# started with no configuration binds. Whatever remains is what this repository
# added, without needing a list of it.
if ! command -v zsh &>/dev/null; then
    para "zsh is not installed, so its bindings cannot be read"
else
    # Compared as key-and-widget pairs, not keys alone. fzf rebinds Ctrl+R,
    # which zsh already binds to its own history search, so filtering on the key
    # would hide the single most useful shortcut the shell config adds.
    table_start "Key" "Widget"
    default_pairs="$(zsh -f -c 'bindkey' 2>/dev/null | sort -u)"
    ours="$(zsh -i -c 'bindkey' 2>/dev/null)"

    if [[ -z "$ours" ]]; then
        para "could not read bindings from an interactive zsh"
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
            row "$pretty" "$widget"
            record "zsh" "$pretty" "$widget"
        done <<<"$ours"
    fi
fi

# ----------------------------------------------------------------------
heading "Keys used in more than one context"

# Collected before anything is printed, because an empty markdown table with a
# header and no rows renders as a stray pair of lines that reads like a bug.
overlapping=()
for key in "${!CONTEXT_OF[@]}"; do
    [[ "${CONTEXT_OF[$key]}" == *,* ]] || continue
    overlapping+=("$key")
done
overlaps=${#overlapping[@]}
if [[ $overlaps -gt 0 ]]; then
    table_start "Key" "Meanings"
    for key in "${overlapping[@]}"; do
        row "$key" "${ACTION_OF[$key]}"
    done
fi

if [[ $overlaps -eq 0 ]]; then
    para "None. Every key means one thing."
else
    para "Not necessarily wrong: an application may reasonably claim a key the compositor also uses. Worth knowing which wins, and whether it should."
fi

# ----------------------------------------------------------------------
heading "Not covered yet"

table_start "Program" "Why not"
covered_note() { row "$1" "$2"; }
covered_note "qutebrowser" "no config in this repository, so it uses its own defaults"
covered_note "neovim"      "its keymap lives in this repository but is not parsed here yet"
covered_note "rofi"        "launcher keys are built in and not configurable here"
covered_note "foot"        "no keybindings overridden; foot defaults apply"
para "Each becomes coverable by parsing the config this repository already owns, or by giving it one."
