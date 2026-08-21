---
id: TASK-24
title: Configure Neovim
status: Done
assignee:
  - '@claude'
created_date: '2026-08-19 18:16'
updated_date: '2026-08-21 19:49'
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
- [x] #1 The configuration is tracked in the repository and applied with the other dotfiles, with no manual bootstrap on a fresh install
- [x] #2 It is built from scratch on nvim 0.12's built-ins - vim.pack for plugins, vim.lsp.config, bundled treesitter - rather than on a distribution, and every plugin present has a stated reason
- [x] #3 Plugin versions are pinned, so two machines syncing this repository get the same editor
- [x] #4 Startup time is measured rather than assumed, against the 15ms bare baseline recorded in TASK-73
- [x] #5 Nothing writes into the config directory at runtime that the repository does not know about
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

VERIFICATION.

AC1 - tracked and applied with no bootstrap: the config is setup/dotfiles/dot_config/nvim/, applied by chezmoi with every other dotfile. Nothing clones a plugin manager on first run because there is no plugin manager.

AC2 - built on 0.12's built-ins: vim.pack is present and unused, vim.lsp.config/vim.lsp.completion configure the servers, treesitter and gc commenting are the bundled ones. Confirmed on this machine: nvim reports 0 plugins loaded.

AC3 - versions pinned: satisfied in the strongest available way, by there being no plugins at all to drift. The one thing that is fetched rather than packaged - the npm language servers - is pinned by a tracked package-lock.json and installed with npm ci, which fails rather than resolving something newer.

AC4 - startup measured, not assumed: 10.85ms, best of five, against the 15ms bare baseline recorded on TASK-73. FASTER than bare, because the config deletes 62 default mappings and disables netrw and matchit, and that costs less than loading them. Opening a real python file costs 62ms, which is treesitter parsing plus spawning pyright and ruff, and is the number that matters in daily use.

AC5 - nothing writes into the config directory: state is ~/.local/state/nvim, data is ~/.local/share/nvim, and ~/.config/nvim holds no file newer than init.lua.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Neovim configured from scratch on 0.12's built-ins with zero plugins: vim.pack unused, vim.lsp.config for servers, bundled treesitter and gc. Startup measured at 10.85ms best-of-five against the 15ms bare baseline - faster than bare, because pruning defaults costs less than loading them. State and data stay outside the config directory, so nothing untracked appears there. Language servers, the colourscheme and SQL are TASK-81, TASK-82 and TASK-83.
<!-- SECTION:FINAL_SUMMARY:END -->
