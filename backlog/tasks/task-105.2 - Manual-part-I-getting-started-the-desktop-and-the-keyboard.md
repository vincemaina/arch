---
id: TASK-105.2
title: 'Manual part I: getting started, the desktop, and the keyboard'
status: Done
assignee: []
created_date: '2026-08-22 10:27'
updated_date: '2026-08-22 10:35'
labels: []
dependencies: []
parent_task_id: TASK-105
ordinal: 109000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The first three chapters. Getting started: what this machine is, what happens between power on and a usable session, and the first five minutes. The desktop: windows, workspaces, tiling and floating, the scratchpad, the bar and what each module does when clicked, notifications. The keyboard: the complete shortcut reference, the modes, the scroll layer that lives below the compositor in keyd, and the left Alt/Control swap.

The keyboard reference must be generated from the configuration by tools/shortcuts.sh rather than typed out, so it cannot drift.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A reader who has never used sway can move, resize, split, float and reach every workspace using only this text
- [x] #2 Every bar module is documented including what clicking it does
- [x] #3 The shortcut tables are generated at build time from the actual config, not hand-maintained
- [x] #4 The scroll layer and the modifier swap are documented, since no sway config mentions them
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Read README.md, DECISIONS.md, CLAUDE.md for voice and facts.
2. Read sway config (config + config.d/*), waybar config.jsonc.tmpl, keyd default.conf, mako config, workspace greeter, systemd user units.
3. Verify against the running system: systemctl --user status for session units, swaymsg -t get_binding_modes/get_version, keyd active + config match, tools/shortcuts.sh output.
4. Write docs/manual/01-getting-started.md: what the machine is, boot chain (systemd-boot -> greetd/ReGreet -> uwsm -> sway -> wayland-session@sway.target units), first five minutes.
5. Write docs/manual/02-the-desktop.md: sway tiling model, containers/splits, tabbed layout (stacking removed per DECISIONS.md), fullscreen, scratchpad, workspaces, every waybar module and its click action, notifications/mako/notification centre.
6. Write docs/manual/03-the-keyboard.md: prose only, {{shortcuts}} placeholder for the generated table, modifier convention, keyd left-Alt/Control swap, modes, mod+scroll resize, media keys, Caps Lock scroll layer, VM LED caveat.
7. Check markdown dialect compliance (no forbidden constructs) and internal relative links to DECISIONS.md/CLAUDE.md.
8. Record notes and verify acceptance criteria.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Wrote docs/manual/01-getting-started.md, 02-the-desktop.md, 03-the-keyboard.md. Verified against the running system: systemctl --user status for waybar/mako/swayidle/polkit-agent/autotiling/greeting units (all active), swaymsg -t get_binding_modes (default, resize), keyd active with the leftcontrol/leftalt swap present in /etc/keyd/default.conf, and tools/shortcuts.sh run directly to confirm the generated table's shape and the swap/scroll-layer notes it prints. 03-the-keyboard.md contains the literal {{shortcuts}} placeholder rather than a typed table. Did not touch 07/08/09 chapters already present in docs/manual/ from other subtasks.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Wrote docs/manual/01-getting-started.md, 02-the-desktop.md and 03-the-keyboard.md. AC1: chapter 2 covers move/focus, resize (mod+r mode and mod+scroll), split (autotiling direction, mod+t tabbed toggle), float (mod+shift+space, mod+drag), and reaching every workspace (mod+1..0, prev/next_on_output, back_and_forth) in plain prose. AC2: chapter 2's table covers all 13 waybar modules from config.jsonc.tmpl (workspaces, mode, scratchpad, notifications, focus-timer, clock, mpris, idle_inhibitor, network, cpu, memory, pulseaudio, battery) with what each shows and what clicking does. AC3: chapter 3 contains the literal {{shortcuts}} placeholder, no hand-typed tables. AC4: chapter 3 has dedicated sections for the keyd left-Alt/Control swap and the Caps Lock scroll layer, both flagged as invisible to sway config and to tools/shortcuts.sh's own table. Verified against the running system rather than the files: systemctl --user status on all six wayland-session@sway.target units (active), swaymsg -t get_binding_modes ([default, resize]), keyd active with the swap present in /etc/keyd/default.conf, and tools/shortcuts.sh run directly. Markdown checked against the allowed dialect (headings, tables, lists, code, links; no images/HTML/footnotes/task-lists) and banned words (simply/just/easily/seamlessly) grepped out.
<!-- SECTION:FINAL_SUMMARY:END -->
