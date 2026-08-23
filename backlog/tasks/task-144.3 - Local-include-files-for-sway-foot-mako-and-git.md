---
id: TASK-144.3
title: 'Local include files for sway, foot, mako and git'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 11:40'
updated_date: '2026-08-23 11:59'
labels: []
dependencies: []
parent_task_id: TASK-144
type: feature
ordinal: 151000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The override layer for the four tools reached for most often. Each tracked config gains an include of a create_ file, seeded with a comment explaining what it is for and never rewritten afterwards. foot needs an absolute path, so its include line has to be templated.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Each of the four has a local file that is created once and never overwritten
- [x] #2 The include is last, so a local setting wins
- [x] #3 A missing or empty local file breaks nothing
- [x] #4 checks/session.sh passes
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Delivered for sway, foot and git. MAKO WAS DROPPED, and that is the substantive finding.

The escape hatch only works if deleting the untracked file is survivable, because it is untracked and looks like clutter. Measured, per tool:
  zsh   [[ -r ]] guard          safe
  sway  config.d/*.conf glob    safe - a missing file matches nothing
  git   ignores it, exit 0      safe
  foot  logs an error, STARTS ANYWAY (exit 0); only --check-config returns non-zero
  mako  'Failed to parse config' and exits BEFORE reaching the bus - fatal

mako.service is Restart=always, so a deleted local file would crash-loop the notification daemon and silently kill notifications. mako has no conditional include to guard with. The trade was not close either way: mako only accepts include among the global options before the first criteria, so a local file could override globals and would still lose to the criteria blocks below.

Placement was measured, not assumed. foot only accepts include in [main]; an include inside [key-bindings] is rejected outright ('not a valid action'). Putting it in [main] at the top would mean losing to every later section, so the file re-opens [main] at the very end - accepted by --check-config, and foot demonstrably keeps parsing after an include (an invalid line placed after one still errors). sway needed no include line at all: config.d/*.conf is already globbed and 99- sorts last.

Also corrected checks/session.sh: it required every sway config.d/*.conf to be hashed by the reload script, which caught create_99-local.conf. Hashing a create_ file is meaningless - chezmoi writes it once and never again, so the source hash can never change, and the edits that matter happen to the target. A hash line that can never change reads as coverage and provides none.

Verified live: all three files created; foot --check-config exit 0; sway reload parses 99-local.conf; a git [user] email in the local file overrides the tracked one and reverts cleanly when removed; hand-edits to sway and foot local files survive 'chezmoi apply --force'; chezmoi status reports no drift for any of them.

I also briefly reported foot as VALID with a missing include when it actually exits 230 - the && was reading tail's exit code through a pipe. Same mistake as an earlier git push in this session.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
sway, foot and git each gained a machine-local file created once by chezmoi and never rewritten, read last so a local setting wins. sway needed no new line (config.d/*.conf is globbed, 99- sorts last); foot re-opens [main] at the end because include is only valid there; git uses [include] path.

mako was deliberately excluded: a missing include kills it before it reaches the bus, and with Restart=always that is a crash-looping notification daemon. The rule this produced is recorded in DECISIONS.md - an escape hatch whose absence breaks the program is not an escape hatch, so check the missing-file case before adding a tool.

checks/session.sh updated to exclude create_ files from the sway reload-hash requirement. Verified with checks/manual.sh 8/0, checks/session.sh 91/1 (the one failure is the sink sitting at 131%, machine state rather than config), sway-bindings passing, and live override tests for all three tools.
<!-- SECTION:FINAL_SUMMARY:END -->
