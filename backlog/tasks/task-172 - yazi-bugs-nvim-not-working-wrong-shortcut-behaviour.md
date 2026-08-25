---
id: TASK-172
title: 'yazi bugs (nvim not working, wrong shortcut behaviour)'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-25 09:57'
updated_date: '2026-08-25 10:08'
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
- [ ] #1 Enter on a file in yazi opens it in neovim in the same window, and returns to yazi on quit
- [ ] #2 Enter on a directory navigates into it
- [ ] #3 o opens the hovered file the same way Enter does, and navigates into a hovered directory
- [ ] #4 Ctrl+o still opens a terminal in the directory yazi is showing, and closes yazi behind it
- [ ] #5 The manual describes what the keys now do, and checks/manual.sh passes
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
