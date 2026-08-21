---
id: TASK-24
title: Configure Neovim
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-19 18:16'
updated_date: '2026-08-21 14:30'
labels:
  - dotfiles
  - dev
dependencies: []
priority: medium
type: feature
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
dev.txt installs neovim but no configuration is tracked, so it starts as a bare editor with none of the tooling around it. Since it is intended as the main editor on this system, the configuration belongs in the repository like every other user-facing choice.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The configuration is tracked in the repository and applied with the other dotfiles, with no manual bootstrap on a fresh install
- [ ] #2 It is built from scratch on nvim 0.12's built-ins - vim.pack for plugins, vim.lsp.config, bundled treesitter - rather than on a distribution, and every plugin present has a stated reason
- [ ] #3 Plugin versions are pinned, so two machines syncing this repository get the same editor
- [ ] #4 Startup time is measured rather than assumed, against the 15ms bare baseline recorded in TASK-73
- [ ] #5 Nothing writes into the config directory at runtime that the repository does not know about
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Scope narrowed by TASK-73 to the base config only. Language servers, the
colorscheme and the SQL tooling are separate tickets that depend on this one.

The decision was to build from scratch rather than adopt LazyVim or kickstart,
and nvim 0.12 makes that much less work than it would have been: vim.pack,
vim.lsp.config, vim.lsp.completion, treesitter and gc commenting are all built
in now, so the plugin list a year-old guide would give is mostly redundant.
Confirmed on this machine rather than taken from release notes.

Bare startup measured at 15ms, best of five, with no configuration at all. That
is the number any config spends from.
<!-- SECTION:NOTES:END -->
