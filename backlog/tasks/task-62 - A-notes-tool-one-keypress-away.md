---
id: TASK-62
title: 'A notes tool, one keypress away'
status: To Do
assignee: []
created_date: '2026-08-21 10:23'
labels:
  - desktop
  - feel
dependencies:
  - TASK-59
ordinal: 64000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
There is nowhere to write something down. A thought during a build, a command worth keeping, the reason a decision was made - all of it currently goes into a scratch file that gets lost, or nowhere.

The requirement that decides the design is that it opens fast enough to use mid-thought. Anything that takes two seconds to appear will lose to not bothering. That points at the pattern already used four times here - a helper in ~/.local/bin, a .desktop entry with an absolute Exec, a floating foot window with its own app_id and a for_window rule - rather than at a note-taking application.

What is worth settling:

  * Whether a new note is a new file or an append to a running one. Both are defensible: separate files are searchable and organisable, a single running log is faster and never asks you to name anything before you have written it.
  * Whether finding a note again is a listing, a search, or just yazi and ripgrep on a directory - both are installed, and the cheapest good answer might be no new tool at all for reading, only for capture.
  * Whether it needs to be aware of the todo tool. A note with a checkbox in it is a todo, and TASK-59 decides whether these are one thing or three.

The launcher already opens the notification centre and the theme switcher; this should feel like those, not like a new application. A binding as well as a launcher entry is probably justified for capture specifically, since the whole value is speed.

Where the notes live and whether they survive a rebuild is TASK-59, not this ticket. What is certain is that they do not live in this repository.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A note can be captured in one gesture from anywhere, without first choosing where to put it
- [ ] #2 Notes written earlier can be found again, and how is a deliberate choice rather than whatever was easiest
- [ ] #3 It follows the existing helper pattern: absolute Exec, own app_id, floating rule, themed like everything else
- [ ] #4 No note content is committed to this repository
- [ ] #5 Any binding it takes does not collide, and appears in tools/shortcuts.sh
<!-- AC:END -->
