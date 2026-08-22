---
id: TASK-117
title: add q alias to exit terminal
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 14:25'
updated_date: '2026-08-22 18:02'
labels: []
dependencies: []
ordinal: 123000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
q in the terminal should exit the terminal
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. setup/dotfiles/dot_zshrc: alias q=exit, alongside the other aliases.
2. Verify: chezmoi render to scratch and read the rendered .zshrc; after sync.sh, type q<Enter> in a real terminal and confirm it closes (foot has no confirmation, so this is destructive to test carelessly - trial with a throwaway terminal).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
setup/dotfiles/dot_zshrc: alias q='exit' added alongside the other aliases. Verified by rendering the template to a scratch dir and reading the output; live keypress trial still needs sync.sh on the running machine.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
q now exits the terminal via a zsh alias (alias q='exit'). Verified via a chezmoi scratch render; not yet trialled live since it needs sync.sh applied first.
<!-- SECTION:FINAL_SUMMARY:END -->
