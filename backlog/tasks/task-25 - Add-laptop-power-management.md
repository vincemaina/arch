---
id: TASK-25
title: Add laptop power management
status: To Do
assignee: []
created_date: '2026-08-19 18:16'
labels:
  - foundation
  - laptop
dependencies: []
priority: low
type: feature
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Nothing manages power. There is no battery handling, no lid behaviour, no CPU frequency policy and no power profile switching, even though the waybar stylesheet already contains styling for a power-profiles-daemon module that is never enabled. This has no effect on the reference VM but matters as soon as the setup runs on real portable hardware.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A power policy is applied automatically and differs on battery versus mains
- [ ] #2 Closing the lid does something deliberate and documented
- [ ] #3 Battery state is visible in the bar, with a warning before the machine is at risk
- [ ] #4 The chosen approach is compared against alternatives in DECISIONS.md
- [ ] #5 None of it is installed or enabled on non-laptop profiles
<!-- AC:END -->
