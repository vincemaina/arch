---
id: TASK-144.2
title: Make font size a machine-local value
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 11:40'
updated_date: '2026-08-23 11:45'
labels: []
dependencies: []
parent_task_id: TASK-144
type: feature
ordinal: 150000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The motivating case. foot.ini.tmpl hardcodes size=10 and waybar/style.css.tmpl hardcodes 13px; this machine wants 15 and loses it on every sync. Font size is a value rather than an override - it belongs in chezmoi.toml [data] alongside the theme, consumed by both templates, so the two move in step. ~/.local/lib/desktop_config.py is the only thing permitted to write chezmoi.toml.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Font size is read from machine-local data with a sensible tracked default
- [x] #2 foot and waybar both use it, so they cannot drift apart
- [x] #3 Changing it survives ./sync.sh
- [x] #4 A machine that has never set it still renders correctly, including in the installer chroot which has no chezmoi config at all
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Scope grew from 'font size' to 'the font', because the family was repeated in all six places the sizes were - five chances to change five of them and miss one. .chezmoidata/fonts.toml now holds family plus four sizes (terminal, desktop, menu, bar) and every surface reads them: foot, waybar CSS, sway titlebars, mako, and rofi's three.

Verified BEFORE editing that a partial override is safe, because CLAUDE.md records a nested-table merge having broken every apply once. A scratch source with [font] terminal=10, bar=13 and a config setting only terminal=15 rendered 'terminal=15 bar=13', so chezmoi merges per key rather than replacing the table. Had it replaced, setting one size would have silently dropped the others.

Rendered the whole tree to a scratch destination with --exclude=scripts first (scripts are NOT sandboxed by --destination): every font line came out byte-identical to the hardcoded values, so the defaults preserve existing behaviour exactly.

bar stays in pixels and is deliberately not derived from the point sizes - the conversion depends on output scale, so a formula would be a guess wearing the clothes of arithmetic.

This machine now records data.font.terminal = 15 and chezmoi status is clean, so sync no longer reverts it. Note desktop_config.py is a lib and is not executable: call it with python3, not directly.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Font family and sizes moved from six hardcoded sites into .chezmoidata/fonts.toml, read by foot, waybar, sway, mako and rofi. A machine overrides any key in ~/.config/chezmoi/chezmoi.toml via desktop_config.py and keeps the repository's defaults for the rest.

Verified: a partial override preserves sibling keys (measured in a scratch source, since a nested-table merge bug has bitten this repo before); a scratch render with --exclude=scripts produced byte-identical output to the previous hardcoded values; this machine's terminal=15 survives with chezmoi status clean. checks/manual.sh 8/0, checks/session.sh 92/0, manual builds at 10 chapters.
<!-- SECTION:FINAL_SUMMARY:END -->
