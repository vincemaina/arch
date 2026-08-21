---
id: TASK-61.4
title: 'Remind me before, not after'
status: To Do
assignee: []
created_date: '2026-08-21 10:22'
labels:
  - desktop
  - feel
dependencies: []
parent_task_id: TASK-61
ordinal: 63000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A calendar you have to remember to look at is a list. The reminder is the part that makes it useful.

mako is already the notification daemon and already has urgency handling, grouping and a do-not-disturb mode, plus a notification centre on the bar for anything missed - so the delivery mechanism exists and this is about deciding what fires and when, not about building a notifier.

The scheduling is the interesting part. A timer per event is precise and multiplies; a single timer that wakes periodically and asks what is due is simpler and can miss things across a suspend. Suspend is worth thinking about specifically: a machine asleep through a reminder should say something on waking rather than nothing, and systemd timers have a persistent mode that behaves that way.

Whether the lead time is fixed, per event, or per calendar is a small decision that changes the storage, so it should be made before the storage is written rather than after.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A notification arrives before an event, through mako
- [ ] #2 How far ahead is configurable rather than hardcoded
- [ ] #3 A reminder that falls while the machine is asleep is handled deliberately, one way or the other
- [ ] #4 Reminders survive a reboot without needing anything to be started by hand
<!-- AC:END -->
