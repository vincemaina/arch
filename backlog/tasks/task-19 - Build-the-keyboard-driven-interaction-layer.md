---
id: TASK-19
title: Build the keyboard-driven interaction layer
status: To Do
assignee: []
created_date: '2026-08-19 18:16'
updated_date: '2026-08-19 18:17'
labels:
  - desktop
  - feel
dependencies:
  - TASK-2
priority: medium
type: feature
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The goal is that nothing routine requires the mouse. Today the launcher is wofi, which is GTK-based and noticeably slower to appear than native alternatives such as fuzzel; there is no clipboard history despite wl-clipboard being installed; and network, audio and power actions are only reachable through tray icons and pavucontrol. Each of these is a point where the workflow silently falls back to pointing and clicking.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Launcher options are compared on actual time-to-first-frame, not impression, and the choice is recorded
- [ ] #2 Clipboard history is available and reachable from a single binding
- [ ] #3 Network, audio, power and session actions each have a keyboard-reachable path
- [ ] #4 A discoverable way to see the current keybindings exists in-session
- [ ] #5 A full working day of routine actions is possible without touching the pointer
<!-- AC:END -->
