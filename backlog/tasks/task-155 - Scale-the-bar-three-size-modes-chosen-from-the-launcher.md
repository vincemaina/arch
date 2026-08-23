---
id: TASK-155
title: 'Scale the bar: three size modes, chosen from the launcher'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 19:13'
updated_date: '2026-08-23 19:28'
labels: []
dependencies: []
ordinal: 165000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Waybar's height and font are fixed (font.bar = 13px in .chezmoidata/fonts.toml, plus fixed CSS padding/margins in waybar/style.css.tmpl). The user wants to be able to make the bar noticeably bigger - a machine-local size mode with three steps, the current look as the smallest, and the largest roughly 1.5-2x that, switchable from rofi the same way theme/wallpaper/glow already are (see [[theme]] and TASK-144.2's fonts.toml machine-local pattern). All three consumers of font.bar (waybar CSS) and the CSS padding/margin values that give the bar its height need to scale together, or the bar looks bigger without the modules resizing to match, or vice versa.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A machine-local setting picks one of three bar sizes; the smallest reproduces today's bar exactly
- [x] #2 The largest size is roughly 1.5-2x the current bar's height and font size
- [x] #3 The size can be chosen from a rofi menu, following the pattern of theme/wallpaper/glow (a new bin/bar-size or equivalent switcher)
- [x] #4 Changing it survives ./sync.sh and leaves no diff in git, same as theme/wallpaper/glow
- [x] #5 A machine that has never set it still renders correctly, including in the installer chroot which has no chezmoi config
- [x] #6 checks/session.sh and checks/manual.sh still pass, and docs/manual/ documents the switcher
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add setup/dotfiles/.chezmoidata/barsize.toml: tracked default barSize="small" plus a barsizes table (small/medium/large), each with a description and a single scale float (1.0 / 1.4 / 1.8) - same tracked-default/machine-override shape as theme.
2. In waybar/style.css.tmpl and config.jsonc.tmpl, look up $scale := (index .barsizes .barSize).scale and multiply it through: font.bar, the outer box padding, pill padding/margin/radius, the workspace button size/margin, #mode's padding/margin, and config.jsonc's module spacing - via named $vars computed once at the top of each file (round (mulf N.0 $scale) 0), mirroring how $glow is computed today. Leave the 1px hairline border, the glow text-shadow blur radii and the hover box-shadow alone (subtle/cosmetic, out of scope). scale=1.0 for small must render byte-identical to today.
3. New setup/dotfiles/dot_local/bin/executable_bar-size (python, using ~/.local/lib/desktop_config.py exactly as glow/wallpaper do): bar-size / bar-size <name> / --list / --current, a rofi picker with descriptions when run bare, writing data.barSize and calling desktop_config.apply().
4. New setup/dotfiles/dot_local/share/applications/bar-size.desktop.tmpl (absolute Exec, reachable from $mod+space via rofi drun, same pattern as theme/glow/wallpaper.desktop.tmpl).
5. Add a '# barSize: {{ .barSize }}' line to run_onchange_after_reload-theme.sh.tmpl's load-bearing comment block so a size change re-triggers the existing waybar restart.
6. checks/session.sh: extend the reload-script grep (~line 520) to also require '.barSize' (bump the count threshold); add a short validation section confirming the selected barSize is one of barsizes' keys, mirroring the existing theme-validity check.
7. Document in docs/manual/05-making-it-yours.md (a 'Bar size' section beside Themes/Glow) and touch 07-how-it-is-put-together.md if it enumerates the reload triggers by name.
8. Verify: render all three sizes to a scratch destination with --exclude=scripts (small byte-identical to the pre-change render, medium/large show the scaled numbers); run checks/session.sh and checks/manual.sh; screenshot the bar at each size per the desktop-verification skill.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Chose a single scale multiplier per size (1.0/1.4/1.8) computed once at the top of each template, rather than a table of independently-tuned pixels per size - font.bar, box/pill padding, pill margin/radius, workspace dot size/margin, module spacing and #mode's geometry all derive from it, so nothing can drift out of proportion. Left the 1px hairline, glow blur radii and hover box-shadow un-scaled (cosmetic, out of scope).

Found and fixed a real bug while verifying: my first cut of the config.jsonc.tmpl edit used {{- ... -}} trim markers on both new template-only lines, which ate the newline before the JSON opening brace and merged it onto the preceding comment line (// the bar ever was.{) - which would have commented out the brace and broken every waybar render. Caught by actually reading the rendered output rather than trusting the template, exactly the failure mode CLAUDE.md names. Fixed by dropping the trailing trim on the last directive.

Verified per desktop-verification skill, without disturbing the running desktop:
- Rendered small/medium/large to scratch destinations (--exclude=scripts): small is byte-identical to the pre-change file (font-size 13px, padding 0 10px, pill 0 7px/4px/14px, workspace 22px/3px, spacing 4 - all unchanged); medium comes out 18px/1.4x geometry; large comes out 23px font and 40px workspace dots (~1.77-1.82x), within the 1.5-2x asked for.
- Screenshotted small and large on a throwaway headless output (swaymsg create_output, unplugged afterward, focus restored) - large is visibly and proportionally bigger (bar height 51px vs 29px for the same content); small placed next to the real live bar matches it exactly.
- Ran the actual switcher end-to-end against the real machine (ARCH_SETUP_SOURCE pointed at this worktree): bar-size --list/--current/--help all correct; bar-size medium visibly resized the real live bar (screenshotted); bar-size small reverted it, confirmed by screenshot and by chezmoi status printing nothing (no drift, no diff) both from the worktree's chezmoi source and in git status on the tracked repo.
- Rendered with --config pointed at a nonexistent file (no chezmoi.toml at all, i.e. the installer chroot) - still renders at small (13px, spacing 4), confirming a machine that has never chosen still works.
- checks/session.sh: new 'Bar size (TASK-155)' section passes, reload-script section updated to require 5 embedded triggers and passes; full run has 0 FAIL. checks/manual.sh: 8/8 pass, manual builds. checks/sway-commands.sh: all referenced commands accounted for.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added a machine-local bar-size setting with three named sizes (small/medium/large, scale 1.0/1.4/1.8), following the exact tracked-default/machine-override pattern theme/wallpaper/glow already use. One scale factor drives waybar's font, padding, margins, pill radius, workspace dots and module spacing together via named template variables in style.css.tmpl and config.jsonc.tmpl, backed by setup/dotfiles/.chezmoidata/barsize.toml. A new ~/.local/bin/bar-size (python, reusing ~/.local/lib/desktop_config.py exactly as glow/wallpaper do) offers a rofi picker plus --list/--current/direct-name, reachable from $mod+space via bar-size.desktop.tmpl. The reload script and checks/session.sh were extended to know about barSize alongside theme/wallpaper/glow, and docs/manual/05-making-it-yours.md documents it as its own section.

Verified: small renders byte-identical to the pre-change bar (scratch render, diffed field by field); medium/large scale proportionally (font 13->18->23px, ~1.4x/1.77x); a real live bar-size medium then bar-size small round-trip was screenshotted and left chezmoi status clean; a render with no chezmoi config at all (--config pointed at a missing file, simulating the installer chroot) still renders at small. checks/session.sh (0 fail, including a new Bar size section), checks/manual.sh (8/8) and checks/sway-commands.sh all pass. Caught and fixed a template-whitespace bug during verification that would have broken every waybar render (a trimmed newline merged the JSON opening brace into a // comment) - found by reading the rendered file rather than trusting the template.
<!-- SECTION:FINAL_SUMMARY:END -->
