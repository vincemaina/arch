---
id: TASK-35
title: 'Toggle the bar away, and give the space back to the windows'
status: To Do
assignee: []
created_date: '2026-08-20 12:57'
labels:
  - desktop
  - feel
dependencies: []
priority: medium
type: feature
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The bar should be hideable on a key, for reading or focusing on one thing, and the windows should reclaim the strip it occupied rather than leaving a gap where it was. A bar that hides but leaves its space reserved is worse than one that stays.

Waybar reserves its strip through the layer shell exclusive zone, so whether tiled windows expand depends on the exclusive zone being released rather than the surface merely being drawn empty. That is the thing to verify, and it is easy to mistake a bar that has gone invisible for one that has gone away.

Mechanisms worth trying, cheapest first. Waybar responds to SIGUSR1 by toggling visibility, which is the obvious approach and needs checking against the point above. Waybar also has a hide mode and a start-hidden option, which may fit better if the wanted behaviour is closer to reveal-on-modifier than a persistent toggle.

One trap specific to this setup: the session units now use Restart=always, so anything that kills waybar to hide it will simply have it restarted a second later. An explicit systemctl --user stop is honoured and would work, but is heavier than signalling and loses the process. Whatever is chosen should not fight the supervision.

The binding belongs to sway, which is consistent with the keybinding principle that $mod is for window management - the bar is part of the frame rather than an application.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 One key hides the bar and the same key brings it back
- [ ] #2 Tiled windows expand into the freed strip while it is hidden, verified by looking rather than assumed from the bar disappearing
- [ ] #3 The mechanism does not fight Restart=always, so the bar does not reappear on its own
- [ ] #4 State survives what it should: a reload or a bar restart does not leave it hidden with no way back
- [ ] #5 The binding fits the existing scheme and appears in tools/shortcuts.sh
<!-- AC:END -->
