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
    # Opening a folder gives you a shell in it rather than a file browser. A
    # directory you have gone to the trouble of finding is usually one you want
    # to do something in, and yazi is still one keypress away on $mod+e.
    #
    # This replaced yazi.desktop, which had a second problem worth remembering:
    # yazi.desktop declares Terminal=true, so glib has to find a terminal to run
    # it in, and until /usr/local/bin/xdg-terminal-exec existed there was none.
    # The association resolved correctly and opened nothing at all, for months,
    # with a comment here asserting that it worked.
    "terminal-here.desktop:inode/directory"

    # Editing, rather than viewing. text/plain already resolves to nvim through
    # the entry nvim ships, but several things that are plainly code do not:
    # a shell script is text/x-shellscript, which had no association at all, and
    # JSON is application/json, which resolved to the browser. Opening a config
    # file from the launcher and getting a read-only browser tab is the wrong
    # answer to an unambiguous question.
    #
    # HTML is deliberately left alone. Opening one is far more often "look at
    # this page" than "edit this markup", and the browser is right for that.
    "nvim.desktop:text/x-shellscript application/json application/x-shellscript text/x-python text/x-lua text/markdown application/toml text/x-makefile"

    # Links open in qutebrowser, which is the everyday browser - TASK-91 decided
    # two, and this is the one meant to be reached for.
    #
    # It was firefox, and nothing here had asked for that. Installing firefox by
    # hand registered it as the http handler, so every link clicked anywhere -
    # from a notification, from the launcher, from another application - opened
    # the heavy browser rather than the keyboard-driven one. Untracked, so a
    # rebuilt machine would have done something different again.
    #
    # firefox stays installed and stays a keystroke away; it is for DRM video
    # and extensions, which qutebrowser cannot do at all. It is not for links.
    #
    # text/html is included deliberately, and is the one case where the comment
    # above about leaving HTML alone still holds: a .html file should open in a
    # browser rather than the editor. This only decides WHICH browser.
    "org.qutebrowser.qutebrowser.desktop:x-scheme-handler/http x-scheme-handler/https text/html"
)

for entry in "${ASSOCIATIONS[@]}"; do
    desktop="${entry%%:*}"
    types="${entry#*:}"

    # A default pointing at a .desktop that does not exist is the failure this
    # repository keeps finding: it looks configured and does nothing. Packages
    # are installed before dotfiles are applied, by both install.sh and
    # sync.sh, so a miss here means something is genuinely wrong.
    # No pipe here, deliberately. This was `find ... | grep -q .`, and grep -q
    # exits at the first match and closes the pipe, so find takes SIGPIPE and
    # exits 141 - which this script's `set -o pipefail` turns into a failure
    # while the file it was looking for is sitting right there.
    #
    # It is a race, so it passed for years: for an entry in /usr/share it is
    # found immediately and find is done before grep can exit. The first entry
    # to live in ~/.local/share/applications - the LAST directory searched -
    # lost that race every time, and reported itself as not installed.
    # `|| true` because /usr/local/share/applications does not exist on this
    # machine, and find exits 1 for a missing directory even when it found what
    # it was asked for. That did not matter while this was the condition of an
    # `if`, since set -e ignores those - it started mattering the moment the
    # result was captured into a variable, where the assignment takes the
    # command substitution's status and set -e acts on it.
    found="$(find /usr/share/applications /usr/local/share/applications \
                  "$HOME/.local/share/applications" \
                  -maxdepth 1 -name "$desktop" -print -quit 2>/dev/null || true)"
    if [[ -z "$found" ]]; then
        echo "Cannot set defaults: $desktop is not installed." >&2
        echo "Its package should have been installed before dotfiles were applied." >&2
        exit 1
    fi

    for type in $types; do
        xdg-mime default "$desktop" "$type"
    done
    echo "    $desktop handles: $types"
done
