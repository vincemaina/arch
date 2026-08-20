---
id: TASK-3
title: Define the visual design of the desktop
status: Done
assignee:
  - '@claude'
created_date: '2026-08-19 15:28'
updated_date: '2026-08-20 13:02'
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

Two icon problems, same root cause. When the waybar config was rewritten the Nerd Font glyphs were lost, leaving empty strings in format-icons for the idle inhibitor, volume and battery - which look exactly like configured icons in the file and render as nothing. That is why the bar had fewer icons than before rather than more. Restored by writing every glyph from its codepoint and auditing the file: 14 distinct glyphs now present and verified.

The prompt had the same shape of problem for a different reason. It was built from rounded caps rather than powerline chevrons, and the separators lived inside each module, so they vanished with the module. The reference screenshots the user supplied show the standard preset structure, where separators sit in the top-level format and therefore render regardless: outside a git repo the segment collapses to a sliver of chevron instead of breaking the chain. Rebuilt that way, with a folder icon, the powerline branch glyph and a clock, all written by codepoint.

Added a check for empty icon strings, verified by reintroducing one.

Wallpaper chosen: deep violet, a generated gradient mesh committed to setup/dotfiles/dot_local/share/wallpapers/ so it is applied like any other dotfile rather than being a file the user has to remember to copy.

The first set of candidates was rejected as too subtle - three variations on near-black, when the point of a wallpaper on a deliberately plain desktop is to make it worth looking at. The replacements are built from overlapping soft colour fields with a domain warp so the shapes read as blobs rather than circles, rendered small and upscaled since a smooth gradient has no detail to lose, with noise at full size to prevent banding.

The path is an absolute one rendered by chezmoi rather than a bare tilde, since sway passes it through to swaybg and tilde expansion is not worth relying on there.

Added a check for it. swaybg fails quietly when its image is missing - the output is just left blank, which looks like a plain desktop rather than a fault - so the check verifies the configured file exists, swaybg is installed, and it is actually running.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Gave the desktop one design. A single palette in .chezmoidata/palette.toml drives sway appearance, the bar, foot, swaylock and the prompt through chezmoi templates, so a colour is changed in one place - demonstrated by swapping the whole palette from Gruvbox to neon at a cost of one file. Contrast is measured rather than eyeballed, which caught readouts at 4.45:1 and terminal comments at 2.77:1 before they shipped. The bar carries coloured pills so it can be scanned rather than read, after a first attempt at uniform grey proved austere rather than minimal; that reversal is recorded in DECISIONS.md rather than quietly rewritten. Wallpaper is a generated gradient committed to the dotfiles, chosen after a first set proved too subtle to be worth having.
<!-- SECTION:FINAL_SUMMARY:END -->
