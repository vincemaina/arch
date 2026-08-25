---
id: TASK-176
title: 'Caffeinate timed sessions must expire on wall-clock time, not monotonic'
status: To Do
assignee: []
created_date: '2026-08-25 17:29'
labels: []
dependencies: []
ordinal: 183000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A timed caffeinate session survives a suspend/resume and keeps running past the time it was supposed to end.

Reproduce: `caffeinate 1h`, suspend the laptop for 30 minutes, resume. The hour is up 30 minutes later than it should be — the machine stays uninhibited past its expiry.

Cause (confirmed from `man systemd.timer`): `turn_on_for` schedules the expiry with `systemd-run --user --on-active="$dur"`. `OnActiveSec=` is a *monotonic* timer, and the man page states plainly: "If the computer is temporarily suspended, the monotonic clock generally pauses, too." So the suspended time is not counted and `caffeinate off` fires late by however long the machine was asleep.

The two halves of the feature already disagree about which clock they use. The state file stores `UNTIL` as an absolute epoch and `read_state` computes the remaining time by subtracting `date +%s`, so the countdown in the bar *is* wall-clock and is already correct. Only the thing that actually turns caffeinate back off is monotonic. After a long enough suspend the countdown clamps to 0 and the bar sits on `<1m` indefinitely while swayidle stays stopped — the display says expired, the system is still inhibited.

The intent is the one already written into the state file: the moment a duration is chosen, the target instant is fixed, and everything afterwards is a comparison against the wall clock. Whether the process counting is alive, and whether the machine was awake, should not change when the session ends.

Worth deciding during implementation: whether expiry that falls *during* suspend should also self-heal on the next `read_state` (the countdown already knows it hit zero) as well as being scheduled correctly, so a stale timer can never leave the machine inhibited. And note that `WakeSystem=` is deliberately not wanted here — caffeinate expiring should not wake a sleeping laptop.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A timed caffeinate session started before a suspend expires at the wall-clock instant it was scheduled for, regardless of how long the machine was suspended
- [ ] #2 If the expiry instant passes while the machine is suspended, caffeinate is off (swayidle running) once the machine is back, without waiting for the remainder of the original duration
- [ ] #3 Expiry never wakes a suspended machine
- [ ] #4 The bar countdown and the actual expiry agree: the bar cannot sit at zero or `<1m` while swayidle is still stopped
- [ ] #5 The `checks/session.sh` and `checks/sway-commands.sh` checks still pass, including any command newly invoked by the script being declared in a package manifest
- [ ] #6 The header comment in `~/.local/bin/caffeinate` explaining the timer choice is updated to record why the clock changed, so the monotonic version is not reintroduced
<!-- AC:END -->
