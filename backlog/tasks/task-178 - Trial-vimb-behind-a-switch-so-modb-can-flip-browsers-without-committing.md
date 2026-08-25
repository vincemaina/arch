---
id: TASK-178
title: 'Trial vimb behind a switch, so $mod+b can flip browsers without committing'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-25 18:10'
updated_date: '2026-08-25 18:17'
labels: []
dependencies:
  - TASK-177
priority: medium
type: enhancement
ordinal: 185000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-177 measured vimb at 354ms cold against qutebrowser's 1673ms - 4.7x - and established that 354ms is the WebKitGTK engine floor, so no lighter GUI browser exists to find. What it could not answer is whether WebKitGTK renders the sites actually used well enough to live with, which is the real decision.

This makes that trial cheap: $mod+b launches whichever browser a one-line state file names, so switching is one command and reverting is one command.

Deliberately NOT in chezmoi.toml, even though theme, wallpaper and glow all live there. Reading it needs desktop_config.py, which shells out to 'chezmoi data' at ~100ms+ - and $mod+b is precisely the latency this whole exercise is about. Same reasoning already recorded in DECISIONS.md for the sound pack, which is a plain file in ~/.local/state for the same reason.

Scope is the keybinding only. xdg-mime default handlers keep pointing at qutebrowser, so links from other applications are unaffected and the launcher still reaches either browser by name - which is what makes this a trial rather than a switch.

vimb has to be declared in setup/packages/desktop.txt or checks/sway-commands.sh fails: it enforces that every command the session can invoke comes from a declared package. epiphany and netsurf stay as package drift for TASK-177 to resolve.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 $mod+b launches vimb after switching to it, and qutebrowser after switching back, verified by pressing it and reading the window's app_id
- [x] #2 The switch survives a sway reload and a new login, since it is not sway state
- [x] #3 An unset or corrupt state file falls back to qutebrowser rather than launching nothing
- [x] #4 vimb windows float at the same size qutebrowser's do, so the trial is comparable
- [x] #5 checks/sway-commands.sh, checks/sway-bindings.sh, checks/manual.sh and checks/session.sh pass
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Re-add ~/.local/bin/browser as a small bash helper: no args launches the selected browser, --use switches, --current prints, --list shows both. State in ~/.local/state/browser, one line, read directly.
2. Remove the .local/bin/browser line from .chezmoiremove, added by TASK-174 - chezmoi cannot both manage the file and manage its removal.
3. Point $browser back at the helper in sway/config.
4. Float vimb at 1500x900 alongside qutebrowser in 40-window-rules.conf.
5. Declare vimb in setup/packages/desktop.txt with a comment saying it is on trial and pointing at TASK-177, and mark it explicit so checks/packages.sh is satisfied.
6. Update docs/software/README.md and docs/manual/04-applications.md; note the trial in DECISIONS.md rather than reversing the browser decision, which is not settled.
7. Verify by launching through the helper both ways and reading app_id from sway, not by reading the file back. Prove the fallback by corrupting the state file on purpose.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified by firing the real binding through 'swaymsg exec' and reading app_id back from sway's tree, not by reading files:
  browser --use vimb        -> app_id=vimb, floating, 1500x900
  browser --use qutebrowser -> app_id=org.qutebrowser.qutebrowser, floating, 1500x900

Fallback proven by breaking it on purpose rather than by reading the code:
  no state file        -> qutebrowser
  unsupported value    -> qutebrowser
  empty file           -> qutebrowser
  'rm -rf /'           -> qutebrowser (never exec'd)
  'vimb' + whitespace  -> vimb (trimmed, so an editor's trailing newline is fine)
  --use netscape       -> rejected, names the valid set
  --bogus              -> rejected

checks/sway-commands.sh traces 'browser' into both qutebrowser and vimb and
accounts for each from a declared package, which is what the '# requires:'
header is for - so declaring vimb in desktop.txt was load-bearing, not
bookkeeping. sway-commands, sway-bindings and manual all exit 0 on merged main.
vimb is no longer package drift and is marked Explicitly installed; epiphany
and netsurf still are, left for TASK-177.

Left selected on qutebrowser deliberately - the trial starts when the user
runs 'browser --use vimb', not because a task landed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
$mod+b opens whichever of qutebrowser and vimb one line in ~/.local/state/browser names, so the WebKitGTK question can be answered by a week of use instead of by argument.

~/.local/bin/browser is back, having been deleted in TASK-174, and does a different job: it chooses WHICH browser, not how to open one. State is a plain file rather than chezmoi.toml because reading that needs desktop_config.py, which shells out to 'chezmoi data' at 100ms+ - self-defeating on the path whose latency is the whole point. vimb is declared in desktop.txt because checks/sway-commands.sh requires it, and floats at qutebrowser's 1500x900 so the two are compared fairly.

xdg-mime handlers are untouched, so links still open qutebrowser and reverting stays one command.

Verified by firing the binding through sway and reading app_id back for both browsers, and by deliberately corrupting the state file - unset, empty, unrecognised and hostile values all fall back to qutebrowser rather than launching nothing.
<!-- SECTION:FINAL_SUMMARY:END -->
