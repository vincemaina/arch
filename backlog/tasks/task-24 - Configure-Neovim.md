---
id: TASK-24
title: Configure Neovim
status: To Do
assignee: []
created_date: '2026-08-19 18:16'
labels:
  - dotfiles
  - dev
dependencies: []
priority: low
type: feature
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
dev.txt installs neovim but no configuration is tracked, so it starts as a bare editor with none of the tooling around it. Since it is intended as the main editor on this system, the configuration belongs in the repository like every other user-facing choice.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Neovim configuration is tracked in the repository and applied with the other dotfiles
- [ ] #2 A fresh install produces a working editor with no manual bootstrap step
- [ ] #3 Startup time stays fast enough for use as a quick-edit editor, measured not assumed
- [ ] #4 Any plugin management approach is reproducible with versions pinned
<!-- AC:END -->
