---
id: TASK-53
title: 'Make the bar clickable, and put the clock and media where the window title was'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-21 04:22'
updated_date: '2026-08-21 04:22'
labels:
  - desktop
  - feel
  - dotfiles
dependencies: []
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two changes to the bar, which turn out to be related.

Nothing in the bar does anything when clicked except pulseaudio, which opens pavucontrol. Every other module is a readout you can only look at. Clicking a reading should open the thing that explains it - cpu or memory should open btop, the network module should offer somewhere to change the connection, and so on. A bar that reports without responding trains you to ignore it.

The centre currently shows the focused window's title, which is not worth the space: sway already shows which window is focused by giving it the accent border, and the title is usually a truncated path. The date and time should be there instead - it is the thing most often wanted at a glance, and it is currently squeezed into the right-hand run of readouts. Clicking it should open a calendar.

And when something is playing, the centre should say what. That is the other thing worth a glance, and it has nowhere to appear at the moment.

waybar 0.15 here links libplayerctl, so the mpris module is available rather than needing a custom script. btop, playerctl, pavucontrol and nmtui are all installed and declared already, so this should add no packages.

Worth deciding while doing it: whether a click that opens a window should toggle it - clicking the clock twice ought to close the calendar rather than open a second one - and whether that wants one shared helper rather than a launcher per module.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every module in the bar does something relevant when clicked, and what each one does is written down rather than only discoverable by clicking
- [ ] #2 The focused window's title is gone from the bar
- [ ] #3 The date and time occupy the centre, and clicking them shows a calendar
- [ ] #4 When a player is playing, what it is playing appears in the bar, and the playback can be controlled from there
- [ ] #5 Clicking a module that opens a window twice does not leave two windows open
- [ ] #6 Any window opened this way is floating and sized to its contents rather than tiling and shoving the workspace around
- [ ] #7 No new packages are needed, and checks/sway-commands.sh still accounts for every command the bar invokes
<!-- AC:END -->
