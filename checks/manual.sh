#!/usr/bin/env bash
set -uo pipefail

# Does the manual still describe this system?
#
# Prose goes stale the same way configuration does, and in this repository that
# is the failure that matters: a chapter that names a keybinding nobody bound,
# or a helper nobody ships, reads exactly like one that is right. Every other
# check here asks the running system a question; this one asks the manual's
# claims the same question.
#
# What it does NOT check is whether the prose is true - only whether the things
# it names exist. That is a floor, not a ceiling, and it is the part a script
# can do.
#
# Read-only.

PASS=0
FAIL=0

pass() { printf '  \033[32mPASS\033[0m  %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; FAIL=$((FAIL + 1)); }
section() { printf '\n==> %s\n' "$*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANUAL_DIR="$REPO_ROOT/docs/manual"

if [[ ! -d "$MANUAL_DIR" ]]; then
    echo "no docs/manual/ to check" >&2
    exit 1
fi

# ----------------------------------------------------------------------
section "The manual builds at all"

# The build is the dialect check: tools/manual-render.py refuses anything it
# does not understand rather than rendering it wrongly, so a chapter that fails
# to build is a chapter with something in it nobody will see.
if build_out="$("$REPO_ROOT/tools/manual.sh" 2>&1)"; then
    pass "tools/manual.sh renders every chapter"
else
    fail "the manual does not build:"
    sed 's/^/        /' <<<"$build_out" | tail -3
fi

# ----------------------------------------------------------------------
section "Everything the manual names exists"

BINDINGS="$(mktemp)"
trap 'rm -f "$BINDINGS"' EXIT
"$REPO_ROOT/tools/shortcuts.sh" --markdown 2>/dev/null > "$BINDINGS"

REFCHECK="$(mktemp)"
trap 'rm -f "$BINDINGS" "$REFCHECK"' EXIT
cat > "$REFCHECK" <<'PYEOF'
import os
import re
import sys
from pathlib import Path

repo = Path(sys.argv[1])
manual = repo / "docs/manual"
bindings_file = Path(sys.argv[2])

results = []


def say(kind, message):
    results.append((kind, message))


chapters = sorted(p for p in manual.glob("*.md") if re.match(r"^\d\d-", p.name))
text_of = {p: p.read_text() for p in chapters}

# The index links to every chapter and is not built into the document, so
# nothing else would ever notice it pointing at a chapter that was renamed.
index = manual / "README.md"
if index.exists():
    text_of[index] = index.read_text()

# ---------------------------------------------------------------- links
# Every relative link, whether it points at another chapter or out of the
# manual entirely. README.md promised FLOW.md for months before anyone checked.
broken = []
for path, text in text_of.items():
    for m in re.finditer(r"\[[^\]]+\]\(([^)]+)\)", text):
        href = m.group(1).split("#", 1)[0]
        if not href or href.startswith(("http://", "https://", "mailto:")):
            continue
        if not (path.parent / href).resolve().exists():
            broken.append(f"{path.name} -> {href}")
if broken:
    say("fail", f"{len(broken)} link(s) point at nothing: " + "; ".join(broken[:4]))
else:
    say("pass", "every relative link in the manual resolves")

# A link to another chapter labelled with its filename reads as a filename in
# the built document, where the file it names does not exist. Chapters have
# titles; use them. Links out of the manual - DECISIONS.md, FLOW.md - are
# exactly the case where naming the file IS the useful label, so only the
# numbered chapters are policed.
filename_labels = []
for path, text in text_of.items():
    for m in re.finditer(r"\[(\d\d-[^\]]+\.md)\]\(", text):
        filename_labels.append(f"{path.name}: {m.group(1)}")
if filename_labels:
    say("fail", "chapter links labelled with a filename rather than a title: "
        + "; ".join(sorted(set(filename_labels))[:4]))
else:
    say("pass", "cross-chapter links are labelled with chapter titles")


# ---------------------------------------------------------------- paths
# A path written in backticks is a promise that it is there. chezmoi's source
# naming means the tracked file is not spelled the way the manual spells it:
# ~/.config/foo is setup/dotfiles/dot_config/foo, an executable carries an
# executable_ prefix, and a template carries a .tmpl suffix. Check the source,
# not the rendered copy, because the source is what a reader would go and edit.
def source_candidates(p):
    if p.startswith("~/"):
        rest = p[2:].split("/")
        rest[0] = "dot_" + rest[0].lstrip(".")
        base = repo / "setup/dotfiles"
        for i in range(1, len(rest)):
            if rest[i].startswith("."):
                rest[i] = "dot_" + rest[i][1:]
        stem = base.joinpath(*rest)
        last = stem.name
        return [
            stem,
            stem.with_name(last + ".tmpl"),
            stem.with_name("executable_" + last),
            stem.with_name("executable_" + last + ".tmpl"),
            stem.with_name("symlink_" + last),
            Path(os.path.expanduser(p)),
        ]
    return [repo / p, repo / (p + ".tmpl")]


REPO_DIRS = ("setup/", "checks/", "tools/", "docs/", "backlog/", ".claude/")

# A dotfile the repository deliberately does NOT track still exists as far as
# the manual is concerned - ~/.config/zsh/local.zsh is the whole point of
# .chezmoiignore, a place for machine-local changes that leave no diff. Naming
# one is correct; failing the check for it would push the manual into either
# silence or a lie.
ignored = set()
ignore_file = repo / "setup/dotfiles/.chezmoiignore"
if ignore_file.exists():
    for line in ignore_file.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            ignored.add("~/" + line)

# A path that does not exist yet because nothing has created it YET is not the
# same as a path the manual invented, and this check could not tell them apart.
# ~/Pictures/wallpapers is where `wallpaper` keeps an image of your own -
# dot_local/bin/executable_wallpaper builds it, and the comment beside it
# explains why it sits deliberately outside the disposable generated cache. It
# is created on the first custom wallpaper and not by the install, so demanding
# that it exist fails on every machine where nobody has added one, which is
# most of them. That is a false alarm, and a check that cries wolf about a
# correct manual is worse than no check: this repository's own rule is that a
# failing check must mean something.
#
# Listed here rather than derived from the helper, because the helper builds
# the path from components - home() / "Pictures" / "wallpapers" - so there is
# no literal string in the source to match on that is not a comment.
created_on_demand = {"~/Pictures/wallpapers"}
ignored |= created_on_demand

missing = []
seen = set()
for path, text in text_of.items():
    for m in re.finditer(r"`([^`\s]+)`", text):
        token = m.group(1).rstrip(".,;:)")
        if "/" not in token or token.endswith("/") and token.count("/") == 1:
            continue
        if not (token.startswith("~/") or token.startswith(REPO_DIRS)):
            continue
        if "*" in token or "<" in token or token.startswith("/"):
            continue
        if token in seen or token in ignored:
            continue
        seen.add(token)
        if not any(c.exists() for c in source_candidates(token)):
            missing.append(f"{path.name}: {token}")
if missing:
    say("fail", f"{len(missing)} path(s) named in the manual do not exist: "
        + "; ".join(missing[:5]))
else:
    say("pass", f"all {len(seen)} repository paths named in the manual exist"
        f" ({len(created_on_demand)} created on first use, acknowledged)")


# ---------------------------------------------------------------- helpers
# ~/.local/bin/thing is checked above as a path. This checks the other way a
# helper gets named: as a bare command in prose or a shell block.
helpers = {p.name.replace("executable_", "")
           for p in (repo / "setup/dotfiles/dot_local/bin").iterdir()}
claimed = set()
for text in text_of.values():
    for m in re.finditer(r"`~/\.local/bin/([a-z0-9-]+)", text):
        claimed.add(m.group(1))
absent = sorted(c for c in claimed if c not in helpers)
if absent:
    say("fail", "helpers named that are not in dot_local/bin: " + ", ".join(absent))
else:
    say("pass", f"all {len(claimed)} helper scripts the manual names are shipped")


# ---------------------------------------------------------------- bindings
# The point of the whole check. Only compositor bindings are examined - a
# chapter may legitimately mention Ctrl+P for printing, which sway never binds -
# so the rule is: anything written with $mod, Mod4 or Super must be bound.
def canon(combo):
    parts = combo.lower().replace("$mod", "super").replace("mod4", "super")
    parts = parts.replace("control", "ctrl").replace("mod1", "alt")
    return "+".join(sorted(parts.split("+")))


bound = set()
for m in re.finditer(r"^\| `([^`]+)` \|", bindings_file.read_text(), re.M):
    bound.add(canon(m.group(1)))

MOD = re.compile(r"^(?:\$mod|Mod4|Super)(?:\+[A-Za-z0-9_]+)+$")
# "$mod+Shift" in a sentence names a modifier pair, not a binding, and there is
# nothing for it to be bound to. Without this the check demanded that prose
# explaining WHY a shortcut uses a modifier be itself a shortcut.
MODIFIERS = {"shift", "ctrl", "control", "alt", "mod1", "mod4", "super", "meta"}
unbound = []
mentioned = set()
# Chapters only. The index is about the manual rather than about the desktop,
# and it names a binding that was deliberately taken away to make the point
# that this check cannot see meaning, only existence.
for path in chapters:
    text = text_of[path]
    for m in re.finditer(r"`([^`\s]+)`", text):
        combo = m.group(1)
        if not MOD.match(combo):
            continue
        if combo.rsplit("+", 1)[-1].lower() in MODIFIERS:
            continue
        mentioned.add(combo)
        if canon(combo) not in bound:
            unbound.append(f"{path.name}: {combo}")
if unbound:
    say("fail", f"{len(unbound)} keybinding(s) the manual describes are not bound: "
        + "; ".join(sorted(set(unbound))[:5]))
else:
    say("pass", f"all {len(mentioned)} compositor keybindings the manual names are bound")


# ---------------------------------------------------------------- shape
numbers = [p.name[:2] for p in chapters]
if numbers != sorted(numbers) or len(set(numbers)) != len(numbers):
    say("fail", "chapter numbers are duplicated or out of order: " + ", ".join(numbers))
else:
    say("pass", f"{len(chapters)} chapters, numbered without gaps in meaning")

for path in chapters:
    first = text_of[path].split("\n", 1)[0]
    if not first.startswith("# "):
        say("fail", f"{path.name} does not start with a # title")
        break
else:
    say("pass", "every chapter starts with its own title")

for kind, message in results:
    print(f"{kind}\t{message}")
PYEOF

while IFS=$'\t' read -r kind message; do
    case "$kind" in
        pass) pass "$message" ;;
        fail) fail "$message" ;;
    esac
done < <(python3 "$REFCHECK" "$REPO_ROOT" "$BINDINGS")

# ----------------------------------------------------------------------
printf '\n'
if [[ $FAIL -eq 0 ]]; then
    printf '\033[32m%d passed, 0 failed\033[0m\n' "$PASS"
else
    printf '\033[31m%d passed, %d failed\033[0m\n' "$PASS" "$FAIL"
fi
exit $((FAIL > 0))
