---
id: TASK-20
title: Make application look and feel consistent
status: To Do
assignee: []
created_date: '2026-08-19 18:16'
updated_date: '2026-08-19 18:17'
labels:
  - desktop
  - feel
dependencies:
  - TASK-17
priority: medium
type: enhancement
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Nothing configures how applications present themselves. No Wayland-related environment variables are set, so some toolkits fall back to XWayland and render blurry or oversized on scaled outputs and lose native input handling. No GTK or Qt theme, icon theme or font preference is configured either, so Thunar, pavucontrol and qutebrowser each pick their own defaults and the desktop looks assembled rather than designed. The bar is already carefully styled, which makes the inconsistency elsewhere more obvious.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Toolkits run natively on Wayland where they support it, verified per application rather than assumed
- [ ] #2 A single theme, icon set and font choice apply across GTK and Qt applications
- [ ] #3 Dark appearance is consistent - no application renders a light window against the dark desktop
- [ ] #4 Application-facing environment is set in one place that both the session and the dotfiles agree on
- [ ] #5 XWayland applications render at the correct scale
<!-- AC:END -->
