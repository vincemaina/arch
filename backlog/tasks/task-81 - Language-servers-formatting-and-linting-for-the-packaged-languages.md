---
id: TASK-81
title: 'Language servers, formatting and linting for the packaged languages'
status: To Do
assignee: []
created_date: '2026-08-21 14:21'
labels:
  - dev
  - dotfiles
dependencies:
  - TASK-24
ordinal: 83000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The half of the editor's language support that can be installed from the official repositories today, and therefore declared in packages/ like everything else.

Available now, with sizes checked:

  pyright 18M and ruff 27M          python: types, and lint plus format in one tool
  typescript-language-server 2.2M   javascript and typescript
  marksman 21M                      markdown
  tailwindcss-language-server 5.2M  if tailwind is in use
  yaml-language-server 15M          yaml
  bash-language-server 13M          shell
  lua-language-server 19M           this configuration itself
  prettier 8.2M, stylua 7.1M, shfmt 3M   formatting

Deliberately NOT in scope: html, css, json, emmet and sql. None is in the official repositories, and the decision on TASK-73 was to install what is packaged and let the rest wait on TASK-43 rather than reach outside the manifests. They are a separate ticket that depends on that decision.

nvim 0.12 has vim.lsp.config and vim.lsp.completion built in, so nvim-lspconfig and a completion engine are not automatically required - whether they earn their place is part of this work rather than assumed.

Formatting and linting want deciding together, since ruff does both for python and prettier does neither for it. Whether formatting happens on save is a preference worth making explicitly rather than inheriting from an example config.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each language named in TASK-73 that has a packaged server has one configured and working, verified by opening a real file of that type and seeing diagnostics
- [ ] #2 Every server and formatter is declared in packages/, so a rebuilt machine has them without a bootstrap step
- [ ] #3 Whether nvim-lspconfig and a completion plugin are needed at all on 0.12 is decided rather than assumed
- [ ] #4 Format-on-save is a deliberate choice, stated, rather than inherited from an example
- [ ] #5 The languages with no packaged server are listed as known gaps rather than quietly missing
<!-- AC:END -->
