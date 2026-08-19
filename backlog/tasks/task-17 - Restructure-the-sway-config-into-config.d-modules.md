---
id: TASK-17
title: Restructure the sway config into config.d modules
status: To Do
assignee: []
created_date: '2026-08-19 18:16'
labels:
  - desktop
  - maintainability
dependencies: []
priority: high
type: chore
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
setup/dotfiles/dot_config/sway/config is a 256-line copy of the upstream default with edits scattered through it and appended at the bottom, still carrying stock commentary telling you to copy the file into place. This works against the repository philosophy of small, separately reviewable pieces, makes every future change a noisy diff, and makes it hard to tell our decisions apart from upstream defaults. Splitting it into focused includes is the enabler for the input, keybinding, startup and theming work that follows.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The main config only sets variables and includes config.d fragments
- [ ] #2 Fragments are split by concern - at least input, output, keybindings, window rules, startup and appearance
- [ ] #3 Upstream boilerplate comments that do not describe our own choices are removed
- [ ] #4 The restructure is behaviour-preserving and verified against a running session
- [ ] #5 Adding a new binding or window rule touches exactly one fragment
<!-- AC:END -->
