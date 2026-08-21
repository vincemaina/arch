---
id: TASK-73
title: discuss neovim setup
status: Done
assignee: []
created_date: '2026-08-21 11:51'
updated_date: '2026-08-21 14:22'
labels: []
dependencies: []
priority: medium
type: spike
ordinal: 75000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
lets discuss the work I'll be doing in this tool e.g. coding (predominantly SQL, python, javascript, typescript, html, css, markdown)
then do some research into available configurations/features/plugins etc
then have a discussion about what we actually want to implement
from that we can create tickets for each piece of work
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Discussed, researched and broken into tickets.

THE WORK: SQL predominantly, then python, javascript, typescript, html, css and
markdown.

THREE FINDINGS THAT CHANGED THE SHAPE OF IT, all checked on this machine rather
than taken from documentation.

nvim 0.12 ships what most guides still tell you to install: vim.pack as a plugin
manager, vim.lsp.config, vim.lsp.completion, bundled treesitter and gc
commenting. A plugin list written a year ago is mostly redundant. Bare startup
is 15ms, which is the number any configuration spends from.

Half the languages named have no packaged language server. Available: pyright,
ruff, typescript-language-server, marksman, tailwindcss-language-server,
yaml-language-server, bash-language-server, lua-language-server, prettier,
stylua, shfmt. Missing: html, css, json (all in vscode-langservers-extracted),
emmet, and sqls. That collides with the rule that every package is declared -
and Mason, which is how most configurations solve it, installs binaries into
~/.local/share/nvim where the manifests cannot see them.

Neovim would be the only thing on screen ignoring the eight themes, and it is
the window open longest.

DECISIONS TAKEN:

  * Build from scratch on 0.12's built-ins rather than adopt LazyVim or
    kickstart, which fits a repository where everything is explained.
  * Install what pacman has; let the rest wait on TASK-43 rather than reach
    outside the manifests. Mason rejected.
  * SQL gets both a database client and, eventually, a language server - the
    client is the more useful half and needs neither Mason nor the AUR.

TICKETS: TASK-24 rescoped to the base config; TASK-81 the packaged language
servers; TASK-82 the colorscheme generated from themes.toml; TASK-83 running SQL
from the editor; TASK-84 the unpackaged servers.

One consequence worth flagging: TASK-43, filed as a low-priority curiosity about
whether this repository supports the AUR, now gates four of the six languages.
Raised to high.
<!-- SECTION:FINAL_SUMMARY:END -->
