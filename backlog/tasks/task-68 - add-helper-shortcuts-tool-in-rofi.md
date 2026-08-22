---
id: TASK-68
title: add helper + shortcuts tool in rofi
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 10:56'
updated_date: '2026-08-22 02:52'
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

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
A shortcuts panel opening on the tab for whatever is focused, reading sway's bindings from its config, neovim's by asking a headless instance, and yazi's from its keymap. Collapses repeated workspace bindings, renders key names as the keyboard actually produces them including the keyd swap, searches description as well as chord, and follows focus changes live. Reached from the launcher and from $mod+slash.
<!-- SECTION:FINAL_SUMMARY:END -->
