---
id: TASK-21
title: Handle displays and colour temperature automatically
status: To Do
assignee: []
created_date: '2026-08-19 18:16'
updated_date: '2026-08-19 18:17'
labels:
  - desktop
  - feel
dependencies:
  - TASK-17
priority: medium
type: feature
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The config has no output configuration beyond a wallpaper line, so any machine with more than one display, or a laptop that gets docked and undocked, needs manual swaymsg commands after every change. There is also no night-time colour temperature shift. Both are things that should simply happen rather than be managed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Display layout is applied automatically per hardware arrangement and survives hotplug
- [ ] #2 Docking and undocking a laptop needs no manual command
- [ ] #3 Colour temperature shifts on a schedule appropriate to location
- [ ] #4 A single-output VM install is unaffected and produces no errors
- [ ] #5 Layouts are declared in the repository, not configured on the machine
<!-- AC:END -->
