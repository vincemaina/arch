---
id: TASK-116
title: fix line numbers in neovim
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 14:09'
updated_date: '2026-08-22 18:02'
labels: []
dependencies: []
priority: low
type: chore
ordinal: 122000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
currently line numbers appear to be reletive to the current line which i absolutely hate and find utterly useless. id like line numbers to just be actual line numbers. although i would also be curious to know the benefits of having your line numbers relative. why is that the default in neovim?
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. setup/dotfiles/dot_config/nvim/init.lua: drop o.relativenumber = true, keep o.number = true. Absolute numbers only.
2. Verify: chezmoi render to scratch and read the rendered init.lua.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
setup/dotfiles/dot_config/nvim/init.lua: o.relativenumber = true removed, o.number = true kept - plain absolute line numbers. Verified by rendering the template to a scratch dir and reading the output.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Neovim now shows absolute line numbers only; relativenumber is gone. Verified via a chezmoi scratch render.
<!-- SECTION:FINAL_SUMMARY:END -->
