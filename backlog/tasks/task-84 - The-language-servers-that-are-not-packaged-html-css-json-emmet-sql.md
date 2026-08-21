---
id: TASK-84
title: 'The language servers that are not packaged: html, css, json, emmet, sql'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 14:22'
updated_date: '2026-08-21 19:54'
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
- [x] #1 html, css, json and emmet language servers work in the editor, installed through npm from a list tracked in this repository
- [x] #2 The list is reconciled the way packages/ is - a machine missing one installs it, rather than the list being documentation
- [x] #3 Where the servers land is a known location, not scattered, and checks/session.sh notices when a declared one is missing
- [x] #4 Mason is not used, and neither is the AUR - both were decided against, on TASK-73 and TASK-43 respectively
- [x] #5 SQL's server is either included, pulling in go, or explicitly deferred - TASK-83 delivers the client half without it
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

VERIFICATION.

AC1 - all four work, tested with the config actually loaded (which took two goes: `nvim -l` does NOT read init.lua, so an LSP test through it reports zero clients and reads as a broken editor):
  html   attaches, 117 tag completions after '<d'
  cssls  attaches, 2 diagnostics on a malformed rule
  jsonls attaches, 1 diagnostic - 'Trailing comma'
  emmet  attaches, expands 'ul>li.item*3'

CSS WAS ATTACHING AND DOING NOTHING. The vscode css server ships with validation off, per dialect, and announces it nowhere - it answered completions while accepting 'colour: red' in silence. settings.css.validate now turns it on for css, scss and less. Exactly the failure this repository keeps meeting.

AC2 - reconciled, not documentation: run_onchange_after_install-language-servers.sh runs npm ci from a tracked package-lock.json, and re-runs when either package.json or the lockfile changes. Both are hashed - the first version hashed only package.json, so pinning a version would silently not have installed.

AC3 - checks/session.sh now notices. Two new checks: one asks lua/lsp.lua which servers it expected versus which it could actually find, so adding a server to that module is enough and the check cannot drift from it; the other looks for the four npm executables in ~/.local/lib/language-servers/node_modules/.bin. PROVEN BY HIDING ONE: renaming emmet-language-server made both fail by name, and restoring it made both pass. A check that has never failed proves nothing.

AC4 - no Mason and no AUR. The servers come from npm into a prefix under $HOME, named by absolute path in lua/lsp.lua because ~/.local/bin is not on the session PATH.

AC5 - SQL IS DEFERRED, deliberately. sqls is written in Go, is not in the official repositories, and neither route to it is acceptable here: the AUR was ruled out on TASK-43, and 'go install' means adding a whole toolchain outside the manifests to build one binary - the same objection that ruled out Mason. TASK-83 delivers the useful half, running SQL from the editor, and does not need a language server to do it. Revisit if sqls is ever packaged.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
html, css, json and emmet installed from npm into ~/.local/lib/language-servers via npm ci from a tracked lockfile, reconciled by a run_onchange script that hashes both package.json and the lockfile. All four verified working by opening real files and reading back diagnostics and completions - which exposed that the css server ships with validation off and had been attaching silently. checks/session.sh now fails when a declared server is missing, proven by hiding one. SQL deferred: sqls is Go, unpackaged, and reaching it means either the AUR or a toolchain outside the manifests; TASK-83 covers the useful half without it.
<!-- SECTION:FINAL_SUMMARY:END -->
