---
id: TASK-156
title: bar-size does nothing from the rofi launcher
status: Done
assignee: []
created_date: '2026-08-23 22:12'
updated_date: '2026-08-23 22:14'
labels: []
dependencies: []
type: bug
ordinal: 166000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-155 shipped a bug: ~/.local/bin/bar-size's bare (no-argument) picker strips leading whitespace off rofi's returned selection before parsing it (result.stdout.strip()), then extracts the size name at a fixed field index (chosen.split(None, 2)[1]). The menu marks the current size with a leading '* ', so stripping only removes the padding on *unmarked* rows - it shifts their fields by one, so selecting anything other than the currently-active size extracts a word from the description instead of the size name, fails validation, and dies to stderr - which nothing shows when launched from rofi's Exec (Terminal=false). Direct invocation (bar-size medium) is unaffected since it never goes through the picker. Reported by the user: 'the terminal bar-size command works, however it doesn't do anything via the rofi launcher.'
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Selecting medium or large from the bar-size rofi picker actually switches to that size
- [x] #2 The fix does not reintroduce the marked/unmarked column-shift bug for any future menu entry
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause confirmed by simulating rofi's output for each menu row and running it through the old vs new parsing logic directly (no live rofi needed, since rofi launcher testing in this environment was unreliable due to concurrent interference). Old code: result.stdout.strip() then chosen.split(None, 2)[1] - correct only for the marked '* small ...' row, because stripping removes the unmarked rows' leading padding and shifts every field left by one, so selecting medium or large read 'about' (part of the description) as the wanted size, which fails validation and dies to stderr with nothing to show it. Fixed by giving the rofi menu its own unmarked list (menu_lines), matching how ~/.local/bin/theme's list_themes_labelled already avoids this - the '*' marker now appears only in --list output, never in what rofi is shown, so the first-whitespace-token split is always correct.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The rofi picker's answer was parsed by stripping leading whitespace then reading a fixed field index, which only lined up for the one row carrying the '*' current-size marker; selecting medium or large silently extracted the wrong word and failed validation with no visible error (Terminal=false). Fixed by giving the rofi menu an unmarked line format (menu_lines), separate from --list's marked one, and parsing the first whitespace-delimited token - verified by feeding each menu row's exact text through the old and new logic. checks/session.sh and checks/manual.sh pass (one unrelated pre-existing FAIL about a VM greeter session, from concurrent unrelated work on this machine).
<!-- SECTION:FINAL_SUMMARY:END -->
