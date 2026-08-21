---
id: TASK-35
title: 'Toggle the bar away, and give the space back to the windows'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-20 12:57'
updated_date: '2026-08-21 20:59'
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
- [x] #1 One key hides the bar and the same key brings it back
- [x] #2 Tiled windows expand into the freed strip while it is hidden, verified by looking rather than assumed from the bar disappearing
- [x] #3 The mechanism does not fight Restart=always, so the bar does not reappear on its own
- [x] #4 State survives what it should: a reload or a bar restart does not leave it hidden with no way back
- [x] #5 The binding fits the existing scheme and appears in tools/shortcuts.sh
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Measure the exclusive zone first: a tiled window's geometry from swaymsg -t get_tree, on a throwaway headless output, before and after each candidate mechanism.
2. Try SIGUSR1 to waybar, the cheapest option, and check it releases the layer-shell exclusive zone rather than only blanking the surface.
3. Deliver it as a helper, ~/.local/bin/sway-toggle-bar, signalling through systemctl --user kill --kill-whom=main so the unit is never stopped and Restart=always has nothing to react to.
4. Bind it in sway on $mod+Shift+b with a trailing # comment so the shortcuts panel gets a real label.
5. Verify: geometry before/after, sway reload while hidden, waybar restart while hidden, then checks/sway-bindings.sh, checks/sway-commands.sh, checks/session.sh and tools/shortcuts.sh.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
MECHANISM: SIGUSR1 to waybar, delivered as `systemctl --user kill --kill-whom=main --signal=SIGUSR1 waybar.service` from a new helper, setup/dotfiles/dot_local/bin/executable_sway-toggle-bar.

Why the signal and not a stop: the unit keeps running, so Restart=always has nothing to react to and there is nothing to fight. Measured NRestarts=0 and the same MainPID across a full hide/show cycle. A stop would have worked too but throws the process away and makes coming back a cold start.

Why --kill-whom=main: systemctl kill defaults to every process in the cgroup. waybar's on-click commands are spawned as its children, and SIGUSR1 terminates a process that does not handle it - so the default would take a terminal opened from the bar with it.

THE EXCLUSIVE ZONE IS ACTUALLY RELEASED - the thing the ticket said to prove. Measured from swaymsg -t get_tree, not from a screenshot, on a throwaway headless output (1920x1080, gaps 12):

  tiled window, bar shown:   x=1932 y=41 w=1896 h=1027
  tiled window, bar hidden:  x=1932 y=12 w=1896 h=1056
  tiled window, shown again: x=1932 y=41 w=1896 h=1027

The window gains exactly the 29px the bar reserved and the 12px gap is untouched. The workspace rect on the real output moved the same way (y=41 h=1027 -> y=12 h=1056), so it is not a per-window artefact. waybar's setVisible releases the zone as well as hiding the surface; that is what makes this work and is the thing to re-check if it ever stops.

STATE ACROSS RELOAD AND RESTART:
  sway reload while hidden      -> window stays at y=12 h=1056; the hidden state survives
  systemctl restart waybar      -> window returns to y=41 h=1027; the bar comes back visible

That is the safe direction to fail in: no state is stored anywhere, so the bar can never be left hidden with nothing able to bring it back. The helper also starts waybar.service if it is not active, so the key means "bring the bar back" even if the service is down.

BINDING: $mod+Shift+b, which was free. $mod because the bar is part of the frame rather than an application; Shift because it is infrequent, the same argument that keeps reload and exit on Shift. Verified sway really holds it: `swaymsg unbindsym Mod4+Shift+b` succeeds where an unbound key (Mod4+Shift+y) errors with "Could not find binding".

The bindsym carries a trailing `# Hide or show the bar`, which the shortcuts panel uses as an override label - harmless to sway because an exec line is handed to sh, where it is a shell comment. Confirmed by running the exact string sway runs.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added `~/.local/bin/sway-toggle-bar`, bound to $mod+Shift+b in setup/dotfiles/dot_config/sway/config.d/50-keybindings.conf. It signals waybar with SIGUSR1 via `systemctl --user kill --kill-whom=main`, so the unit keeps running and Restart=always never fights it (NRestarts=0, MainPID unchanged across a cycle).

Verified from swaymsg -t get_tree rather than a screenshot: a tiled window on a 1080p output goes from y=41 h=1027 to y=12 h=1056 when the bar is hidden and back again - it gains exactly the 29px the layer-shell exclusive zone reserved, so the zone is released and not merely blanked. A sway reload leaves the hidden state alone; restarting waybar brings the bar back, so it can never be stuck hidden. checks/sway-bindings.sh (68 bindings, no duplicates), checks/sway-commands.sh and tools/shortcuts.sh all pass, and the shortcut reads "Super+Shift+b  Hide or show the bar" in the $mod+? panel. checks/session.sh is 75 passed / 1 failed, the failure being a pre-existing zswap-still-enabled report unrelated to this change.
<!-- SECTION:FINAL_SUMMARY:END -->
