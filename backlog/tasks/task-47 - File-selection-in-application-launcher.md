---
id: TASK-47
title: File selection in application launcher
status: To Do
assignee: []
created_date: '2026-08-20 21:58'
updated_date: '2026-08-21 11:32'
labels: []
dependencies: []
priority: medium
type: feature
ordinal: 45000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Selecting a file in the application launcher should open that file with the appropriate tool
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Choosing a file in the launcher opens it in the chosen editor, in a window, verified from rofi rather than from a terminal that already has a tty
- [ ] #2 The Terminal=true problem is fixed for the category rather than for one entry - or the decision to ship explicit entries instead is recorded, with the yazi/inode-directory association fixed too since it has the same bug
- [ ] #3 Code files that are not text/plain - shell scripts, json - open in the editor rather than in nothing or in a browser
- [ ] #4 EDITOR and VISUAL are set, so the terminal and the launcher agree about what edits a file
- [ ] #5 checks/session.sh covers the mime associations end to end, since the existing one was declared, believed, and never worked
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Investigated before starting, and the ticket is bigger than it reads.

WHAT ALREADY WORKS. The launcher entry exists: find-files.desktop runs
`rofi -show recursivebrowser`, and rofi hands the chosen file to xdg-open. The
mime resolution is largely right too - a .py, .js, .md, .toml or .go file
resolves to text/plain and text/plain is already associated with nvim.desktop.
So on paper this feature is finished.

WHAT ACTUALLY HAPPENS. Nothing. `xdg-open /tmp/a.py` opens no window. nvim is
executed in the *calling* process's terminal rather than in a new one, so from
rofi - which has no tty - it starts, finds no terminal, and dies silently.
Confirmed by running it from a non-interactive shell, where nvim printed
"Caught deadly signal 'SIGTERM'" instead of drawing anything.

THE CAUSE IS NOT THE EDITOR. nvim.desktop declares Terminal=true, and nothing
on this machine launches a Terminal=true entry inside a terminal emulator.
xdg-terminal-exec, which is the freedesktop mechanism for this, is not
installed. So the failure is generic to the category, and picking a different
editor does not fix it - a different editor with Terminal=true fails the same
way.

IT IS ALREADY BROKEN ELSEWHERE, UNNOTICED. run_onchange_after_set-default-
applications.sh associates inode/directory with yazi.desktop, whose comment
says "yazi.desktop declares Terminal=true, so xdg-open starts it inside a
terminal". It does not. `xdg-open /tmp` fails with "Error: No such device or
address (os error 6)" - yazi with no tty. That association has never worked and
nothing reported it, which is this repository's signature failure exactly.

WE ALREADY HAVE THE WORKING PATTERN. $mod+e opens yazi correctly because the
sway config does it explicitly: `set $explorer foot --app-id=explorer -e yazi`.
An explicit terminal with a distinct app_id, not a Terminal=true entry. The same
shape works for the bar's btop and nmtui windows. So the fix is probably to ship
desktop entries that name foot themselves rather than to make Terminal=true work
- but installing xdg-terminal-exec is the alternative and deserves weighing,
since it fixes the whole category including entries shipped by packages.

TWO OTHER THINGS FOUND ON THE WAY:

  * application/json and text/html resolve to firefox.desktop, so selecting a
    .json file in the launcher opens a browser rather than an editor. For html
    that is arguable; for json it is just wrong.
  * .sh resolves to text/x-shellscript, which has no association at all.
  * firefox is installed but declared in no manifest - package drift, TASK-13.
  * EDITOR and VISUAL are both unset, so git, systemctl edit and anything else
    honouring them fall back to whatever the system default is rather than to
    the chosen editor. Worth fixing in the same pass whichever editor wins.
<!-- SECTION:NOTES:END -->
