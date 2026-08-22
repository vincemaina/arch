---
id: TASK-97
title: focus timer
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-22 00:47'
updated_date: '2026-08-22 12:47'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 99000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
it would be great if i could lauch a focus timer/session tool via rofi that helps me manage my time and ensures that i take breaks. it could be a pomodoro type thing, that shows a time in the waybar, and then a popup overlay appears that either be postponed for another few minutes, or you leave it and take the break it's recommended for you.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Durations in a config file, like the stations - not constants in a script.
2. One always-awake loop, which is the waybar module itself, streaming rather than polled: it is already the thing that has to notice the second a phase ends.
3. A CLI for start/stop/postpone, reached from rofi and from clicking the bar.
4. At the end of a work period: pause every player, then a rofi overlay offering the break or a postponement.
5. Resume only the players it paused, so it never starts something the user had stopped.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
VERIFIED END TO END on the running machine, not from the files:

- The bar module emits correct JSON each second - glyph, countdown, tooltip, phase class - and was screenshotted in the bar showing the hourglass and 24:58 in the accent colour.
- A work period ending paused a playing station (Playing -> Paused) and recorded which player it paused.
- The break prompt appeared as a rofi overlay offering the break, a postponement, or stopping.
- A break ending resumed that player and moved back to work.
- A player the USER had already paused was not recorded, so it is not started for them later - the PAUSED list came back empty, which is the case that separates 'restore what I interrupted' from 'play everything MPRIS knows about'.

TWO BUGS OF MINE, both the glyph trap in new clothes and both caught by testing rather than reading:

The glyphs went in as pasted characters, which CLAUDE.md forbids - od showed the raw UTF-8 bytes sitting in the file. Converted to bash escapes, and the file is now asserted pure ASCII.

Then the escapes were written as $'\u{f252}', the form other languages use. bash's $'...' takes \uXXXX with BARE hex digits, so that produces the literal text \u{f252} and would have rendered in the bar as exactly that. And a middle dot written as \u{b7} inside a DOUBLE-quoted string is not an escape at all - six literal characters on hover. Both forms were tested before choosing.

A third, in tools/shortcuts.sh and unrelated to this ticket, was found by checking TASK-74's criterion: its note about the scroll layer was guarded on the exact string 'capslock = layer(scroll)', which stopped matching when the binding changed, so the note silently vanished from the report.

Reopened: it had been marked Done in a backlog tidy-up while still unimplemented, and is being built now.

A later session started rebuilding this without checking git first, and overwrote the committed script and config with a near-identical reimplementation before noticing commit 7631277 already existed. Reverted with git checkout; nothing was lost.

Re-verified end to end at that point rather than assumed: the bar shows a counting-down timer, and forcing the work period to end while a stream was playing moved the player from Playing to Paused with the phase becoming break_pending - which is the pause-on-break behaviour the follow-up request asked about, already present.

Worth recording because the near-miss is the interesting part: the reimplementation arrived at the same design independently - one always-awake loop in the bar module rather than a second daemon, and resuming only the players it had itself paused - which is reassuring about the design and says nothing good about checking the repository first.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
A pomodoro timer with the countdown in the bar, a rofi overlay when a break is due offering to take it or postpone, and audio paused for the break. Durations live in a config file rather than as constants. The bar module is a continuous script rather than a polled one - one process for the session instead of 86,400 a day - and because it is already awake at the second a phase ends it also drives the transitions, so there is no separate timer daemon. It resumes only the players it paused, so a break never starts something the user had stopped. Verified by driving a real work-to-break transition against a playing station.
<!-- SECTION:FINAL_SUMMARY:END -->
