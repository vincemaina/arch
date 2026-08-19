---
id: TASK-11
title: 'Start the desktop session reproducibly (waybar, notifications, idle)'
status: To Do
assignee: []
created_date: '2026-08-19 18:15'
updated_date: '2026-08-19 18:41'
labels:
  - foundation
  - session
dependencies:
  - TASK-17
references:
  - 'https://wiki.archlinux.org/title/Universal_Wayland_Session_Manager'
priority: high
type: bug
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Waybar is never launched by anything in the repository. The only exec line in the sway config is swayidle at line 36, the bar block is commented out at lines 229-241, and no exec waybar exists anywhere under setup/. Confirmed with the user: on the reference VM Waybar is started by hand after logging in, so the committed configuration does not reproduce the desktop that is actually in use, and a fresh install comes up with no bar at all.

Rather than patching in an exec line, decide how the session should be supervised: plain exec entries, sway-systemd, or uwsm, which wraps a compositor in systemd units and provides a real graphical-session.target that waybar, mako and swayidle can order against, with restart-on-failure and clean shutdown. The same mechanism should own every session component, so this is the last time a piece of the desktop is started by hand.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A fresh install reaches a complete desktop - bar, notifications and idle handling - with no manual startup step
- [ ] #2 A crashed bar or notification daemon is restarted automatically rather than leaving the session degraded
- [ ] #3 Session components are declared in one obvious place under setup/
- [ ] #4 DECISIONS.md records the comparison between plain exec, sway-systemd and uwsm, and why the chosen option won
<!-- AC:END -->
