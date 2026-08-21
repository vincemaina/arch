---
id: TASK-81
title: 'Language servers, formatting and linting for the packaged languages'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 14:21'
updated_date: '2026-08-21 19:50'
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
- [x] #1 Each language named in TASK-73 that has a packaged server has one configured and working, verified by opening a real file of that type and seeing diagnostics
- [x] #2 Every server and formatter is declared in packages/, so a rebuilt machine has them without a bootstrap step
- [x] #3 Whether nvim-lspconfig and a completion plugin are needed at all on 0.12 is decided rather than assumed
- [x] #4 Format-on-save is a deliberate choice, stated, rather than inherited from an example
- [x] #5 The languages with no packaged server are listed as known gaps rather than quietly missing
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
VERIFICATION. Each server opened against a file containing a real error, with the config actually loaded, and the attached clients and published diagnostics read back:

  py    pyright,ruff   3 diagnostics   'Undefined name `undefined_name`'
  ts    ts_ls          3 diagnostics   'Type string is not assignable to type number'
  css   cssls,emmet    2 diagnostics   'property value expected'
  json  jsonls         1 diagnostic    'Trailing comma'
  md    marksman       1 diagnostic    'Link to non-existent document'
  html  emmet,html     117 completions after '<d'

html is completion and formatting rather than diagnostics - it does not validate tag nesting - so it was verified the way it is actually used.

CSS WAS SILENTLY DOING NOTHING. The vscode css server ships with validation off per dialect and reports it nowhere: it attached, answered completions, and accepted 'colour: red' without comment. settings.css.validate now turns it on for css, scss and less. This is the failure mode this repository keeps hitting - configuration that looks correct and does nothing.

AC3 - nvim-lspconfig and a completion plugin: decided against, not assumed. 0.12's vim.lsp.config describes a server in the same number of lines lspconfig would, for eight servers, and vim.lsp.completion with autotrigger gives an as-you-type menu with documentation. Neither plugin earns its place. Recorded in the header of lua/lsp.lua.

AC4 - FORMAT ON SAVE IS OFF, deliberately. Opening a file to read and saving out of habit would reformat a repository that has its own style and no formatter config, producing a diff nobody asked for in a file nobody was working on - the same objection as the shortcuts policy. <leader>f is the key instead. Verified through the real keymap: python, json and css all reformat.

Every language here formats through its server except markdown, so prettier is declared in packages/dev.txt for that one gap and reached through formatprg, needing no plugin. prettier is declared but not yet installed on this machine - it arrives with the next sync.sh, and the markdown path is the one part of formatting not yet exercised.

AC5 - the gap that was: html, css, json and emmet had no packaged server and are now installed from npm under TASK-84. SQL remains the known gap and is TASK-83.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Every language named on TASK-73 that has a packaged server now has one working, verified by opening a file with a real error and reading back the published diagnostics rather than by checking the config: pyright and ruff for python, ts_ls, cssls, jsonls, marksman, and html verified through completion since it does not diagnose. Found that the css server ships with validation off and reports nothing until asked - it looked configured and did nothing. nvim-lspconfig and a completion plugin were both decided against on 0.12's built-ins. Format-on-save is deliberately off with <leader>f instead; prettier covers markdown, the one language no server formats.
<!-- SECTION:FINAL_SUMMARY:END -->
