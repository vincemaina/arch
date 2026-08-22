---
id: TASK-67
title: clipboard history (integration with rofi)
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-21 10:38'
updated_date: '2026-08-22 01:10'
labels: []
dependencies: []
priority: medium
type: feature
ordinal: 69000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
It would be cool to have clipboard history in this. for text and images alike. And ideally if you could acess and view that clipboard history via rofi that'd be great. e.g. rofi -> open clipboard history tool, select the thing you want to paste.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 cliphist and its watchers are declared in setup/packages/desktop.txt and the manifest says what each costs
- [ ] #2 The store is watched by a supervised systemd USER unit bound to wayland-session@sway.target with Restart=always, not a sway exec line and not graphical-session.target
- [x] #3 Both text and images are captured - one wl-paste watcher cannot do both
- [x] #4 The history is browsable from rofi, reachable by name from the launcher through a .desktop entry and by a keybinding
- [x] #5 Selecting an entry puts it back on the clipboard with the right mime type, images included
- [x] #6 What happens with images in the list is stated honestly, with a screenshot rather than a claim
- [x] #7 A decision about storing secrets is made and written down, with a way to forget one entry and a way to wipe the lot
- [ ] #8 checks/sway-commands.sh and checks/sway-bindings.sh pass, and checks/session.sh does not regress
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Establish what the official repos actually offer. cliphist (extra, 2.3 MiB, depends on wl-clipboard which is already declared) against copyq (extra, 8.7 MiB + Qt/KDE deps). clipman, clipse and greenclip are AUR-only and disqualified by TASK-43.
2. Trial cliphist without installing it: fetch the package from the mirror, extract to a scratch directory, run it against a scratch db. Establish that one wl-paste watcher stores text only and that images need a second --type image watcher.
3. Establish honestly what images look like in the list. cliphist list renders them as [[ binary data 1 MiB png 1920x1080 ]]. Decode each one to a cache file and hand rofi that path as the row icon; screenshot on a throwaway headless output to see whether it is a real thumbnail or a smudge.
4. Watcher supervision: a templated cliphist@.service bound to wayland-session@sway.target, Restart=always, instantiated as cliphist@text.service and cliphist@image.service by two committed symlinks in wayland-session@sway.target.wants. The package ships its own cliphist.service wanted by graphical-session.target with Restart=on-failure - both wrong for this repository - so it is deliberately not used.
5. Privacy: cliphist 0.7.0 has no notion of a secret (confirmed by strings on the binary). Interpose ~/.local/bin/clipboard-store between wl-paste and cliphist store, which drops anything whose offered mime types mention a password. Add per-entry forget and a whole-history wipe to the menu, and state plainly what is still stored in the clear.
6. Reaching it: ~/.local/bin/clipboard-history, a .desktop entry so the launcher finds it by name, and $mod+v.
7. Verify: render the templates, systemd-analyze verify the unit, run the helper end to end against the extracted binary, run the three checks.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
WHAT WAS CHOSEN

cliphist (extra, 1:0.7.0-2, 2.3 MiB, depends on glibc and wl-clipboard which
this repository already declares). The alternative in the official repos is
copyq: 8.7 MiB before qt6-svg, knotifications, kstatusnotifieritem, kguiaddons,
qca-qt6, qtkeychain-qt6 and libxtst, it draws a KDE-shaped Qt window next to a
GTK-dark desktop, it wants a system tray this machine does not have, and it
reaches Wayland through libxtst. clipman, clipse and greenclip are AUR-only and
therefore disqualified by TASK-43 - named rather than dropped silently.

TRIALLED WITHOUT INSTALLING, because there is no sudo in this session: the
package was fetched from the mirror and extracted to a scratch directory, and
every finding below comes from running that binary against a scratch db.

ONE WATCHER IS NOT ENOUGH - MEASURED

wl-paste --watch with no --type asks for text, so the obvious single watcher
records URLs and silently drops every screenshot. With one plain watcher and a
PNG on the clipboard, cliphist list showed three text entries and nothing else.
Adding a second watcher with --type image produced

  6  text after image
  5  [[ binary data 1 MiB png 1920x1080 ]]

This matters because the package's OWN unit has the bug: cliphist ships
/usr/lib/systemd/user/cliphist.service with ExecStart=wl-paste --watch cliphist
store, PartOf/WantedBy graphical-session.target, and Restart=on-failure - three
separate disagreements with this repository. It is not used.

IMAGES IN ROFI - A REAL PREVIEW, AND HERE IS WHAT IT COST

cliphist list renders an image as [[ binary data 1 MiB png 1920x1080 ]] and
that is all the list gives you. What turns it into a preview is that rofi's
per-row icon protocol - text NUL icon US <name> - accepts a FILE PATH as
happily as an icon name. So each image entry is decoded to a file in the
menu's temp dir and rofi is handed the path.

Sized by looking at three screenshots, not by guessing:
  26px (the theme's own icon size)  a smudge - you can tell the colour and
                                    nothing else
  4em                               legible, but the rows grow so much that
                                    the window overflows and pushes the search
                                    box off the top of the screen
  44px with listview lines: 7       legible AND the same window size as the
                                    launcher. Chosen.
At 44px a 200x200 red circle and a 1920x1080 screenshot of a terminal are told
apart at a glance. Both -theme-str overrides are on the command line, so
rofi/config.rasi.tmpl is untouched.

PRIVACY

cliphist 0.7.0 has no notion of a secret. strings on the binary finds no
x-kde-passwordManagerHint, no 'sensitive', no 'secret', no 'conceal' - there is
nothing to configure, so the filtering has to happen before it or not at all.

~/.local/bin/clipboard-store now sits between wl-paste and cliphist store, and
is what the units call. It reads wl-paste --list-types and stores nothing when
any offered type mentions 'password' case-insensitively, which is the hint
KeePassXC and the KDE tools offer alongside the text. The match is deliberately
loose because the outcomes are asymmetric: a false positive costs one missing
history entry, a false negative writes a password to disk.

Proved in both directions rather than by watching nothing happen:
  A  ordinary copy through the wrapper            -> stored (id 6)
  B  same wrapper, same input, clipboard offering
     x-kde-passwordManagerHint                    -> nothing stored
  C  that exact input piped straight to cliphist
     store                                        -> stored (id 7)
C is the part that makes B evidence: the store would have taken it, so the
absence in B is the filter and not an inert test.

WHAT IT DOES NOT PROTECT, stated in the script where the next reader will look:
a password copied out of a terminal, out of Firefox's saved-logins page or out
of a file is ordinary text and IS stored, in the clear, at ~/.cache/cliphist/db,
750 entries deep, on a disk that is unencrypted by choice. So the menu also
carries Ctrl+d to forget the highlighted entry and a 'Clear the whole history'
row behind a confirmation whose default answer is No.

NO AUTO-PASTE, AND IT WAS TRIED

wtype is in extra at 24 KiB and works: sway implements the virtual keyboard
protocol, and wtype -M ctrl -M shift -k v -m shift -m ctrl was watched putting
text into a foot window during this ticket. It is still not used, because that
trial only worked by knowing foot pastes on Ctrl+SHIFT+V. A browser wants
Ctrl+V; Ctrl+V in a shell is readline's quoted-insert and eats the next
character instead. Nothing can ask the focused window which it is, so
auto-pasting means guessing, and guessing wrong does something silent and wrong
rather than nothing.

VERIFICATION

Done on the running machine with the extracted binary on PATH via a shim, and
the menu driven with real keystrokes (wtype) on a throwaway headless output, so
the user's screen was never used:

  * The menu renders: five entries, two of them images showing their actual
    picture, the trash icon on the wipe row, and the overridden footer reading
    'up/down move . enter copy . Ctrl+d forget . Esc close'.
  * Down Down Enter on the 200x200 PNG row -> wl-paste --list-types reports
    image/png and the bytes are byte-identical to the original file (cmp).
  * Enter on a text row -> clipboard is text/plain with the right string.
  * Ctrl+d on the top row -> that entry is gone from cliphist list AND the menu
    reopens by itself on the remaining four.
  * The wipe confirmation renders with 'No, keep it' preselected and returns
    index 1 for 'Yes'; cliphist wipe empties the db.
  * chezmoi renders the whole tree clean; the two wants symlinks resolve to
    cliphist@text.service and cliphist@image.service; both helpers arrive 0755.
  * systemd-analyze --user verify on the rendered unit: clean.
  * checks/sway-bindings.sh: 70 bindings, none defined twice, repeat rule ok.
  * checks/session.sh: 82 passed, 0 failed - unchanged by this work.

WHAT IS NOT YET PROVEN, AND WHY

checks/sway-commands.sh reports exactly one failure, 'cliphist is not
installed'. That is the check doing its job: the package is declared and this
session has no sudo to install it. It clears on the next ./sync.sh.

For the same reason AC #2 is left unchecked. The unit file is correct, renders
correctly and verifies clean, but no one has watched cliphist@text.service and
cliphist@image.service actually run - and this repository's whole failure mode
is configuration that looks correct and does nothing. To close it:

  sudo pacman -S cliphist   (or ./sync.sh, which does packages before dotfiles)
  systemctl --user daemon-reload
  systemctl --user start cliphist@text.service cliphist@image.service
  systemctl --user status cliphist@text.service cliphist@image.service

then copy something and press $mod+v. sync.sh does not start new user units, so
without those two lines the watchers wait for the next login, same as every
other session component here.

TWO THINGS FOR FILES THIS AGENT WAS NOT ALLOWED TO EDIT

1. checks/session.sh hardcodes 'for unit in waybar mako swayidle polkit-agent'.
   cliphist@text and cliphist@image should join that list, and autotiling and
   greeting are already missing from it.
2. checks/sway-commands.sh only ever looks at the FIRST token of an ExecStart -
   cut -d= -f2- then the leading non-space word. So
   'ExecStart=/usr/bin/wl-paste --type %i --watch %h/.local/bin/clipboard-store'
   is checked as wl-paste and the helper in the arguments is never resolved. It
   happens to exist; nothing would have noticed if it did not.
3. DECISIONS.md has no clipboard entry. Suggested text is in the agent's report.
<!-- SECTION:NOTES:END -->
