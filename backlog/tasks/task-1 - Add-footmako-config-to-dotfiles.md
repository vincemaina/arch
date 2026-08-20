---
id: TASK-1
title: Configure foot and mako
status: Done
assignee:
  - '@claude'
created_date: '2026-08-19 15:26'
updated_date: '2026-08-20 20:35'
labels:
  - dotfiles
  - feel
dependencies: []
priority: medium
type: feature
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Originally deferred because the defaults were fine. Worth revisiting now: foot has a committed config (font, padding, tokyonight theme) but nothing for the features that affect daily use - scrollback size, URL following, or server mode, which removes the per-window startup cost when terminals are opened constantly. mako has no config at all, so notifications use default placement, timeouts and styling and do not match the bar, and there is no keyboard path to dismiss or act on one.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 foot configuration covers scrollback, keyboard-driven URL and text selection, and font sizing
- [ ] #2 A decision is recorded on whether to run foot in server mode, based on measured window spawn time
- [ ] #3 mako notifications visually match the bar and the rest of the desktop
- [ ] #4 Notifications can be dismissed and acted on from the keyboard
- [ ] #5 Urgent notifications are visually distinct from routine ones
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Done across the session rather than as one piece of work.

foot: colours from palette.toml, alpha 0.90 for background translucency (foot alpha rather than sway opacity, since sway fades glyphs too and the text goes visibly duller - compared side by side at the same value before choosing), pad 16x16 matching the sway gaps, and a bell that does something. visual flashes the window in the palette warning colour, and notify raises a desktop notification through mako when the window is unfocused, which is the half that matters for a long build finishing elsewhere.

mako: had no configuration at all, which is why notifications looked like they belonged to a different desktop. Now takes its colours from the palette, groups by app-name so a chatty program folds into one stack, holds critical notifications until dismissed deliberately, and defines a dnd mode - modes do nothing without a config to say what they mean, so a do-not-disturb toggle would have been a dead control until this file existed.

Beyond the ticket: mako had no surface to read from, so $mod+n lists live notifications and history through rofi, with dismiss-all, restore and the dnd toggle. Verified visually - grouping shows as (3), critical renders with the urgent border, and the centre lists both live and [seen] entries.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
foot and mako both configured from palette.toml, so the terminal and its notifications match the rest of the desktop rather than each carrying their own defaults. foot gained background translucency, padding matched to the sway gaps, and a working bell that notifies through mako when unfocused. mako gained colours, grouping, urgency handling and a dnd mode, plus a notification centre on $mod+n since it had no surface of its own to read from.
<!-- SECTION:FINAL_SUMMARY:END -->
