---
id: TASK-19
title: Build the keyboard-driven interaction layer
status: To Do
assignee: []
created_date: '2026-08-19 18:16'
updated_date: '2026-08-20 17:12'
labels:
  - desktop
  - feel
dependencies:
  - TASK-2
priority: medium
type: feature
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The goal is that nothing routine requires the mouse. Today the launcher is wofi, which is GTK-based and noticeably slower to appear than native alternatives such as fuzzel; there is no clipboard history despite wl-clipboard being installed; and network, audio and power actions are only reachable through tray icons and pavucontrol. Each of these is a point where the workflow silently falls back to pointing and clicking.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Launcher options are compared on actual time-to-first-frame, not impression, and the choice is recorded
- [ ] #2 Clipboard history is available and reachable from a single binding
- [ ] #3 Network, audio, power and session actions each have a keyboard-reachable path
- [ ] #4 A discoverable way to see the current keybindings exists in-session
- [ ] #5 A full working day of routine actions is possible without touching the pointer
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
First slice: workspace navigation off the number row.

The complaint was reach - the number row is a stretch for the most frequent move on a keyboard-driven desktop. Settled by trying four arrangements live with runtime swaymsg bindings, which cost nothing to reject because the repository was never touched until one stuck. In order: $mod+Ctrl+h/l, then $mod+u/i, then $mod+Ctrl+j/k, then $mod+Ctrl+h/l with j as the toggle. The last survived.

Landed: $mod+Ctrl+h and $mod+Ctrl+l step between workspaces, $mod+Ctrl+j returns to the previous one, replacing $mod+Tab. The modifier carries the meaning - bare $mod moves between windows, $mod+Ctrl between workspaces - so it is derivable rather than memorised, with one deliberate exception: j is a toggle rather than a direction, given the best key because it is the most frequent action. That exception is commented in the config, since it is obvious now and would be mysterious later.

Reachability comes from this mornings keyd swap: Control is now the key beside the space bar, so these are thumb-and-home-row chords rather than the two-modifier contortion they would have been yesterday. TASK-40 paid off somewhere it was not aimed.

The number row stays, and the one-binding-per-action principle survives intact without amendment. $mod+1..0 reaches a workspace directly and $mod+Shift+1..0 remains the only way to send a window to one, so direct and relative access do not overlap. That only became clear after trying move-and-follow bindings on $mod+Ctrl+Shift and finding they were not wanted.

Tried and rejected in the same session, recorded so they are not proposed again as though new: $mod+u/i, cheaper to press but arbitrary and spending scarce $mod letters; move-window-and-follow on $mod+Ctrl+Shift+h/l/j, which worked correctly including the edge case where the source workspace is destroyed mid-command, but was not wanted; and a window picker on $mod+o listing every window across every workspace through wofi, which worked but did not earn its place. The picker is the one worth remembering, since it is the closest sway can come to the overview discussed in TASK-34 and sway has no expose of its own.
<!-- SECTION:NOTES:END -->
