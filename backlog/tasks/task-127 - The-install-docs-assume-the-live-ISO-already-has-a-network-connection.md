---
id: TASK-127
title: The install docs assume the live ISO already has a network connection
status: Done
assignee:
  - '@vincemaina'
created_date: '2026-08-22 19:17'
updated_date: '2026-08-22 19:20'
labels: []
dependencies: []
ordinal: 131000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
README.md and docs/manual/09-installing.md tell the user the live ISO needs a network connection and that 'a wired connection normally works without any setup', but say nothing about wifi. install.sh, 01-disk.sh and 02-base.sh never touch networking - pacstrap in 02-base.sh just assumes internet is already reachable. On a laptop with no Ethernet port, there is no path to a network before pacstrap runs unless the person already knows to run iwctl unprompted. Found while auditing the repo for laptop-install risk ahead of the first non-desktop install.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The pre-install checklist in docs/manual/09-installing.md (and README.md if it repeats the checklist) tells the reader how to bring up wifi on the Arch live ISO before running install.sh, e.g. via iwctl
- [x] #2 checks/manual.sh still passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a wifi bullet/step to docs/manual/09-installing.md's 'What you need first' checklist: iwctl station wlan0 connect <SSID> (or iwctl device list if the interface isn't wlan0), before the existing ping check.
2. Update README.md's '2. Connect to the internet' step the same way, since it duplicates the same checklist for GitHub readers.
3. Run checks/manual.sh to confirm nothing broke.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added a wifi bullet to docs/manual/09-installing.md's 'What you need first' list plus a short iwctl example block after the list (a fenced code block nested inside a list item fails the manual's restricted markdown dialect - 'unmatched backtick' - so it had to sit outside the list, same pattern as the existing git-clone block). Mirrored in README.md's '2. Connect to the internet' step. Verified with checks/manual.sh (8/8, was previously failing to build until the nesting was fixed) and by grepping the rendered docs/manual/build/manual.html for the new text.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
docs/manual/09-installing.md and README.md's pre-install checklists now tell the reader to connect wifi with iwctl before running install.sh, since nothing in install.sh/01-disk.sh/02-base.sh sets up networking and a laptop with no Ethernet port previously had no documented path to a connection before pacstrap. Verified with checks/manual.sh (8/8) and the rendered manual.
<!-- SECTION:FINAL_SUMMARY:END -->
