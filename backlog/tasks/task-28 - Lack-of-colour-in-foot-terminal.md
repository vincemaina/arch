---
id: TASK-28
title: 'Foot has no colour scheme: its theme include points at a missing file'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-19 19:41'
updated_date: '2026-08-20 00:53'
labels:
  - desktop
  - feel
dependencies: []
priority: high
type: bug
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
foot.ini ends with include=/usr/share/foot/themes/tokyonight-night, but tokyonight is not among the themes foot ships. Its bundled set is catppuccin-*, gruvbox, dracula, nord, monokai-pro, modus-*, nordiq and similar. The include therefore resolves to nothing and foot falls back to its default colours, which is the monotone appearance reported.

Two further findings while diagnosing, which explain the wider "everything looks boring" rather than just the terminal:

The waybar stylesheet is Catppuccin Mocha - #89b4fa, #a6e3a1, #f38ba8, #f9e2af are that palette exactly - with two Nord colours mixed in, #d8dee9 and #bf616a. So the bar alone is two palettes, the terminal was reaching for a third, and nothing else on the desktop is themed at all.

The class of failure is familiar: a config referencing something that does not exist, failing silently. Nothing reported the missing include.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The terminal has a deliberate colour scheme that actually loads
- [x] #2 A check fails when any dotfile include or referenced path does not exist on the machine
- [ ] #3 The mixed palettes in the bar stylesheet are resolved rather than left as two
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Cause confirmed by checking what foot actually ships: its bundled themes are catppuccin-*, gruvbox, dracula, nord, monokai-pro, modus-*, nordiq and similar. tokyonight is not among them, so the include resolved to nothing and foot used its defaults.

Pointed the include at catppuccin-mocha, which foot does ship. Mocha rather than any other because the waybar stylesheet is already predominantly that palette, making it the cheapest way to get two components agreeing. TASK-3 will decide the palette for the whole desktop and may replace this with an include of our own file.

Added a Dotfile references section to checks/session.sh which resolves every absolute path a dotfile includes and fails when one is missing. Globs are handled separately, since sway include of /etc/sway/config.d/* matching nothing is legitimate and only its directory needs to exist.

Still outstanding: the mixed palettes in the bar stylesheet, which belongs with TASK-3 rather than being patched piecemeal here.
<!-- SECTION:NOTES:END -->
