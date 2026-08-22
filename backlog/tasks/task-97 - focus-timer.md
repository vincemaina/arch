---
id: TASK-97
title: focus timer
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-22 00:47'
updated_date: '2026-08-22 02:50'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 99000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
it would be great if i could lauch a focus timer/session tool via rofi that helps me manage my time and ensures that i take breaks. it could be a pomodoro type thing, that shows a time in the waybar, and then a popup overlay appears that either be postponed for another few minutes, or you leave it and take the break it's recommended for you.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Durations in a config file, like the stations - not constants in a script.
2. One always-awake loop, which is the waybar module itself, streaming rather than polled: it is already the thing that has to notice the second a phase ends.
3. A CLI for start/stop/postpone, reached from rofi and from clicking the bar.
4. At the end of a work period: pause every player, then a rofi overlay offering the break or a postponement.
5. Resume only the players it paused, so it never starts something the user had stopped.
<!-- SECTION:PLAN:END -->
