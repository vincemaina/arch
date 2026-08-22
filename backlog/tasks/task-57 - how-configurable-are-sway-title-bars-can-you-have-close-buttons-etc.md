---
id: TASK-57
title: 'how configurable are sway title bars, can you have close buttons etc?'
status: Done
assignee: []
created_date: '2026-08-21 10:20'
updated_date: '2026-08-22 00:53'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 55000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
it might be nice to have minimise, close, buttons etc but for now this is just a question
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Answer: no. sway(5) documents title_format, title_align, titlebar_padding, titlebar_border_thickness, hide_edge_borders and font for titlebars - all text/layout controls. close_button, minimize, maximize and titlebar_buttons appear zero times in the man page, and no bindsym/for_window mechanism attaches a clickable control to the decoration. Confirmed visually: a foot window with border normal (sway's own SSD) on a throwaway headless output (created, screenshotted, unplugged, focus restored to Virtual-1 workspace 1) renders only a text title bar, no icons. The only door for buttons is border csd, which hands drawing to the client app (e.g. a GTK header bar) - not a sway config option, and moot here since this repo runs default_border pixel 3 (no titlebar at all). Recorded in .claude/skills/sway-capability-limits/SKILL.md under 'Title bars have no buttons'. No config change made: setup/dotfiles/dot_config/sway/config.d/30-appearance.conf.tmpl deliberately uses pixel borders (see its own comments) and the buttons feature does not exist to enable regardless. ./checks/session.sh: 80 passed, 0 failed after the skill edit.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Sway title bars are configurable for text only (format, alignment, padding, border thickness, font) - there is no close/minimise/maximise button support anywhere in sway, confirmed against sway(5) and empirically on a headless output. The only escape hatch is border csd, which delegates decoration drawing to the client app, not sway. No sway config change made since none is possible for buttons; documented the finding in the sway-capability-limits skill for future reuse.
<!-- SECTION:FINAL_SUMMARY:END -->
