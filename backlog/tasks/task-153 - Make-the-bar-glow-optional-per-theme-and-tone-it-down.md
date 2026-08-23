---
id: TASK-153
title: 'Make the bar glow optional per theme, and tone it down'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 16:44'
updated_date: '2026-08-23 17:05'
labels: []
dependencies: []
ordinal: 163000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The waybar glow was tuned against the loud dark themes - neon in particular - and it does not suit every palette. On the light themes, paper especially, the halos read as smudge rather than light. Two changes: make the glow something that can be turned on and off, remembered per theme exactly as the wallpaper style already is; and reduce the blur radius everywhere it stays on, so the glow sits close to the glyph making it rather than spreading across the bar.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A `glow` command turns the bar glow on and off, and prints the current setting with `--current`
- [x] #2 The choice is remembered per theme, so returning to a theme restores the setting last used for it
- [x] #3 The choice is machine-local (chezmoi.toml, via desktop_config.py) and leaves no diff in the repository
- [x] #4 Every theme declares a tracked default, so a fresh install and the installer chroot both render without a config file
- [x] #5 With glow off, the bar renders with no text-shadow halos and no bottom-edge bloom, and remains legible in every theme
- [x] #6 With glow on, the blur radius is smaller than before so the halo stays local to the glyph
- [x] #7 Switching glow takes effect without a manual waybar restart, on the same path a theme switch uses
- [x] #8 checks/session.sh passes, and covers the new per-theme key
- [x] #9 The manual, DECISIONS.md and CLAUDE.md describe the setting
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. themes.toml: every theme declares `glow = "on"|"off"` as its tracked default - on for the eight dark themes it was tuned against, off for paper, daylight and sepia. Document it in the header beside `mode`.
2. New `~/.local/bin/glow` (dot_local/bin/executable_glow), modelled on `theme` and `wallpaper`: bare `glow` toggles, `glow on|off` sets, `--current`, `--list`, `-h`. Writes `data.glow.<theme>` through desktop_config.py - the one writer - and re-applies chezmoi.
3. waybar style.css.tmpl: resolve the setting once at the top with `dig "glow" .theme $palette.glow .`, and gate both the text-shadow halos and the bar bottom-edge inset bloom on it.
4. With glow on, drop the blur radii: 5px -> 3px, 6px -> 4px, 7px -> 5px, so the halo stays local to the glyph.
5. run_onchange_after_reload-theme.sh.tmpl: add the glow setting to the load-bearing header lines so changing it re-runs the reload and restarts waybar.
6. A launcher entry, glow.desktop.tmpl, matching wallpaper.desktop.tmpl.
7. checks/session.sh: the existing key-parity check covers the new key once every theme has it; add an explicit check that each value is on or off, mirroring the mode check.
8. Docs: manual chapter 5, DECISIONS.md, CLAUDE.md theming section, and re-run checks/manual.sh.
9. Verify: render to a scratch destination with --exclude=scripts for a dark and a light theme, run checks/session.sh and checks/sway-commands.sh, and screenshot the bar with glow on and off.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
VERIFICATION

Rendered, not read back. `chezmoi execute-template` / `apply --exclude=scripts` against scratch configs and destinations, for neon (dark) and paper (light), with and without a machine-local [data.glow] override:
- paper, no override: 0 text-shadow rules and no bottom-edge box-shadow.
- paper with glow forced on: 19 halo rules, the same count as neon.
- neon: radii render as 3/4/5px where they used to be 5/6/7.
- the reload script renders "# glow: off" vs "# glow: on", which is what makes run_onchange re-run it and restart waybar - the same mechanism a theme switch uses.

Looked at, on a throwaway output. `swaymsg create_output` at scale 2, a throwaway waybar pinned to it with -c/-s, grim, and the images read. Four captures: neon before and after (halo visibly tighter, still lit), paper before and after (the smudge under the readouts and the grey bloom under the bar are both gone; text is crisp). The output was unplugged and focus returned to the user workspace afterwards. The live bar was never used as the test surface - GTK CSS errors kill waybar outright.

The command, end to end. The real script run against a scratch XDG_CONFIG_HOME with only the sys.path line stubbed: --list, --current, bare toggle, `on`, `off`, repeating a set ("already off"), and a rejected value (exit 1). The write lands as a proper [data.glow] table, and re-rendering afterwards produced 0 halos.

Per-theme memory, directly. Set neon off, switched the config to ember (which read its own default, on), set ember off too, switched back: neon still off, ember independently off.

checks/session.sh 103 passed / 0 failed; checks/manual.sh 8/0; sway-commands and sway-bindings clean. The new glow check was exercised on all three branches by feeding the extracted check a crafted data blob: a bad spelling ("true") and a setting for a theme that does not exist both fail; a valid choice passes and says whether it is chosen or the default.

DECISIONS

The blur reduction is independent of the switch and was applied everywhere, including where the glow stays on: at 5-7px the halo reached past its glyph and neighbouring readouts bled together on a 34px bar.

Turning the glow off emits no rule at all rather than overriding with `text-shadow: none`, so there is nothing to keep in step when a module is added later.

desktop_config.py gained resolve_source/data/palette/apply and wallpaper now calls them instead of carrying its own copy. `glow` would have been a third copy of logic that this module exists because of - its docstring is the story of two copies of the writer disagreeing. wallpaper was re-tested (--list/--current/--path) after the move. ~/.local/bin/theme is bash and keeps its own; noted rather than changed.

Also corrected a stale comment in ~/.local/bin/theme claiming every theme must be dark because GTK reads GTK_THEME once - TASK-152 disproved that and three themes are light.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The bar glow is now a setting rather than a rule, remembered per theme, and smaller where it stays on.

Every theme in themes.toml declares a `glow` default - on for the eight dark themes it was tuned against, off for paper, daylight and sepia, where a halo on a white background reads as a smudge rather than light. `~/.local/bin/glow` overrides that default for one theme on one machine: bare `glow` flips it, `glow on|off` sets it, `--current` and `--list` report it, and a "Glow" launcher entry flips it in one click. The answer is stored under [data.glow] in chezmoi own config beside the wallpaper style, through desktop_config.py, so choosing leaves no diff and switching away and back restores it.

The waybar stylesheet resolves the setting once and gates both the readout haloes and the bar bottom-edge bloom on it, emitting no rule at all when a theme does not glow. Where it does, the radii dropped from 5/6/7px to 3/4/5px so the light stays where the text is. The reload script now names the glow among the lines that make it re-run, so a change restarts waybar on the same path a theme switch uses.

Verified by rendering neon and paper with and without an override, by screenshotting a throwaway waybar on a throwaway output before and after, by running the command end to end against a scratch config including a theme round-trip, and by checks/session.sh (103/0, including a new check exercised on all three of its branches) and checks/manual.sh (8/0).
<!-- SECTION:FINAL_SUMMARY:END -->
