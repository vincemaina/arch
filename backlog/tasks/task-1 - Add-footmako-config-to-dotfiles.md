---
id: TASK-1
title: Configure foot and mako
status: To Do
assignee: []
created_date: '2026-08-19 15:26'
updated_date: '2026-08-19 18:17'
labels:
  - dotfiles
  - feel
dependencies: []
priority: medium
type: feature
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Originally deferred because the defaults were fine. Worth revisiting now: foot has a committed config (font, padding, tokyonight theme) but nothing for the features that affect daily use - scrollback size, URL following, or server mode, which removes the per-window startup cost when terminals are opened constantly. mako has no config at all, so notifications use default placement, timeouts and styling and do not match the bar, and there is no keyboard path to dismiss or act on one.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 foot configuration covers scrollback, keyboard-driven URL and text selection, and font sizing
- [ ] #2 A decision is recorded on whether to run foot in server mode, based on measured window spawn time
- [ ] #3 mako notifications visually match the bar and the rest of the desktop
- [ ] #4 Notifications can be dismissed and acted on from the keyboard
- [ ] #5 Urgent notifications are visually distinct from routine ones
<!-- AC:END -->
