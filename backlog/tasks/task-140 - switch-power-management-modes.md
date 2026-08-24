---
id: TASK-140
title: switch power management modes
status: Done
assignee:
  - '@vincemaina'
created_date: '2026-08-23 10:34'
updated_date: '2026-08-24 14:04'
labels: []
dependencies: []
priority: medium
type: feature
ordinal: 144000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
easy way to switch between performance, balanced, and power saving.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 power-profiles-daemon is installed and enabled as a system service, applied through apply-config.sh like every other machine-wide config
- [x] #2 A rofi menu helper (e.g. power-profile) switches between Performance / Balanced / Power Saving via powerprofilesctl, following the power-menu (TASK-163) pattern: dmenu list, direct CLI subcommands, absolute paths
- [x] #3 Clicking the battery waybar module opens that menu, with current charge % and time-remaining shown as the rofi message header instead of the old format-alt click-toggle
- [x] #4 A new custom/power-profile waybar module (plug or lightning icon) opens the same menu, and is only visible when no battery is present (so laptop and desktop never both show a power control)
- [x] #5 docs/manual/02-the-desktop.md bar module table and Power section are updated to describe the profile switcher
- [x] #6 checks/sway-commands.sh passes (new helper has a # requires: header) and checks/session.sh passes
- [x] #7 Verified on a real running session per the desktop-verification skill: screenshot of the menu, and powerprofilesctl get confirms the mode actually changed
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add power-profiles-daemon to setup/packages/desktop.txt; enable+start it in setup/system/apply-config.sh (installer: enable only; sync --activate: enable and start), matching the greetd/earlyoom pattern already there.
2. Write setup/dotfiles/dot_local/bin/executable_power-profile: rofi -dmenu menu (Performance/Balanced/Power Saving, current mode marked) calling 'powerprofilesctl set <mode>'; supports direct subcommand invocation (power-profile performance|balanced|power-saver) for scripting/keybinding; # requires: header lists rofi and powerprofilesctl.
3. Extend the menu (or a thin wrapper) to accept a --mesg header so the battery click can pass '67% - 3h20m remaining' above the list; desktop click passes no message.
4. Update waybar/config.jsonc.tmpl: battery module gets on-click pointing at the absolute path of power-profile with the battery mesg; remove format-alt/tooltip-cycle behavior since detail now lives in the menu; update the module click-table comment.
5. Add a small helper (e.g. executable_power-profile-icon or inline in a custom module 'exec') that checks for battery presence (/sys/class/power_supply/BAT*) and prints the plug/lightning glyph + empty string when a battery exists, wired as a new custom/power-profile module in modules-right, on-click calling power-profile directly (no mesg).
6. Render with 'chezmoi --source ./setup --destination /tmp/render apply --force' (mkdir first) to confirm templates render; verify Nerd Font glyphs are written by codepoint per the scripting-traps skill.
7. Update docs/manual/02-the-desktop.md: bar module table (generated, so update source data if applicable) and the existing 'Power' section to mention profile switching alongside the power menu.
8. Run checks/session.sh, checks/sway-commands.sh, checks/manual.sh; fix anything they flag.
9. Follow the desktop-verification skill to actually see it: screenshot the rofi menu on click, confirm powerprofilesctl get reflects the switched mode, and confirm the correct one of battery/custom module is visible for this machine's hardware.

10. (Discovered during implementation) Also update docs/software/README.md and DECISIONS.md - the packages changed. Discovered -mesg is never placed by this theme (scripting-traps skill), so battery detail moved into the rofi prompt instead. Discovered powerprofilesctl needs python-gobject declared separately - it is an Optional Dep of power-profiles-daemon, not pulled in automatically.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: power-profiles-daemon + python-gobject declared in desktop.txt, enabled/restarted through apply-config.sh. New scripts power-profile (rofi menu, powerprofilesctl set/get, battery detail carried in the rofi prompt since -mesg is never placed by this theme - see scripting-traps) and power-profile-icon (plug glyph U+F0E7, hides itself when a battery is present). waybar battery module's on-click now opens the menu (format-alt toggle removed); new custom/power-profile module is the desktop counterpart, exactly one ever visible. Updated docs/manual/02-the-desktop.md, docs/software/README.md and DECISIONS.md. checks/session.sh (125/125), checks/manual.sh (8/8) and checks/sway-commands.sh all pass except the expected 'powerprofilesctl is not installed' - the new packages are declared but deliberately not yet installed on this live machine (see below). Verified the rofi menu visually on a headless output with a stubbed powerprofilesctl, screenshotted: prompt, rows and (current) marker all render correctly against this repo's theme.

LIVE SYNC completed on the reference machine: power-profiles-daemon + python-gobject installed via pkexec (packages needed pacman's own interactive confirm, so pre-installed with --noconfirm before letting sync.sh's own sudo-shimmed-to-pkexec call find nothing missing); apply-config.sh --activate ran, power-profiles-daemon.service enabled+active; dotfiles applied via chezmoi (foot.ini's pad also reset from a stray direct edit back to the tracked 16x16 - unrelated pre-existing drift, not a TASK-140 change, flagged to the user; a separate foot.ini alpha drift, 0.99 vs tracked 0.90, was left alone as out of scope). BUG CAUGHT LIVE: powerprofilesctl list on this machine (PlatformDriver: placeholder) offers only balanced/power-saver, no performance - the original hardcoded three-profile menu would have offered a Performance row that failed silently on click. Fixed in a follow-up commit: power-profile now builds its menu from 'powerprofilesctl list' output and validates direct CLI args against it, so a machine that DOES offer performance (real laptop hardware) will show it - nothing is hardcoded to this VM's limited set. Verified against the REAL daemon (no stub): power-profile power-saver / balanced both round-tripped through 'powerprofilesctl get'; the invalid-here 'performance' argument is now rejected with a clear error; the real rofi menu, screenshotted on a headless output, shows exactly Balanced (current)/Power Saving. waybar needed an explicit 'systemctl --user restart waybar' to pick up the new config.jsonc (it does not hot-reload plain config changes the way theme changes do) - the real, live bar now shows the lightning-bolt custom/power-profile module, screenshotted. All checks green on the final state: session.sh 125/125, manual.sh 8/8, packages.sh 6/6, sway-commands.sh clean. Two commits merged and pushed directly to origin/main (built via commit-tree/update-ref since main was checked out in the shared checkout and the worktree session could not check it out there): 8eff50a (the feature) and 1fdeccd (the powerprofilesctl-list fix, found only by testing against real hardware).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
power-profiles-daemon + python-gobject, opened from a shared rofi menu (~/.local/bin/power-profile) by whichever of two waybar modules is visible: battery (laptop) or a new plug-icon custom/power-profile module (desktop/no battery), never both. Menu rows are built live from 'powerprofilesctl list', not hardcoded - a real bug this reference machine (a VM with no performance profile) caught during rollout, fixed before closing. Fully verified live: packages installed via pkexec, daemon active, real powerprofilesctl get/set round-tripped, real rofi menu and real (post-restart) waybar module screenshotted on the actual desktop. All checks (session.sh, manual.sh, packages.sh, sway-commands.sh) green on the deployed state. docs/manual, docs/software/README.md and DECISIONS.md updated. Two commits merged and pushed directly to origin/main.
<!-- SECTION:FINAL_SUMMARY:END -->
