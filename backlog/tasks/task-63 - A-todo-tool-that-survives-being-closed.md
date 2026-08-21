---
id: TASK-63
title: A todo tool that survives being closed
status: To Do
assignee: []
created_date: '2026-08-21 10:23'
labels:
  - desktop
  - feel
dependencies:
  - TASK-59
ordinal: 65000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Tasks for this repository live in Backlog, which is deliberate and works. What has nowhere to go is everything else - the things that are not repository work and do not deserve a ticket, but do get forgotten.

Backlog is explicitly not the answer: it is repository tooling, it is committed, and a shopping list does not belong in the git history of an Arch build. Whatever this is, it is personal and lives outside setup/, which is TASK-59.

The interesting question is how much tool this needs. The honest range is wide:

  * A text file and an editor. Costs nothing, composes with everything, and is genuinely what many people use.
  * todo.txt with a CLI. A format with a spec, so priorities and dates are parseable, and plenty of readers exist.
  * taskwarrior. Recurrence, dependencies, projects, reports. Considerably more than is being asked for, and its own database rather than a text file.

The repository's own rule applies - new tooling earns its place - and it is worth being suspicious of the featureful answer. A todo list that needs to be learned is one that gets abandoned, and the failure mode of this category is a tool you stop opening.

Overlap to resolve rather than ignore: a todo with a date is a calendar entry, and TASK-61.4 is building reminders. If a todo can have a due date and a reminder, either that machinery is shared or it is built twice.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A task can be added and completed in one gesture from the launcher
- [ ] #2 The tool is chosen against how much it actually needs to do, with the plain-text option priced honestly against the featureful one
- [ ] #3 Its relationship to Backlog is stated, so it is clear which one a given task belongs in
- [ ] #4 If tasks can have due dates, whether reminders are shared with TASK-61.4 or separate is decided rather than duplicated
- [ ] #5 No task data is committed to this repository
<!-- AC:END -->
