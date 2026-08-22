---
id: TASK-121.1
title: sync.sh run from a worktree records a sourceDir that stops existing
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 17:11'
updated_date: '2026-08-22 17:32'
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
- [x] #1 A sync.sh run from a git worktree does not leave the machine pointed at a path that will stop existing
- [x] #2 Something fails, rather than staying silent, when the recorded sourceDir does not exist - whatever the cause
- [x] #3 Verified by running the failing case, not by reading the code
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Measure what chezmoi actually does with a dead sourceDir, rather than repeating the claim in the manual.
2. sync.sh: resolve a linked worktree to the main working tree before recording, since the main checkout is what persists.
3. checks/session.sh: fail when a bare chezmoi command manages nothing - covering a moved or deleted clone, not just this cause - and fail while it still works if the recorded path is inside a worktree.
4. Make the repair advice resolve to the main checkout, since a check run from a worktree would otherwise advise the bug.
5. Run all four states rather than reading the code: worktree sync, plain-clone sync, dead sourceDir, live worktree sourceDir.
6. Correct the manual where the measurement contradicts it.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Measured first, because the manual's account of the symptom turned out to be half wrong. Against chezmoi 2.72 with a sourceDir that does not exist:

  chezmoi source-path  ->  prints the dead path, exit 0
  chezmoi managed      ->  no output, exit 0
  chezmoi status       ->  'no such file or directory', exit 1

So chezmoi status does complain, contrary to the manual, and the silent one is managed - which is the one tooling calls, and the one the stale-dotfile check called. The manual now says which is which. (The first probe of this proved nothing: overriding HOME alone still read the real config, because chezmoi prefers XDG_CONFIG_HOME and this environment sets it. Both are needed to isolate.)

Two halves to the fix.

sync.sh resolves a linked worktree to the main working tree before recording, via the first entry of 'git worktree list --porcelain' - sed rather than awk because a path may contain spaces. Recording the main checkout rather than skipping the record was the choice: skipping would leave an already-dead pointer dead, while recording repairs it. --dry-run now also prints what it would record, which was the one piece of machine state sync.sh writes outside chezmoi and the one thing the preview did not cover.

checks/session.sh gains 'Where a bare chezmoi command looks': it fails when a bare chezmoi manages nothing, which catches a moved or deleted clone as well as this cause, and fails while everything still works if the recorded path is inside .claude/worktrees/. Its repair advice resolves to the main checkout rather than to CHECKS_REPO - run from a worktree, advising CHECKS_REPO would hand you the bug as the fix.

All four states run, none inferred:
- sync.sh --dry-run from this worktree: 'Recording /home/vincemaina/Arch/setup, not this worktree'.
- sync.sh --dry-run from a plain clone in tmp: records the clone itself, unchanged behaviour. The first attempt at this tested nothing, because git clone takes committed history and the fix was still uncommitted.
- Recorded sourceDir set to the exact path from TASK-121 (task-112-select-all, long gone): FAIL, naming the repair.
- Recorded sourceDir set to this live worktree: FAIL, saying it is deleted with the task.
- Healthy machine: PASS, 126 managed files.

The machine's own config was untouched throughout - still /home/vincemaina/Arch/setup, 126 managed. checks/session.sh 93 passed 0 failed, checks/manual.sh 8 passed 0 failed, manual builds.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
sync.sh run from a linked worktree now records the main working tree, so the path it writes into machine state outlives the task that created it. checks/session.sh gains a check that a bare chezmoi command manages anything at all, which catches a moved or deleted clone too, and fails on a recorded worktree path while it still works rather than after it stops. The repair advice resolves to the main checkout, since a check run from a worktree would otherwise advise the very path that causes this.

Verified by running each state, not by reading the code: dry-run from the worktree records /home/vincemaina/Arch/setup; dry-run from a plain clone records itself; the exact dead path from TASK-121 fails with the repair command; a live worktree path fails as transient; the healthy machine passes with 126 managed files. The machine's own config was untouched.

Measuring the symptom also corrected the manual: chezmoi status does report a missing source and exits 1 - it is chezmoi managed that returns nothing and exits 0, which is why the silent half is the half tooling calls.
<!-- SECTION:FINAL_SUMMARY:END -->
