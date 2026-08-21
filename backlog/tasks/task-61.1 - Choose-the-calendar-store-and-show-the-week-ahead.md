---
id: TASK-61.1
title: 'Choose the calendar store, and show the week ahead'
status: To Do
assignee: []
created_date: '2026-08-21 10:22'
labels:
  - desktop
  - feel
dependencies: []
parent_task_id: TASK-61
ordinal: 60000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The first slice, and the one that decides the shape of the rest: what holds the events, and a view of what is coming up.

Settle the store first. khal plus vdirsyncer is a local iCalendar store synced over CalDAV, which Google speaks; gcalcli is a thin client with the account as the source of truth. The deciding question is what happens with no network - a local store still shows the week ahead, a thin client shows an error - but it should be checked rather than assumed, along with what each costs to install and whether either needs anything from the AUR, which TASK-43 has not yet decided this repository supports.

Then the view. `cal -3` stays as the month grid, because it is genuinely the right answer for "what date is that Thursday", but it should no longer be the whole window. The week ahead is what the calendar is opened for.

The window already exists and already floats: keep the app_id so that clicking the clock twice still closes it, and keep it opaque - dense small text over a translucent background was unreadable and is a fixed bug, not a preference.

Nothing here needs Google to work. An empty local calendar showing an empty week is a working first slice.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The store is chosen with the offline behaviour of each option actually tested, and recorded in DECISIONS.md
- [ ] #2 Anything it needs is declared in packages/, and if only the AUR has it, that is raised against TASK-43 rather than worked around quietly
- [ ] #3 The calendar window shows what is coming up over roughly the next week
- [ ] #4 The month grid is still reachable, since that is what the window did well already
- [ ] #5 Clicking the clock twice still closes it, and the window is still floating and opaque
<!-- AC:END -->
