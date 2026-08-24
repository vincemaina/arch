---
id: TASK-170
title: >-
  Halve the neovim gutter: the space left of the text is mostly reserved for
  nothing
status: Done
assignee:
  - '@claude'
created_date: '2026-08-24 21:35'
updated_date: '2026-08-24 21:39'
labels: []
dependencies: []
ordinal: 177000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Six terminal columns sit between the window edge and the first character, and only three of them carry anything. signcolumn=yes reserves two cells whether or not a sign exists, and numberwidth=4 pads a two-digit line number out to four. Measured with wincol() on a live instance.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The gutter is three columns wide in a file of fewer than 100 lines, rather than six
- [x] #2 Nothing shifts sideways when a diagnostic appears, which is what the reserved column was for
- [x] #3 The line number is still visible on every line that has no sign
- [x] #4 Measured on a drawn frame, not read from the config
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. signcolumn = 'number' - signs draw over the line number, so no separate column is reserved and nothing shifts.
2. numberwidth = 2 - it is a minimum, and nvim widens it as the line count grows.
3. Rewrite the comment that justified signcolumn='yes', which would otherwise be a lie.
4. Measure with wincol() and on a drawn pty frame, with a diagnostic set, before and after.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Measured, not read: wincol() with the cursor on the first character says 6 columns before and 3 after. Drawn 20x40 pty frames agree - the cursor-position escape moves from column 7 to column 4.

signcolumn='yes' was two columns, not one, because a sign is two cells wide. numberwidth=4 was padding a two-digit file out to four; it is a minimum and nvim still widens it past 99 lines.

The promise the old comment made is kept: with a diagnostic set on line 3, the gutter stays at 3 columns in both configs, so nothing shifts. The trade is visible on the frame - line 3 draws 'E' where '3' was, and every line without a sign still shows its number.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The gutter is three terminal columns instead of six: signcolumn='number' draws signs over the line number rather than reserving two cells of its own, and numberwidth=2 stops a two-digit file being padded out to four. Verified with wincol() and on drawn pty frames, with a diagnostic set: 6 columns before, 3 after, no shift when the diagnostic arrives, numbers still shown on every line without a sign.
<!-- SECTION:FINAL_SUMMARY:END -->
