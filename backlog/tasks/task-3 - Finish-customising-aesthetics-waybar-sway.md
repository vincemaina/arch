---
id: TASK-3
title: Define the visual design of the desktop
status: To Do
assignee: []
created_date: '2026-08-19 15:28'
updated_date: '2026-08-19 18:17'
labels:
  - desktop
  - feel
dependencies:
  - TASK-17
priority: medium
type: enhancement
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The waybar stylesheet is already carefully done, but it is the only part of the desktop that has had visual attention, and it is styling modules that are never enabled while showing others by default. Nothing else has a defined look: borders are pixel 2 with default colours, there are no gaps, the wallpaper is the stock sway one, and the lock screen is a plain black fill. The aim is a deliberate and minimal look where everything on screen earns its place - which means deciding what to remove from the bar as much as what to style.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A single colour palette and font scale is defined once and referenced everywhere rather than repeated per component
- [ ] #2 Every module shown in the bar justifies its space; the rest are removed rather than left configured-but-hidden
- [ ] #3 Window borders, gaps and focus indication are chosen deliberately and are consistent between tiled and floating windows
- [ ] #4 The lock screen and any session prompts match the rest of the desktop
- [ ] #5 Changing the palette does not require editing more than one place
<!-- AC:END -->
