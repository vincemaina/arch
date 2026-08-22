---
id: TASK-105.5
title: 'Manual part II: installing on new hardware, and keeping it healthy'
status: Done
assignee: []
created_date: '2026-08-22 10:27'
updated_date: '2026-08-22 11:05'
labels: []
dependencies: []
parent_task_id: TASK-105
ordinal: 112000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Chapters nine and ten. Installing: what install.sh does to a disk, the wizard, the identity it asks for, the partition layout, and what to do differently on real hardware versus a VM - including the things known to differ, such as the Caps Lock indicator. Keeping it healthy: the four checks and what each answers, updating packages, how drift is detected in both directions, reading logs when a session component fails, and the traps this repository keeps falling into.

The troubleshooting section should be grounded in failures that actually happened here rather than generic advice.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A reader can install this system onto a new machine from the manual alone
- [x] #2 Each of the four checks is documented with what it answers and what a failure means
- [x] #3 Troubleshooting covers the real recurring failure mode: configuration that looks correct and does nothing
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Wrote docs/manual/09-installing.md and 10-keeping-it-healthy.md from install.sh, the install stages, sync.sh and the check scripts directly.

AC#2 done, and the table grew: the ticket said four checks, and checks/manual.sh made five during this same piece of work. Chapter 10 documents all five, each with what it answers, when to run it and what a failure means, plus the checks/ versus tools/ distinction and the known screenshot-hang-when-locked behaviour of session.sh. checks/manual.sh is documented WITH ITS LIMIT stated, using the real case that had just happened: when $mod+minus stopped opening the scratchpad and started shrinking a window, the check caught a companion binding that had become unbound and said nothing about $mod+minus itself, which was still bound and now meant something else. Existence is checkable, meaning is not.

AC#3 done. The troubleshooting section is built from failures that actually happened in this repository - media keys calling an uninstalled playerctl, screenshots written to a directory nothing created, polkit with no agent, and the SPICE guest agent that was installed to fix a ghost cursor, did not, and stayed with a manifest comment describing the hypothesis as though it were the outcome. It teaches asking the running system rather than listing generic advice.

AC#1 NOT checked, and this is the honest gap. Nothing in this repository or its backlog records this build ever running on physical hardware, so every real-hardware statement in chapter 9 - the Caps Lock LED, the rendering path, whether the cursor fix is needed there - is written as "expected to" or "not yet tested" rather than as a promise. A reader could follow the chapter onto a new machine, but nobody has, and claiming otherwise would be exactly the failure this repository keeps hitting.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Two chapters on installing onto new hardware and on living with the result. All five checks documented, including the new one and the precise limit of what it can see. AC#1 left unchecked because nobody has installed this on physical hardware, so the hardware-specific claims are hedged rather than asserted.
<!-- SECTION:FINAL_SUMMARY:END -->
