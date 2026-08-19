---
id: TASK-2
title: Redesign the keybinding model
status: To Do
assignee: []
created_date: '2026-08-19 15:27'
updated_date: '2026-08-19 18:17'
labels:
  - desktop
  - feel
dependencies:
  - TASK-17
priority: high
type: enhancement
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The bindings are still essentially the sway defaults with a few app launchers bolted on, and two of those collide with core layout verbs: mod+b at line 147 overwrites splith and mod+e at line 153 overwrites layout toggle split. So two fundamental tiling operations were traded for launching a browser and a file manager. The wider question is what the interaction model should be - which actions deserve a bare chord, which belong behind a mode, and how to keep it coherent as more is added - rather than accumulating bindings one at a time.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Core layout operations are all reachable again, including the split verbs currently shadowed
- [ ] #2 The binding scheme follows a stated organising principle rather than being ad hoc
- [ ] #3 Application launching does not consume bindings needed for window management
- [ ] #4 No binding is defined twice or silently overridden
- [ ] #5 The scheme is documented so it can be extended consistently later
<!-- AC:END -->
