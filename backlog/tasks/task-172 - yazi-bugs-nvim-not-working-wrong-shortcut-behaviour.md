---
id: TASK-172
title: 'yazi bugs (nvim not working, wrong shortcut behaviour)'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-25 09:57'
updated_date: '2026-08-25 10:18'
labels: []
dependencies: []
priority: medium
type: bug
ordinal: 179000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
currently when you try to open a file by pressing enter,
it gives you an area. this used to work and open up neovim
in that same window.

also pressing o on a file opens up the folder instead of the file itself.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Enter on a file in yazi opens it in neovim in the same window, and returns to yazi on quit
- [x] #2 Enter on a directory navigates into it
- [x] #3 o opens the hovered file the same way Enter does, and navigates into a hovered directory
- [x] #4 Ctrl+o still opens a terminal in the directory yazi is showing, and closes yazi behind it
- [x] #5 The manual describes what the keys now do, and checks/manual.sh passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Confirmed root cause: yazi 26.8 replaced shell-positional opener/shell arguments ($@, $0) with its own %s / %s1 / %d1 placeholders. Both the opener and the o/Ctrl+o bindings pass nothing, so yazi-open dies on $1 unbound and yazi-terminal falls back to $PWD.
2. yazi.toml.tmpl: run '.../yazi-open %s'. Rewrite the comment to record the placeholder change.
3. keymap.toml.tmpl: drop the o override (user wants yazi's own o = open), keep Ctrl+o as terminal-here with the new syntax.
4. yazi-terminal: it now only ever runs with no argument; simplify or re-document accordingly.
5. Add a check so a silently-not-substituting placeholder cannot come back unnoticed.
6. Update docs/manual/04-applications.md.
7. Apply with sync.sh and verify live in a pty: Enter on a file, Enter on a dir, o on a file, Ctrl+o.
8. Run checks/session.sh, checks/manual.sh, checks/sway-commands.sh.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause, measured on yazi 26.8.15 rather than inferred. yazi no longer runs an opener or a keymap `shell` command as `sh -c '<run>' <files...>`. `run` is a template yazi substitutes itself, then hands one finished string to sh with no arguments at all. A spy script bound in an isolated YAZI_CONFIG_HOME showed $@, $0 and $1 all arriving empty ($0 is the literal string "sh"), while %s gives every selection already quoted, %s1 the first, and %d1 its parent. A filename containing spaces arrives as a single argument, so %s must NOT be quoted - "%s" would collapse a multi-file selection.

Visible half: yazi-open ran with no arguments, so `set -u` killed it on $1 and the blocking opener printed 'unbound variable' where nvim should have been. Silent half: yazi-terminal fell back to $PWD, so 'o' and Ctrl+o had become the same key without anything saying so.

Second finding: 26.8 binds 'o' itself, to `open`. The comment in keymap.toml.tmpl asserted 'o is unbound in yazi's defaults - checked by extracting all 73 of them from the binary', which was true when written and is not now. Extracted them again: 'o' and 'O' are both bound, Ctrl+o is still free.

User chose (asked directly) to give 'o' back to yazi rather than restore terminal-at-cursor on it. Terminal-at-cursor was removed rather than left unreachable; the %s1 substitution and the two lines yazi-terminal needs are recorded in the comments where they were taken out.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
yazi 26.8 replaced shell-positional substitution in openers and keymap `shell` commands with its own %s placeholders, so the config's "$@" and "$0" expanded to nothing: Enter died on 'yazi-open: $1: unbound variable' and 'o' silently became a duplicate of Ctrl+o. yazi.toml.tmpl now passes %s, yazi-open reports the placeholder by name instead of dying on set -u, and 'o' has been given back to yazi (which binds it to `open` as of 26.8) so it opens the hovered file. Ctrl+o keeps the terminal; terminal-at-cursor was removed rather than left as an unreachable branch, with its restoration recorded in place.

Verified live by driving yazi in a pty against real fixtures, not by reading the config: Enter on a directory navigated into it (title changed to 'Yazi: adir'); Enter on a file opened nvim in the same window, and an edit typed there was written to disk on :wq; 'o' on a file did the same; 'o' on a directory navigated in; Ctrl+o invoked foot with --working-directory set to the directory yazi was showing (captured with a stub foot on PATH rather than opening a window).

checks/session.sh gains a 'File manager (TASK-172)' section that reads the default opener compiled into the installed yazi binary and fails if the config's placeholder style disagrees with it, so the next syntax change fails a check rather than a keypress. checks/session.sh: 131 passed, 1 failed - the failure is a pre-existing 992ms zsh startup, unrelated. checks/manual.sh: 8 passed, 0 failed.
<!-- SECTION:FINAL_SUMMARY:END -->
