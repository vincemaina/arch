---
id: TASK-36
title: 'Explore dynamic tiling, so splits pick themselves'
status: To Do
assignee: []
created_date: '2026-08-20 13:00'
labels:
  - desktop
  - feel
dependencies: []
priority: low
type: spike
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Sway always splits in whichever direction was last set, so keeping a sensible layout means deciding split direction before opening each window. Dynamic tiling would choose for you - split a wide container horizontally, a tall one vertically - and possibly decide placement too, the way a dwindle or master-and-stack layout does.

Not essential. The current behaviour is predictable and predictability has real value in a tiling window manager. This is about whether the workflow feels intuitive rather than whether it works.

The usual approach is a small daemon listening on the sway IPC socket, watching for focus changes and setting splith or splitv based on the focused container dimensions. autotiling is the common one; whether it or an equivalent is in the official repositories needs establishing, since this repository does not build from the AUR, and a script this small might be better owned here than depended upon.

Two connections worth making rather than discovering later.

It interacts directly with TASK-2. The split verbs on mod+b and mod+v were only just restored after an application binding had shadowed them; if dynamic tiling works well those become manual overrides for the cases it gets wrong rather than the primary mechanism, which changes how prominent they should be.

It also overlaps TASK-31. Hyprland ships dwindle and master layouts natively, so if a compositor change is being considered anyway, this stops being a thing to add and becomes a property of that choice.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Whether an implementation exists in the official repositories is established, and if not, whether writing one here is proportionate
- [ ] #2 Tried for long enough to judge feel rather than mechanism, since the whole question is whether it is more intuitive
- [ ] #3 The effect on the split bindings is decided: kept as overrides, demoted, or removed
- [ ] #4 Any cost is measured - a daemon on the IPC socket reacting to every focus change is not free
- [ ] #5 A decision is recorded in DECISIONS.md, and concluding that manual splits are better counts as completing this
<!-- AC:END -->
