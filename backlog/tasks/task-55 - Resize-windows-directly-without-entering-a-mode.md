---
id: TASK-55
title: 'Resize windows directly, without entering a mode'
status: To Do
assignee: []
created_date: '2026-08-21 10:19'
updated_date: '2026-08-21 10:42'
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
- [ ] #1 Whether the existing $mod+r resize mode is sufficient is answered first, since it already does what was asked and may only be undiscoverable
- [ ] #2 If direct bindings are still wanted, they use keys that do not collide - the scratchpad keeps $mod+minus and $mod+Shift+minus
- [ ] #3 checks/sway-bindings.sh reports no key bound twice
- [ ] #4 The step size is chosen against how it feels on a real split, and proportional steps are weighed against pixels
- [ ] #5 Whatever lands is discoverable: it appears in tools/shortcuts.sh, and if the mode stays, the fact that it exists is easier to find than it is today
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
The scratchpad question is settled: moving its bindings is acceptable, so $mod+minus and $mod+Shift+minus are available for resizing.

That removes the blocker but not the decision - the scratchpad bindings have to go somewhere or be dropped, and dropping them is defensible here. Nothing in this setup puts a window in the scratchpad deliberately, and sway-toggle-window exists precisely because the scratchpad was the wrong shape for the bar's windows: it is one global stack, `scratchpad show` cycles rather than addressing a particular window, and showing one thing hides whatever else was in there.

Whoever picks this up should still check whether the scratchpad is wanted at all before rehoming it, rather than moving bindings nobody uses onto worse keys.

Revised after discussion. The scratchpad stays where it is - it is wanted, and moving it was only ever a way to free the requested keys.

That reopens the first question rather than settling it, because a resize mode already exists and always has: $mod+r enters it, hjkl resize by 10px, Return or Escape leave. It is in config.d/51-modes.conf. So the choice is no longer "direct bindings or a mode", it is "is the mode already there good enough, and if not, what is actually wrong with it".

Worth answering in that order, because if the answer is that the mode is fine and merely undiscoverable, this ticket is about discoverability and not about resizing at all - and the fix is tools/shortcuts.sh or a hint in the mode indicator, which waybar already displays when a mode is active.

If the mode is genuinely worse than direct bindings for the common case - one small nudge, where entering and leaving a mode is three gestures for one adjustment - then direct bindings are still wanted and need keys that are not $mod+minus. Unclaimed and reachable: bracketleft/bracketright, comma/period, and $mod+Shift+r. That is a smaller decision than rehoming the scratchpad.

The 10px step is worth revisiting either way. It is small on a 1920-wide screen, and a proportional step (ppt) would behave the same regardless of how the workspace is split.
<!-- SECTION:NOTES:END -->
