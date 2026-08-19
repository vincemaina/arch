---
id: TASK-22
title: Set up the shell and terminal experience
status: To Do
assignee: []
created_date: '2026-08-19 18:16'
labels:
  - dotfiles
  - feel
dependencies: []
priority: medium
type: feature
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The user is created with /bin/bash and no shell dotfiles are tracked at all - setup/dotfiles contains only foot, sway and waybar. That means a stock prompt with no context, default tiny history with no deduplication, no completion beyond the basics, and none of the tools in dev.txt wired up: fzf, ripgrep and fd are installed but nothing binds them. This is the interface used more than any other on the system and it is currently the least considered part of it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Shell configuration is tracked in the repository and applied by the normal dotfile mechanism
- [ ] #2 The prompt shows working directory, git state and the previous exit status
- [ ] #3 History is large, deduplicated and shared sensibly across concurrent terminals
- [ ] #4 Installed tools are wired into the shell rather than merely present
- [ ] #5 Shell startup stays fast enough that opening a terminal feels instant, measured not assumed
- [ ] #6 The choice of shell is recorded in DECISIONS.md, including whether to stay on bash
<!-- AC:END -->
