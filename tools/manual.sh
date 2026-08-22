#!/usr/bin/env bash
set -euo pipefail

# Build docs/manual/ into one self-contained HTML page.
#
# One page, not ten files. A manual split across a directory is a manual nobody
# reads end to end: you open the one file whose name looked relevant and never
# learn what the other nine say. This is the whole thing, with a contents
# column that stays on screen and links between every chapter.
#
# Self-contained matters as much as single: no stylesheet to fetch, no font to
# download, nothing to install. Copy the file anywhere and it still works, and
# a browser will print it if you want it on paper.
#
# There is no pandoc here, and there is not going to be. The manual is
# repository tooling - it never reaches the built machine - so nothing it needs
# may go into setup/packages/, and the lightest of pandoc, weasyprint and
# wkhtmltopdf still costs more than the document weighs. The renderer is
# stdlib Python reading a markdown dialect this repository defines, and it
# refuses anything outside that dialect rather than rendering it wrongly.
#
# This is a tool, not a check: it produces something to read. What guards the
# manual against drift is checks/manual.sh.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANUAL_DIR="$REPO_ROOT/docs/manual"
BUILD_DIR="$MANUAL_DIR/build"
OUT="$BUILD_DIR/manual.html"

OPEN=0
case "${1:-}" in
    --open) OPEN=1 ;;
    "") ;;
    *) echo "usage: manual.sh [--open]" >&2; exit 2 ;;
esac

echo "==> Generating the keyboard reference"
mkdir -p "$BUILD_DIR"
# The one part of the manual nobody writes. A hand-kept shortcut table is wrong
# the first time somebody changes a binding and forgets the document, which is
# the same failure as a keybinding that calls a command nothing installed.
"$REPO_ROOT/tools/shortcuts.sh" --markdown > "$BUILD_DIR/shortcuts.md"
printf '    %s keyboard rows\n' "$(grep -c '^| `' "$BUILD_DIR/shortcuts.md")"

echo "==> Rendering the chapters"
built="Built $(date '+%-d %B %Y') from $(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo 'an untracked tree')."
python3 "$REPO_ROOT/tools/manual-render.py" \
    "$MANUAL_DIR" "$OUT" "$built" "$BUILD_DIR/shortcuts.md" |
    sed 's/^/    /'

echo "==> Done"
echo "    $OUT"
echo
echo "    Read it:  ./tools/manual.sh --open, or 'manual' once ./sync.sh has"
echo "              installed it, or find Manual in the launcher."
echo "    On paper: print it from the browser. The print stylesheet breaks"
echo "              pages between chapters and spells out where each external"
echo "              link points, since a printed link is otherwise useless."

if [[ "$OPEN" == 1 ]]; then
    xdg-open "$OUT" >/dev/null 2>&1 &
fi
