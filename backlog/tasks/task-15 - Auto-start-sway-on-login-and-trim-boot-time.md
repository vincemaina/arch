---
id: TASK-15
title: Auto-start sway on login and trim boot time
status: To Do
assignee: []
created_date: '2026-08-19 18:15'
labels:
  - session
  - performance
dependencies: []
priority: medium
type: feature
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Logging in currently drops you at a TTY where you type sway by hand. DECISIONS.md lists this as intentionally not automated, which was right for a proof of concept but is friction on a daily driver. Worth revisiting together with a boot-time pass: nothing has ever measured what the boot actually spends its time on, and NetworkManager-wait-online in particular commonly adds a long stall for no benefit on a desktop.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Logging in on the first TTY starts the graphical session without typing a command
- [ ] #2 A documented way to get a plain shell without starting the session still exists
- [ ] #3 Boot time is measured before and after, and the figures are recorded
- [ ] #4 No enabled unit delays boot waiting for something the desktop does not need
- [ ] #5 DECISIONS.md is updated, since it currently states graphical login is deliberately manual
<!-- AC:END -->
