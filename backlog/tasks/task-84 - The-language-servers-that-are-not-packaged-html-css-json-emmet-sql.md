---
id: TASK-84
title: 'The language servers that are not packaged: html, css, json, emmet, sql'
status: To Do
assignee: []
created_date: '2026-08-21 14:22'
labels:
  - dev
  - dotfiles
dependencies:
  - TASK-43
  - TASK-81
ordinal: 86000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Four of the languages named on TASK-73 have no language server in the official Arch repositories, and two of them - html and css - are ones you would notice immediately.

Missing, and what provides them elsewhere:

  vscode-langservers-extracted   html, css and json in one package. The standard answer, and an npm package.
  emmet-ls or emmet-language-server   the abbreviation expansion that makes writing html tolerable.
  sqls                           SQL completion and diagnostics. See TASK-83 for the client half, which does not need this.

The decision on TASK-73 was to install what is packaged and let these wait rather than reach outside the manifests, because every package on this machine is declared in packages/ and a rebuilt machine has to reproduce it. Mason - what most neovim configurations use - installs binaries into ~/.local/share/nvim where the manifests cannot see them, and was rejected for exactly that reason.

So this is blocked on TASK-43, which asks whether this repository supports the AUR at all. That ticket was filed as a low-priority curiosity and is now gating real work, which is worth knowing when it is picked up.

If the answer to TASK-43 is no, the fallback is a tracked list of npm packages installed to a known location - more machinery, but it keeps them declared. That is a decision for this ticket once TASK-43 is settled, not before.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 html, css, json and emmet work in the editor, or the decision not to have them is recorded with its reason
- [ ] #2 However they arrive, they are declared somewhere the repository can see, so a rebuilt machine reproduces them
- [ ] #3 Mason is not used, or the reason for reversing that decision is written down
- [ ] #4 The SQL server is included or explicitly deferred, given TASK-83 delivers the client half without it
<!-- AC:END -->
