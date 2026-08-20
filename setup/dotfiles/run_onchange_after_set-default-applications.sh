#!/usr/bin/env bash
set -euo pipefail

# Default applications, set rather than declared.
#
# WHY THIS IS A SCRIPT AND NOT A DOTFILE
#
# ~/.config/mimeapps.list is a shared file. This repository wants to say what
# opens an image; applications write to the same file at runtime to register
# themselves - Claude Code puts its claude-cli:// handler there, and any
# browser or mail client will do the same.
#
# chezmoi owns a file completely: ship mimeapps.list as a dotfile and every
# sync overwrites the live one, silently deleting whatever an application
# registered since. Links stop working and nothing reports it.
#
# xdg-mime edits only the entries it is given and leaves the rest alone, which
# is the semantics this file actually needs. See "Default applications are set,
# not declared" in DECISIONS.md.
#
# run_onchange_ means chezmoi re-runs this only when the script itself changes,
# so adding a mapping below is what triggers it. Editing mimeapps.list by hand
# will NOT be reverted - that is the point.

# desktop file : mime types it should handle
ASSOCIATIONS=(
    "imv.desktop:image/png image/jpeg image/gif image/webp image/bmp image/tiff"
    # Opening a folder should land in the file manager being used, which is a
    # terminal one. yazi.desktop declares Terminal=true, so xdg-open starts it
    # inside a terminal rather than trying to draw a window it does not have.
    "yazi.desktop:inode/directory"
)

for entry in "${ASSOCIATIONS[@]}"; do
    desktop="${entry%%:*}"
    types="${entry#*:}"

    # A default pointing at a .desktop that does not exist is the failure this
    # repository keeps finding: it looks configured and does nothing. Packages
    # are installed before dotfiles are applied, by both install.sh and
    # sync.sh, so a miss here means something is genuinely wrong.
    if ! find /usr/share/applications /usr/local/share/applications \
              "$HOME/.local/share/applications" \
              -maxdepth 1 -name "$desktop" -print -quit 2>/dev/null | grep -q .; then
        echo "Cannot set defaults: $desktop is not installed." >&2
        echo "Its package should have been installed before dotfiles were applied." >&2
        exit 1
    fi

    for type in $types; do
        xdg-mime default "$desktop" "$type"
    done
    echo "    $desktop handles: $types"
done
