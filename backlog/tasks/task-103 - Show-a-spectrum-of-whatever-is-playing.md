---
id: TASK-103
title: Show a spectrum of whatever is playing
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-22 02:24'
updated_date: '2026-08-22 02:24'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 105000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A terminal spectrum display that reacts to the audio actually coming out of the machine, sitting alongside the focus music from TASK-101.

Implemented with cava - 195 KiB from extra, so no TASK-43 question - and it needs no integration with any player at all. The pulse input with source = auto attaches to the default output's MONITOR, so it visualises whatever is audible: the radio, a video in the browser, a notification sound. mpv knows nothing about it and does not have to.

Themed from .chezmoidata/themes.toml like every other consumer, with the gradient running quiet-to-loud through the theme's own identity colours - accent, info, secondary, tertiary, urgent - rather than a fixed green-amber-red, so it looks like the desktop it is in rather than like cava. background and foreground are 'default' so foot's 0.90 alpha shows through, the same reasoning that gives the editor a transparent Normal.

Trialled before being declared, by fetching the package and its iniparser dependency to a scratch directory and running the binary: it read live spectrum data off the monitor while SomaFM was playing, the rendered config parsed with empty stderr, and it was screenshotted running in a foot window showing the verdant gradient.

WHAT IS NOT DONE, and is the reason this ticket exists rather than being folded into TASK-101: opening it automatically at login. It currently tiles like any other window, which is right for opening it deliberately and wrong for a thing that appears on every login and takes a third of the screen. Doing that properly means deciding where it lives - a small floating window in a corner, a scratchpad, or a strip - and it should go through TASK-77's startup toggles so it can be turned off, rather than being an unconditional exec.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The visualiser opens from the launcher and reacts to whatever is playing, not only to one player
- [x] #2 It follows the selected theme, and renders for all eight
- [ ] #3 If it autostarts, it does so through the startup toggles so it can be turned off, and it does not claim a third of the screen
- [ ] #4 Its cost while running is measured rather than assumed - it is a per-frame redraw on a CPU-rendered desktop
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
AC1 and AC2 done and verified. AC3 and AC4 are deliberately open - autostart is not implemented, and the running cost has not been measured because cava is declared and not yet installed system-wide (it was trialled from a scratch extraction, which is enough to prove it works and not enough to measure it fairly).

Verified: read live spectrum off the monitor while SomaFM played through mpv; the rendered config parsed with empty stderr; renders 5/5 valid hex gradient stops for all eight themes; screenshotted running in a foot window with verdant's green-to-cyan gradient while the bar showed 'Drone Zone'.
<!-- SECTION:NOTES:END -->
