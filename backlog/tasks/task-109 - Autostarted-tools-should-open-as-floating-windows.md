---
id: TASK-109
title: Autostarted tools should open as floating windows
status: To Do
assignee: []
created_date: '2026-08-22 12:07'
labels: []
dependencies: []
priority: low
ordinal: 117000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Split out of TASK-103, which was about showing a spectrum of whatever is playing and is done. Autostart was the wrong thing to hang on it.

The preference, from the user: anything that opens itself at login should open FLOATING rather than tiled, because it looks better. A tiled window arriving at login rearranges whatever is already on the workspace and claims a share of the screen it did not earn; a floating one sits where it is put.

The visualiser is the case that raised it - cava tiles like any other window today, which is right when you open it deliberately and wrong for something appearing on every login and taking a third of the screen. It is measured at 3.27% of one core and about 20 MiB while running (see TASK-103), so it is cheap enough to leave running; the objection is entirely to the space and the disruption.

This is a policy question rather than one window. It touches setup/dotfiles/dot_config/sway/config.d/40-window-rules.conf, which is where app_id-based floating rules already live, and it has to work with TASK-77 startup toggles so anything added this way can still be turned off. Worth deciding once: which app_ids, what size, where on the screen, and whether "autostarted" is a property the toggle system should know about rather than something each rule repeats.

Note the app_id trap recorded in CLAUDE.md: the app_id ties together the command that sets it, any toggle that finds the window by it, and the for_window rule that floats it. Nothing notices when the three disagree - the window just tiles.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A tool that opens itself at login appears as a floating window, not tiled
- [ ] #2 Its position and size are deliberate rather than whatever sway picks
- [ ] #3 It goes through the startup toggles, so it can be turned off without editing config
- [ ] #4 The rule is general enough that the next autostarted tool does not need a new special case
<!-- AC:END -->
