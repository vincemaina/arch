#!/usr/bin/env bash
set -uo pipefail

# Two things in this repository go stale silently, and both were asked for by
# name: the manual, and the backlog.
#
# Neither can be enforced by a check that runs on demand, because the failure
# is forgetting to run it. So this runs on its own, once per session, at the
# point where forgetting becomes permanent: the end of a turn.
#
# WHAT IT IS NOT
#
# It is not a linter and it does not know whether the manual is correct -
# checks/manual.sh does that, and even that one only sees existence, never
# meaning. This looks at which files changed and asks one question: given what
# moved, is there something you would want to have written down?
#
# It nags AT MOST ONCE per session per message. A hook you cannot satisfy is a
# hook that gets deleted, so every path out of here is reachable: address it,
# or say why not, and it will not ask again.

STATE_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/state"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

payload="$(cat)"

field() {
    python3 -c '
import json, sys
try:
    print(json.loads(sys.stdin.read()).get(sys.argv[1], "") or "")
except Exception:
    print("")
' "$1" <<<"$payload" 2>/dev/null
}

event="$(field hook_event_name)"
session="$(field session_id)"
[[ -n "$session" ]] || session="unknown"
session="${session//[^A-Za-z0-9_-]/}"

cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

BASE="$STATE_DIR/$session.base"
SEEN="$STATE_DIR/$session.seen"

# ----------------------------------------------------------------------
# SessionStart: remember where the session began, so the Stop hook can see
# work that was committed during it rather than only work left uncommitted.
if [[ "$event" == "SessionStart" ]]; then
    git rev-parse HEAD > "$BASE" 2>/dev/null
    exit 0
fi

[[ "$event" == "Stop" ]] || exit 0

# Proof that the harness actually calls this, independent of whether it has
# anything to say. A hook that is never invoked and a hook with nothing to
# report look identical from the outside, and this repository has been caught
# by that shape of silence more than once. One line, appended every time.
date -Is >> "$STATE_DIR/$session.ran" 2>/dev/null

# ----------------------------------------------------------------------
# What moved this session: everything committed since the baseline, plus
# anything still uncommitted.
changed=""
if [[ -r "$BASE" ]]; then
    base="$(cat "$BASE")"
    changed="$(git diff --name-only "$base" HEAD 2>/dev/null)"
fi
changed="$changed
$(git status --porcelain 2>/dev/null | sed -E 's/^.{3}//' | tr -d '"')"
# Its own state directory is not a change. It is gitignored here, so this only
# matters where that entry is missing - but a hook that reports itself as work
# is a hook that fires on a session where nothing happened, which is precisely
# how one stops being read.
changed="$(grep -v '^[[:space:]]*$' <<<"$changed" | grep -v '^\.claude/state/' | sort -u)"
[[ -n "$changed" ]] || exit 0

matches() { grep -qE "$1" <<<"$changed"; }

notes=()

# ----------------------------------------------------------------------
# The manual. Each pattern names the chapter that most likely covers it, so
# the reminder is actionable rather than a general feeling of unease.
if ! matches '^docs/manual/'; then
    manual_reasons=()
    matches '^setup/dotfiles/dot_config/sway/config\.d/5[012]-' &&
        manual_reasons+=("a keybinding or mode changed -> chapter 3, The keyboard")
    matches '^setup/dotfiles/dot_local/bin/' &&
        manual_reasons+=("a helper script changed -> chapter 4 or 6")
    matches '^setup/dotfiles/dot_config/waybar/' &&
        manual_reasons+=("the bar changed -> chapter 2, and the recap in chapter 5")
    matches '^setup/dotfiles/\.chezmoidata/themes\.toml' &&
        manual_reasons+=("a theme changed -> chapter 5, Making it yours")
    matches '^setup/packages/' &&
        manual_reasons+=("the package set changed -> chapter 4, Applications")
    matches '^setup/dotfiles/dot_config/systemd/' &&
        manual_reasons+=("a session unit changed -> chapter 1 and chapter 8")
    matches '^(setup/system/|setup/install/|install\.sh|sync\.sh)' &&
        manual_reasons+=("the install or sync path changed -> chapters 7, 9 and 10")
    matches '^checks/' &&
        manual_reasons+=("a check changed -> chapter 10, Keeping it healthy")

    if [[ ${#manual_reasons[@]} -gt 0 ]]; then
        notes+=("THE MANUAL was not touched, but something it documents was:")
        for r in "${manual_reasons[@]}"; do notes+=("    - $r"); done
        notes+=("  Update docs/manual/ and run ./checks/manual.sh, or say why the")
        notes+=("  change is not worth a line. Note that checks/manual.sh only sees")
        notes+=("  whether the things named exist - a sentence that is now WRONG")
        notes+=("  about a binding that still exists will pass it.")
    fi
fi

# ----------------------------------------------------------------------
# The backlog. Not the whole board - just the ticket being worked on, which
# is the one the user asked to be kept current.
if command -v backlog >/dev/null 2>&1; then
    active="$(backlog task list --status "In Progress" --plain 2>/dev/null |
              grep -oE 'TASK-[0-9.]+' | head -5)"
    if [[ -z "$active" ]]; then
        notes+=("NO BACKLOG TASK is In Progress, but files changed this session.")
        notes+=("  If this was tracked work, move its task to In Progress. If it was")
        notes+=("  a mechanical edit that needed no planning, that is fine - say so.")
    elif ! grep -qE '^backlog/tasks/' <<<"$changed"; then
        # Deliberately NOT a report on every In Progress task. Several here have
        # been open for weeks and are nobody's business at the end of an
        # unrelated turn; nagging about those is how a hook trains you to
        # ignore it. The only question asked is whether THIS session's work was
        # written down anywhere at all.
        notes+=("NO BACKLOG TASK was updated, though files changed this session.")
        notes+=("  Open: $(tr '\n' ' ' <<<"$active")")
        notes+=("  If this work belongs to one of those, record it with")
        notes+=("  'backlog task edit <id> --append-notes'. If it was a mechanical")
        notes+=("  edit that needed no planning, that is a fine answer too.")
    fi
fi

[[ ${#notes[@]} -gt 0 ]] || exit 0

message="$(printf '%s\n' "${notes[@]}")"

# ----------------------------------------------------------------------
# Say each thing once. The hash is of the message, so a NEW reason still gets
# through while the same reason does not repeat - and nothing here can loop,
# because the second identical Stop passes straight through.
fingerprint="$(sha256sum <<<"$message" | cut -c1-32)"
if [[ -r "$SEEN" ]] && grep -qxF "$fingerprint" "$SEEN"; then
    exit 0
fi
echo "$fingerprint" >> "$SEEN"

{
    echo "Before finishing - two things this repository forgets:"
    echo
    echo "$message"
    echo
    echo "(This is .claude/hooks/keep-the-record.sh. It asks once per session per"
    echo "reason; addressing it or explaining why not are equally fine answers.)"
} >&2
exit 2
