---
id: TASK-3
title: Define the visual design of the desktop
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-19 15:28'
updated_date: '2026-08-20 01:01'
labels:
  - desktop
  - feel
dependencies:
  - TASK-17
priority: medium
type: enhancement
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The waybar stylesheet is already carefully done, but it is the only part of the desktop that has had visual attention, and it is styling modules that are never enabled while showing others by default. Nothing else has a defined look: borders are pixel 2 with default colours, there are no gaps, the wallpaper is the stock sway one, and the lock screen is a plain black fill. The aim is a deliberate and minimal look where everything on screen earns its place - which means deciding what to remove from the bar as much as what to style.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A single colour palette and font scale is defined once and referenced everywhere rather than repeated per component
- [x] #2 Every module shown in the bar justifies its space; the rest are removed rather than left configured-but-hidden
- [x] #3 Window borders, gaps and focus indication are chosen deliberately and are consistent between tiled and floating windows
- [ ] #4 The lock screen and any session prompts match the rest of the desktop
- [x] #5 Changing the palette does not require editing more than one place
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Palette chosen with the user: Gruvbox Dark, minimal but alive - thin borders with the accent only on focus, small gaps, quiet bar.

Defined once in dotfiles/.chezmoidata/palette.toml, with sway appearance, waybar CSS, foot and swaylock all chezmoi templates reading from it. Roles rather than colour names, so a future palette swap does not leave a variable called orange holding something blue. The sixteen ANSI colours live in the same file rather than pointing foot at its bundled gruvbox theme, since a palette split across two files is one that gets half-updated.

Waybar trimmed hard: cpu, memory, temperature, idle inhibitor, scratchpad and backlight removed from display, and a large amount of configuration for modules that were never displayed at all - mpd, media widget, power menu, keyboard state, second battery, power profiles - deleted rather than left commented. Stylesheet went from 278 lines to 92, config from roughly 200 to 61.

Wallpaper replaced with a flat background colour. On a tiling desktop the background is almost never visible, so an image is mostly something you configure and then never see.

Verified by installing chezmoi in the container and rendering the whole source tree into a scratch destination: all 26 files render, no template syntax survives, symlinks resolve. That caught a real bug - swaylock takes its colours without a leading # unlike every other consumer, and the top-level color key had kept its #.
<!-- SECTION:NOTES:END -->
