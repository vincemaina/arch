---
id: TASK-131
title: 'A mistyped password ends the whole install, after the disk has been erased'
status: Done
assignee:
  - '@vincemaina'
created_date: '2026-08-22 23:10'
updated_date: '2026-08-22 23:14'
labels: []
dependencies: []
type: bug
ordinal: 135000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
setup/install/03-system.sh sets the root and user passwords with a bare `passwd` (lines 41 and 45) under `set -euo pipefail`. `passwd` exits non-zero when the two entries do not match, so a typo kills the stage, `arch-chroot` returns non-zero, and `install.sh` - also `set -e` - aborts the entire install.

By the time stage 3 runs, `01-disk.sh` has already erased and repartitioned the disk and `02-base.sh` has pacstrapped the base system. So the cheapest possible mistake, made at the one prompt where nobody is looking at a keyboard they trust, throws away everything done so far and requires starting again from the ISO.

It also strands the machine in the state described by the sibling task about re-running an aborted install: the target filesystems are left mounted on /mnt, so the second attempt fails at the disk stage too.

Retrying the prompt is the obvious fix. Worth noting for whoever picks this up: passwords are deliberately never stored (see the comment at the foot of setup/install.conf and the wizard section of CLAUDE.md), so the answer is to re-ask at the point of failure, not to collect passwords in the wizard up front.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A mismatched or rejected password re-prompts rather than ending the stage
- [x] #2 The retry is bounded, so an install whose stdin is not a terminal cannot spin forever on EOF
- [x] #3 A genuine, repeated failure still fails the stage loudly rather than continuing with no password set
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Wrap passwd in a bounded retry helper in 03-system.sh, used for both root and the new user.
2. Cap attempts so a non-terminal stdin cannot spin on EOF; fail loudly after the cap.
3. Verify with a fake passwd on PATH that succeeds/fails on cue.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Replaced the two bare `passwd` calls in 03-system.sh with a set_password helper that retries. Uses `passwd root` rather than a bare `passwd` so one helper covers both accounts. Bounded at 5 attempts rather than an unconditional `until`, because passwd against a pipe or closed stdin fails instantly and forever and would otherwise spin an unattended install; exhausting the attempts still returns non-zero so the stage fails rather than building a machine with no root password.

Verified by extracting set_password and running it under the same `set -euo pipefail` as the stage, against a fake passwd on PATH that fails on cue: (1) success first time - 1 invocation, returns 0; (2) two mismatches then success - 3 invocations, returns 0, stage continues (this is the reported bug, now fixed); (3) always fails - stops at exactly 5 invocations, returns non-zero with a message, proving the EOF case terminates rather than spinning. checks/wizard.sh 91/91, checks/session.sh 92/92, checks/manual.sh 8/8.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
03-system.sh now retries the password prompt instead of letting a mismatch end the install. A set_password helper wraps passwd for both root and the user, bounded at 5 attempts so a non-terminal stdin cannot spin, and still failing the stage loudly if they are all used up. Verified by running the helper under the stage's own shell options against a fake passwd: a mistype now re-asks and the install continues, and the never-succeeds case stops at exactly 5 rather than looping.
<!-- SECTION:FINAL_SUMMARY:END -->
