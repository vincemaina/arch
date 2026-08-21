---
id: TASK-55
title: 'Resize windows directly, without entering a mode'
status: To Do
assignee: []
created_date: '2026-08-21 10:19'
labels:
  - desktop
  - feel
dependencies: []
ordinal: 53000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Resizing today means $mod+r to enter a resize mode, then hjkl, then Escape. That is three gestures for what is usually one small adjustment, and the mode is stateful - it captures the keyboard until dismissed, so a forgotten Escape makes the next keystroke do something unexpected. Direct bindings that resize by a step and return control immediately are wanted instead.

The request is $mod+minus and $mod+plus for height, and $mod+Shift+minus and $mod+Shift+plus for width.

THE COLLISION, WHICH HAS TO BE SETTLED FIRST

Both of those keys are already bound, to the scratchpad:

    $mod+minus         scratchpad show
    $mod+Shift+minus   move scratchpad

That is sway's conventional pairing and it is what checks/sway-bindings.sh exists to catch, so this cannot be added without deciding what happens to the scratchpad. Three ways out, and the choice belongs to whoever picks this up:

  * Move the scratchpad elsewhere. It is used rarely enough that it could take a less prized key.
  * Drop the scratchpad bindings entirely. Nothing in this setup currently puts a window there deliberately, and sway-toggle-window was written precisely because the scratchpad was the wrong shape for the bar's windows - see the note in that script.
  * Use different keys for resizing, e.g. bracket or comma/period, and leave the scratchpad alone.

Whether the resize mode stays afterwards is also worth deciding. It is better than direct bindings for a long series of adjustments, and redundant if the direct ones cover the common case.

A step size has to be picked too. The mode moves 10px, which is small for a 1920-wide screen; the direct bindings may want a proportional step (ppt) rather than pixels, so the same keypress does the same thing regardless of how the workspace is split.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Window height and width can each be grown and shrunk with a single keypress, with no mode to enter or leave
- [ ] #2 The collision with the existing scratchpad bindings is resolved deliberately, and checks/sway-bindings.sh reports no key bound twice
- [ ] #3 Whether the resize mode on $mod+r stays is decided rather than left as an accident
- [ ] #4 The step size is chosen against how it actually feels on a real split, not picked from the sway manual
- [ ] #5 The new bindings appear in tools/shortcuts.sh output alongside everything else
<!-- AC:END -->
