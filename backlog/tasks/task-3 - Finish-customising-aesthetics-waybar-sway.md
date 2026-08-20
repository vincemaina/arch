---
id: TASK-3
title: Define the visual design of the desktop
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-19 15:28'
updated_date: '2026-08-20 11:32'
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
- [x] #4 The lock screen and any session prompts match the rest of the desktop
- [x] #5 Changing the palette does not require editing more than one place
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Palette chosen with the user: Gruvbox Dark, minimal but alive - thin borders with the accent only on focus, small gaps, quiet bar.

Defined once in dotfiles/.chezmoidata/palette.toml, with sway appearance, waybar CSS, foot and swaylock all chezmoi templates reading from it. Roles rather than colour names, so a future palette swap does not leave a variable called orange holding something blue. The sixteen ANSI colours live in the same file rather than pointing foot at its bundled gruvbox theme, since a palette split across two files is one that gets half-updated.

Waybar trimmed hard: cpu, memory, temperature, idle inhibitor, scratchpad and backlight removed from display, and a large amount of configuration for modules that were never displayed at all - mpd, media widget, power menu, keyboard state, second battery, power profiles - deleted rather than left commented. Stylesheet went from 278 lines to 92, config from roughly 200 to 61.

Wallpaper replaced with a flat background colour. On a tiling desktop the background is almost never visible, so an image is mostly something you configure and then never see.

Verified by installing chezmoi in the container and rendering the whole source tree into a scratch destination: all 26 files render, no template syntax survives, symlinks resolve. That caught a real bug - swaylock takes its colours without a leading # unlike every other consumer, and the top-level color key had kept its #.

Palette switched from Gruvbox to a neon-on-near-black scheme at the user request, wanting something more modern and futuristic. The switch cost one file, which is the templating design paying off immediately.

Contrast measured rather than eyeballed, which caught two real problems in the first draft. The muted grey behind the cpu and memory readouts measured 4.45:1, marginally below readable, and terminal bright_black measured 2.77:1 - the colour most schemes use for code comments. Both lightened above 4.5:1. Bright accents left saturated since they mark small areas rather than carrying text.

cpu and memory restored to the bar at the user request, styled muted so they can be glanced at without competing with the focus accent. Temperature, idle inhibitor, scratchpad and backlight stay removed.

Rounded window corners investigated and not pursued: sway does not support them and SwayFX, the fork that does, is AUR-only, which would mean teaching the repository to build AUR packages. The user chose to keep everything square rather than take that on.

Bar redesigned after the user said it looked uglier than what it replaced and that they missed the idle inhibitor button.

idle_inhibitor restored - it is the control for stopping the screen locking during something you are watching or a long build, which is exactly the kind of thing a bar is for.

The uniform-grey rule is reversed. Every module is now a coloured pill, with colour identifying the readout and state escalating it to warning or urgent. The reference setups the user collected under docs/themes are unanimous on per-module colour, most as filled pills, which is a strong enough signal to override a principle I had derived from first principles. DECISIONS.md records the reversal and why rather than quietly rewriting it.

Windows keep the stricter rule, since there the question genuinely is binary - which window has focus - rather than which of several readouts am I looking at.
<!-- SECTION:NOTES:END -->
