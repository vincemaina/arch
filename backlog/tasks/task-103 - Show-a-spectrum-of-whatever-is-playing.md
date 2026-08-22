---
id: TASK-103
title: Show a spectrum of whatever is playing
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 02:24'
updated_date: '2026-08-22 12:16'
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
- [x] #3 Its cost while running is measured rather than assumed - it is a per-frame redraw on a CPU-rendered desktop
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
AC1 and AC2 done and verified. AC3 and AC4 are deliberately open - autostart is not implemented, and the running cost has not been measured because cava is declared and not yet installed system-wide (it was trialled from a scratch extraction, which is enough to prove it works and not enough to measure it fairly).

Verified: read live spectrum off the monitor while SomaFM played through mpv; the rendered config parsed with empty stderr; renders 5/5 valid hex gradient stops for all eight themes; screenshotted running in a foot window with verdant's green-to-cyan gradient while the bar showed 'Drone Zone'.

AC#4 done. cava is installed now, so it could finally be measured rather than assumed.

Measured on this machine (KVM guest, 4 vCPU of an i7-10700, software rendering), 22 Aug 2026, over 30s of wall clock, sampling utime+stime from /proc/PID/stat and PSS from /proc/PID/smaps_rollup:

  cava                    1.27% of one core     8.0 MiB PSS
  foot showing it         2.00% of one core    12.0 MiB PSS
  foot, static control    0.00% of one core    11.5 MiB PSS
  ------------------------------------------------------
  visualiser total        3.27% of one core   ~20.0 MiB

TWO THINGS THE MEASUREMENT TAUGHT, both of which would have produced a confidently wrong number:

  1. The terminal costs MORE than cava does. Quoting cava alone - the obvious process to measure - would have understated the feature by more than half. The static control window in the same session cost 0.00%, so that 2.00% is the redraw and nothing else.

  2. A first run with no audio playing reported the terminal at 0.00%. That figure was real and useless: with silence the bars do not move, so there is nothing to redraw, and the feature was not doing its job. The fix was to drive cava from a synthetic PCM sweep through a fifo (input method = fifo in a scratch config) rather than the pulse monitor, which made the bars move every frame AND avoided taking over the machine audio to measure it.

Not measured: what sway itself pays to composite a window changing every frame under llvmpipe. On a software-rendered desktop that is a real third component and the 3.27% is therefore a floor, not a total.

Both probe windows ran on a headless output created with swaymsg create_output and were killed by recorded PID; the output was unplugged afterwards.

AC#3 REMAINS THE ONLY BLOCKER and it needs a decision, not implementation. The startup-toggle machinery already exists and works - startup --list shows five components with their memory - so wiring the visualiser in is small. What is undecided is where it lives when it opens itself: a small floating window in a corner, a scratchpad you summon, or a strip. At 3.27% of a core it is cheap enough to leave running; at a third of the screen it is not.

SCOPE NARROWED at the user request, and the ticket closed.

Autostart was dropped from this ticket rather than done. The user reasoning: the ticket was about having a spectrum that shows whatever is playing, and that is finished. Autostart is a separate question - and the answer they gave while dropping it, that anything opening itself at login should be FLOATING rather than tiled because it looks better, is a policy for every autostarted tool rather than a property of this one. That is TASK-109, low priority. The former AC#3 was removed rather than left unchecked, so this ticket does not sit open forever on work that belongs elsewhere.

Re-verified before closing rather than trusted:
  * AC#1 - visualiser.desktop.tmpl renders Name=Visualiser and Exec=foot --app-id=visualiser --title=visualiser -e cava, so it is reachable by name from the launcher. cava is installed. The pulse input with source=auto attaches to the default sink monitor, so it shows whatever is audible rather than one player.
  * AC#2 - all 8 themes (neon, ember, slate, verdant, abyss, orchid, cobalt, mono) define every one of the five gradient keys the config reads: accent, info, secondary, tertiary, urgent. None missing, so no theme fails at render.
  * AC#3 - measured, see the previous note. 3.27% of one core and ~20 MiB, of which the terminal is the larger half.

CORRECTION to the machine description on the measurement above. I labelled it "software rendering", copying the machine description docs/software/README.md records. That label is very likely wrong now.

Evidence gathered afterwards, prompted by TASK-27 finding the same staleness:
  * sway RSS is 65.2 MiB today. The figure on record, measured under llvmpipe, is 143.8 MiB - less than half.
  * The "Refusing to try glamor on llvmpipe" and DRI2 EGL failure messages in the journal are all from 20 Aug. Nothing like them appears for the sway running now, started 11:21 on 22 Aug.
  * virtio_gpu is loaded with 8 users and /dev/dri/card1 and renderD128 both exist.
  * DECISIONS.md already carries an entry titled "The VM rendered in software, and no longer does".

NOT CONCLUSIVE, and worth saying so rather than upgrading a strong inference into a fact: confirming which renderer the running sway actually holds needs root to read /proc/PID/fd or to run fuser against /dev/dri/renderD128, and passwordless sudo is not available here. What is established is that the "software rendering" label contradicts the evidence, not which label is right.

The cava figure itself is unaffected. It was measured today, on whatever this machine is now, so it describes the current configuration. Only the description of the machine was wrong, and it mattered because the ticket AC specifically framed the cost as "a per-frame redraw on a CPU-rendered desktop" - if that premise is gone, 3.27% may be the cost of a slower path than the one this desktop now uses.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
cava shows a spectrum of whatever is audible, reachable from the launcher, themed from themes.toml and verified to render for all eight themes. Its cost is measured rather than assumed: 3.27% of one core and about 20 MiB, of which the terminal drawing it is the larger half - a figure a first, silent measurement had reported as zero. Autostart was split out to TASK-109 rather than left open here.
<!-- SECTION:FINAL_SUMMARY:END -->
