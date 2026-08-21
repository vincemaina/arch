---
id: TASK-61
title: A calendar worth opening
status: To Do
assignee: []
created_date: '2026-08-21 10:21'
labels:
  - desktop
  - feel
dependencies:
  - TASK-59
ordinal: 59000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The calendar the clock opens is custom, in the sense that ~/.local/bin/calendar is a script in this repository - but what it does is run `cal -3` in a floating foot window. It prints three months and highlights today. It knows nothing about you: no events, no reminders, nothing coming up. It answers "what date is that Thursday" and nothing else.

That was the right size when it was built - the alternative was a large GTK dependency rendering exactly what cal already prints, and there was no calendar data on the machine for it to show. This ticket is about there being data.

What is wanted, in rough order of how much each would be used:

  * A view of what is coming up over the next week or so, rather than a grid of numbers.
  * Adding an event without leaving the keyboard.
  * The events from Google Calendar, so this shows the calendar that actually exists rather than a second empty one.
  * Reminders that arrive before the thing rather than after it.

Each of those is a subtask, because each is independently useful and the first is worth having before the others exist. They share a store, which is why they are subtasks of one parent rather than four unrelated tickets.

THE DECISION THAT GATES ALL OF IT

What holds the events. The realistic options are a local iCalendar store synced with CalDAV - khal with vdirsyncer is the usual pairing, both packaged, both terminal-first, and Google speaks CalDAV - or a Google-only client such as gcalcli that treats the account as the source of truth and keeps nothing locally.

The difference that matters is what happens with no network. A local store still shows the week ahead on a train; a thin client shows an error. This machine is a laptop-shaped thing and the whole repository is built around working offline and reproducibly, which points at the local store - but that is an argument, not a decision, and it belongs in the first subtask rather than being assumed here.

Whatever is chosen, TASK-59 decides where its data sits, and it is not in this repository: a calendar full of your appointments is not part of a reproducible Arch install.

The existing calendar window is the obvious surface to grow, and clicking the clock is already the gesture. It should keep working the whole time - a half-built calendar that has stopped showing the month is worse than the one that only showed the month.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Clicking the clock shows what is actually coming up, not only a grid of dates
- [ ] #2 An event can be added without leaving the keyboard
- [ ] #3 Events from the Google account appear, and events added locally reach it
- [ ] #4 A reminder arrives before an event, through mako like every other notification
- [ ] #5 It still works with no network, or the limitation is a recorded decision rather than a surprise
- [ ] #6 No calendar data is committed to this repository
<!-- AC:END -->
