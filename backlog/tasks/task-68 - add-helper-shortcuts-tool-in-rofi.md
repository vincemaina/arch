---
id: TASK-68
title: add helper + shortcuts tool in rofi
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 10:56'
updated_date: '2026-08-22 12:38'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 70000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
It would be cool if there was a tool in rofi that displayed all the configured shorts across sway and as many other installed applications as possible.

also a helper tool with a manual/guide for using this desktop build, as well as using sway more generally.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Closed. The shortcuts panel has been in use for most of this session: a curses window on $mod+? and from the launcher, tabbed by tool, following the focused window, collapsing repeated workspace bindings, showing real key names through the keyd swap, and searchable by both shortcut and description. It also grew a keyd section, so bindings that live below the compositor - the Caps Lock scroll layer - are listed rather than being discoverable only by accident.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
A shortcuts panel opened with $mod+? or from the launcher, showing sway, neovim, yazi and desktop bindings in tabs that follow whatever window is focused. Reads sway's own config and asks neovim directly rather than duplicating either, and reports keyd-level bindings that no config file mentions.
<!-- SECTION:FINAL_SUMMARY:END -->
