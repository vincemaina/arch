---
id: TASK-121.1
title: sync.sh run from a worktree records a sourceDir that stops existing
status: To Do
assignee: []
created_date: '2026-08-22 17:11'
updated_date: '2026-08-22 17:11'
labels:
  - repo
dependencies: []
parent_task_id: TASK-121
priority: high
type: bug
ordinal: 126000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
sync.sh:267 records the checkout it ran from with `theme --record-source $SETUP_SOURCE`, unconditionally and by design - the recorded path is wrong after a move or re-clone, which is exactly when nothing else differs.

Run from inside a git worktree, it records the worktree. .claude/worktrees/<name>/setup is deleted when the worktree is, and from then on every bare chezmoi command on the machine operates on a directory that does not exist. chezmoi does not error: `chezmoi managed` lists nothing and `chezmoi status` prints nothing, which is indistinguishable from a machine that is perfectly up to date.

This has already happened once. TASK-121 traced a check that recommended deleting seven live config files back to exactly this, and the recorded path was repaired by hand with `theme --record-source /home/vincemaina/Arch/setup`. Nothing prevents the next occurrence: this session worked in a worktree too.

TASK-121 fixed the check by passing --source explicitly, so checks/session.sh no longer depends on the recorded value - which also means it no longer notices when the recorded value is wrong. A human running a bare chezmoi command still gets silence.

Worth considering rather than assuming: sync.sh could refuse to record a path under .claude/worktrees/, or resolve it back to the main checkout via `git rev-parse --path-format=absolute --git-common-dir`; and/or checks/session.sh could fail when the recorded sourceDir does not exist, which catches every cause including a moved or deleted clone rather than just this one.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A sync.sh run from a git worktree does not leave the machine pointed at a path that will stop existing
- [ ] #2 Something fails, rather than staying silent, when the recorded sourceDir does not exist - whatever the cause
- [ ] #3 Verified by running the failing case, not by reading the code
<!-- AC:END -->
