---
id: TASK-171
title: Ctrl+S writes the file in neovim
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-24 21:40'
updated_date: '2026-08-24 21:42'
labels: []
dependencies: []
ordinal: 178000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Saving means typing :w. Ctrl+S is what every other editor uses for it and reaches nvim intact - keyd does not rewrite s, foot does not bind it, and nvim turns off the terminal flow control that would otherwise swallow it as XOFF.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Ctrl+S writes the buffer from normal mode
- [ ] #2 Ctrl+S writes the buffer from insert mode without leaving insert mode
- [ ] #3 An unmodified buffer is not rewritten
- [ ] #4 The binding appears in shortcuts --mode nvim and in the manual, like every other chosen mapping
- [ ] #5 Verified by sending a real 0x13 down a pty and reading the file off disk
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. vim.keymap.set({'n','i'}, '<C-s>', '<cmd>update<CR>') - update, not write, and <cmd> so insert mode is not left.
2. Add the row to the manual's neovim table.
3. Verify by sending a real 0x13 down a pty against the rendered config: normal mode, insert mode, still-in-insert afterwards, and an unmodified buffer left alone (compare mtime).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Ctrl+S is XOFF, so the question was whether it arrives at all. It does: nvim puts the terminal in raw mode and disables flow control, keyd's [control] layer rewrites j/k/h/l/semicolon and not s, and foot binds only Ctrl+Shift+*. <C-s> was unmapped in the live instance before this.

Driven with a real 0x13 down a pty against the rendered config:
- unmodified buffer rewritten: False (mtime unchanged - this is why it is update rather than write)
- after Ctrl+S in normal mode: 'before\nchanged\n'
- after Ctrl+S in insert mode: 'before\nchangedmore\n'
- still in insert afterwards: True
<!-- SECTION:NOTES:END -->
