---
id: TASK-195
title: The manual claims three neovim split bindings that do not exist
status: Done
assignee:
  - '@claude'
created_date: '2026-08-29 11:53'
updated_date: '2026-08-29 11:53'
labels: []
dependencies: []
ordinal: 200000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The neovim keybinding table in docs/manual/04-applications.md lists `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` as "Move between splits". Only `<C-l>` is mapped. The other three were deliberately removed when keyd took those chords for Escape, Enter and Backspace (TASK-108, TASK-119, TASK-123) - init.lua says so at length and explains that `Ctrl+W` then k, j or h is now the only way to reach those splits, and chapter 3 of the manual already documents exactly that, per key, in its cost tables. Chapter 4 never caught up.

That table is introduced with "Verified by asking a headless neovim what is actually mapped rather than reading the config", which makes the row worse than an ordinary stale line: it asserts a provenance it does not have. A reader who trusts it presses Ctrl+K expecting a split and gets Escape.

checks/manual.sh does not look for this. It verifies helper scripts, compositor keybindings, chapter numbering and titles - nothing compares the neovim table against the mappings a headless neovim reports.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The neovim table in chapter 4 lists only the split binding that exists
- [x] #2 The three removed ones are accounted for where a reader meets the gap, rather than silently dropped
- [x] #3 The claim matches what a headless neovim reports as mapped
- [x] #4 checks/manual.sh passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Ask a headless neovim what is actually mapped, so the correction is measured rather than reasoned from init.lua.
2. Replace the four-key row in the neovim table in docs/manual/04-applications.md with the one binding that exists, named for what it does.
3. Account for the other three where the reader meets the gap - Ctrl+W then k, j or h - and point at chapter 3, which already carries the per-key cost tables rather than restating them here.
4. Run checks/manual.sh.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Measured rather than reasoned. A headless neovim reports exactly three Ctrl mappings in normal mode:

    n <C-Q>    Quit neovim
    n <C-S>    Write the file
    n <C-L>    Split right

so <C-h>, <C-j> and <C-k> were never there. The table now names <C-l> alone, and describes it as "Move to the split on the right" rather than "Move between splits" - the old wording was half the reason the row read as four keys doing one job.

The three absences are accounted for in a paragraph under the table: they are Escape, Enter and Backspace below the compositor, so a mapping for them here could never fire, and Ctrl+W then k, j or h is the only route to those splits. It points at chapter 3 rather than restating the cost tables that already live there, which is the rule that chapter works under.

checks/manual.sh: 8 passed, 0 failed. tools/manual.sh renders 10 chapters, 236 KiB.

The check gap is real and is NOT closed here: checks/manual.sh verifies helper scripts, compositor keybindings, chapter numbering and titles, and nothing compares the neovim table against what a headless neovim reports. This drift would not have been caught by it, and the same table could drift again the next time a mapping moves.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The neovim table in chapter 4 listed `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` as split movement when only `<C-l>` has been mapped since keyd took the other three chords for Escape, Enter and Backspace. It now names `<C-l>` alone, and a paragraph under the table says why the other three are absent and that `Ctrl+W` then k, j or h is the only way to those splits, pointing at chapter 3 rather than repeating its cost tables.

Verified by asking a headless neovim what is mapped - <C-Q>, <C-S>, <C-L> and nothing else - which is the provenance that table already claimed for itself. checks/manual.sh 8 passed / 0 failed; the manual renders at 10 chapters, 236 KiB.

Left open deliberately: checks/manual.sh has no pass that compares the neovim table against a live headless neovim, so this class of drift is still uncaught.
<!-- SECTION:FINAL_SUMMARY:END -->
