---
id: TASK-18
title: 'Tune keyboard, pointer and cursor for responsiveness'
status: To Do
assignee: []
created_date: '2026-08-19 18:16'
updated_date: '2026-08-19 18:17'
labels:
  - desktop
  - feel
dependencies:
  - TASK-17
references:
  - 'https://man.archlinux.org/man/sway-input.5'
priority: medium
type: enhancement
ordinal: 17000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
No input tuning exists at all. The sway config sets only xkb_layout gb; repeat delay and rate are left at defaults, which feel sluggish when navigating by keyboard, and the touchpad block is still commented-out upstream example text. No cursor theme or size is set either, which is why cursors change appearance between native Wayland and XWayland windows. These are small settings with a disproportionate effect on how immediate the system feels.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Key repeat delay and rate are set deliberately and recorded, not left at defaults
- [ ] #2 Touchpad behaviour - tap, natural scroll, disable-while-typing - is configured for laptop machines
- [ ] #3 A cursor theme and size are set and applied consistently across native Wayland, XWayland and GTK applications
- [ ] #4 Settings are verified against the live session rather than assumed to have applied
<!-- AC:END -->
