---
id: TASK-84
title: 'The language servers that are not packaged: html, css, json, emmet, sql'
status: To Do
assignee: []
created_date: '2026-08-21 14:22'
updated_date: '2026-08-21 14:51'
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
- [ ] #1 html, css, json and emmet language servers work in the editor, installed through npm from a list tracked in this repository
- [ ] #2 The list is reconciled the way packages/ is - a machine missing one installs it, rather than the list being documentation
- [ ] #3 Where the servers land is a known location, not scattered, and checks/session.sh notices when a declared one is missing
- [ ] #4 Mason is not used, and neither is the AUR - both were decided against, on TASK-73 and TASK-43 respectively
- [ ] #5 SQL's server is either included, pulling in go, or explicitly deferred - TASK-83 delivers the client half without it
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Unblocked. TASK-43 decided against AUR support, so this goes through npm
instead, and the dependency on that ticket is satisfied rather than pending.

npm is the right route for these specifically, not a workaround. The servers
missing from the official repositories - html, css and json in
vscode-langservers-extracted, and emmet - are npm packages, and the AUR
PKGBUILDs for them are wrappers around npm install. Going through npm removes a
layer rather than adding one, and avoids depending on packages the AUR barely
maintains: vscode-langservers-extracted has 4 votes and was last updated in May
2024.

nodejs (61M) and npm (9.6M) are both in extra and neither is currently declared,
so this ticket adds them to packages/dev.txt.

The design question this leaves is where the servers are installed and how the
list is reconciled. A global npm install puts them in /usr/lib/node_modules,
which needs root and is outside anything this repository tracks; a prefix under
the user's home keeps it user-level but needs PATH handling, which
xdg-terminal-exec has already shown is not free. Worth settling before writing
anything.

sqls is Go rather than npm, which is why SQL is the one that may still wait: it
needs the go toolchain at 215M, for one language server.
<!-- SECTION:NOTES:END -->
