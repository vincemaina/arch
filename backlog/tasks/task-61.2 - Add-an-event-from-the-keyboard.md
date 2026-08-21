---
id: TASK-61.2
title: Add an event from the keyboard
status: To Do
assignee: []
created_date: '2026-08-21 10:22'
labels:
  - desktop
  - feel
dependencies: []
parent_task_id: TASK-61
ordinal: 61000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Adding an event should be as quick as the launcher is for everything else, or it will not be used and events will keep being added on a phone.

Two shapes worth weighing. A prompt that parses what you type - "lunch with sam thursday 1pm" - which is fast when it works and irritating when it guesses wrong, and needs a way to see what it understood before committing. Or a small form with the fields separated, which is slower and never surprises you. khal ships `khal new` with its own syntax, which may be enough on its own.

Whichever it is, the event has to land in the store chosen by the sibling ticket, and must be visible in the week view immediately rather than after a sync.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 An event can be created from the launcher or the calendar window without using a pointer
- [ ] #2 What was understood is shown before it is saved, if the input is parsed rather than entered field by field
- [ ] #3 A newly added event appears in the week view straight away
<!-- AC:END -->
