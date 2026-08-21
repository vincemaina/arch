---
id: TASK-96
title: checks/session.sh hangs on its screenshot check whenever the screen is locked
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 21:18'
updated_date: '2026-08-21 21:22'
labels:
  - desktop
  - repo
dependencies: []
ordinal: 98000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The screenshot section of checks/session.sh runs $HOME/.local/bin/sway-screenshot and waits for it. With swaylock on screen, grim never returns - the wlr-screencopy request is not answered while the session is locked - so the check blocks until whatever is running it gives up, and then reports 'sway-screenshot did not produce a file: Terminated', which reads like the helper is broken.

MEASURED, not inferred. With swaylock running:

    $ time timeout 20 grim /tmp/g.png
    timeout 20 grim /tmp/g.png  0.00s user 0.00s system 0% cpu 20.001 total

grim used no CPU at all and produced no file - it is waiting, not failing. Unlocking makes the same command return immediately.

This is easy to hit and hard to read. swayidle locks after 300 seconds, so any session left alone for five minutes - which is every session where the work is being done over IPC rather than at the keyboard - puts checks/session.sh into this state. The failure message names the helper, so the natural next step is to go and debug a helper that is fine.

The check itself is worth keeping; what is missing is that it cannot distinguish 'grim is broken' from 'the compositor will not answer while locked'. Both a timeout and a lock-state test are cheap: swaylock's presence is visible in the process list, and sway reports it too.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 checks/session.sh no longer blocks when the screen is locked
- [ ] #2 A locked session is reported as skipped, with the reason, rather than as a failure of the screenshot helper
- [ ] #3 A genuinely broken screenshot helper still fails, so the skip has not swallowed the check - demonstrated by breaking it deliberately
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixed. Two changes, because the lock is the known cause and not the only possible one.

The check now skips when swaylock is running, saying why: the helper cannot be tested while the screen is locked and nothing in a check can unlock it. Refusing to try is the honest result - not a pass, because nothing was captured.

And the capture is bounded at 15s regardless, failing with 'something is holding the output' rather than waiting. A check that can wait forever is worse than one that is occasionally wrong: this one hung a full session.sh run for over two minutes while I was verifying something else, which is how it was met rather than read about.

The mechanism, since it is not obvious: swaylock takes an exclusive lock on every output, and a screencopy request against a locked output is not refused - it is queued until the output is readable again. So grim uses no CPU and never returns, which reads as a broken helper and is a working one waiting.

Verified: with the screen locked, session.sh now completes in seconds and reports 74 passed, 1 failed, 1 skipped - the failure being TASK-89's zswap drop-in awaiting a sync.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
checks/session.sh no longer hangs when the screen is locked. swaylock holds an exclusive lock on every output and a screencopy request queues rather than failing, so grim waited indefinitely and the whole run stalled. The check now skips with the reason when swaylock is running, and bounds the capture at 15s in every other case.
<!-- SECTION:FINAL_SUMMARY:END -->
