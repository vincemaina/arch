---
id: TASK-22
title: Set up the shell and terminal experience
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-19 18:16'
updated_date: '2026-08-20 01:42'
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
- [x] #1 Shell configuration is tracked in the repository and applied by the normal dotfile mechanism
- [x] #2 The prompt shows working directory, git state and the previous exit status
- [x] #3 History is large, deduplicated and shared sensibly across concurrent terminals
- [x] #4 Installed tools are wired into the shell rather than merely present
- [ ] #5 Shell startup stays fast enough that opening a terminal feels instant, measured not assumed
- [x] #6 The choice of shell is recorded in DECISIONS.md, including whether to stay on bash
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
zsh chosen over fish and bash with the user, after explaining where Oh My Zsh and Powerlevel10k fit. Both rejected: Oh My Zsh is a self-updating git clone rather than a package, costs startup time, and would be a framework managing three source lines; Powerlevel10k is AUR-only here and in maintenance mode by its author own description. starship instead - official package, one config file, templated from the palette, and cross-shell so a later change of shell keeps the prompt.

Implemented: history at 50k shared and deduplicated with a leading space keeping a command out of it; completion with a cached dump, case-insensitive matching and descriptions; autosuggestions and syntax highlighting sourced directly, highlighting last since it wraps the line editor; fzf on Ctrl+R and Ctrl+T backed by fd; zoxide; eza and bat aliased, both using ANSI colours so they follow the palette rather than holding a copy of it.

The plugin sources are deliberately unguarded by a file test. They come from declared packages, so a missing one should be loud rather than silently dropping a feature, and the dotfile reference check now resolves source paths as well as includes.

Two ordering problems found and fixed by testing rather than reasoning. The login shell was being set before the dotfiles were applied, which would hand over a shell whose rc did not exist yet; it now runs last and only when zsh -n on the zshrc passes. And sync.sh used $USER, which is not guaranteed to be set and aborted under set -u; it uses id -un now.

Setting the shell also cannot happen in 03-system.sh at useradd time, since zsh comes from the dev manifest installed in 04 - the same ordering trap that broke greetd.

Not verifiable in this container: the zshrc cannot be syntax-checked without zsh installed, and startup time cannot be measured. checks/session.sh does both on the machine.
<!-- SECTION:NOTES:END -->
