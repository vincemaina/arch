---
id: TASK-33
title: Show something worth looking at when the session starts
status: To Do
assignee: []
created_date: '2026-08-20 12:53'
labels:
  - desktop
  - feel
dependencies: []
priority: low
type: feature
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A first terminal that opens on an empty prompt is a missed moment on a desktop that has otherwise been given a lot of attention. A system summary - distro, kernel, uptime, memory, the window manager, a colour strip - is the conventional way to fill it, and doubles as a quick sanity check that the machine is what you expect.

Worth noting that neofetch was archived by its author in 2024 and is no longer maintained. fastfetch is the actively developed successor, is in the official repositories, and is considerably faster, which matters if this runs every time a terminal opens.

Two questions to settle rather than assume. Where it runs: on every new terminal is the obvious choice and also the one that gets tiresome and adds startup time to a shell currently measured at 128ms; only on the first terminal of a session is more considered but needs somewhere to track that state. And what it shows: the default output is long and mostly static, whereas the parts worth seeing are the ones that change.

Colours should come from the palette rather than being chosen separately.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A system summary appears when a session starts, without noticeably delaying the shell
- [ ] #2 Where it runs is a deliberate decision, not every terminal by default
- [ ] #3 The output is trimmed to what is worth reading rather than left at the default
- [ ] #4 Its colours come from the existing palette
- [ ] #5 Shell startup time is measured after adding it and still passes the existing budget
<!-- AC:END -->
