---
id: TASK-128
title: The install docs never mention Secure Boot
status: Done
assignee:
  - '@vincemaina'
created_date: '2026-08-22 19:17'
updated_date: '2026-08-22 19:20'
labels: []
dependencies: []
ordinal: 132000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
03-system.sh runs a bare 'bootctl install', which writes an unsigned systemd-boot binary. DECISIONS.md and the manual document the UEFI requirement but never mention Secure Boot. Most laptop OEMs (especially anything that shipped with Windows) ship Secure Boot on by default, unlike a typical QEMU/OVMF VM where it is commonly off. The installer completes without error in that state, but the freshly-installed machine can then fail to boot - 'no bootable device' - until Secure Boot is disabled in firmware, with nothing in the repo telling the reader this needs checking beforehand. Found while auditing the repo for laptop-install risk ahead of the first non-desktop install.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The pre-install checklist in docs/manual/09-installing.md tells the reader to disable Secure Boot in firmware before installing, or documents why it is not needed
- [x] #2 checks/manual.sh still passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a Secure Boot note to docs/manual/09-installing.md's 'What you need first' checklist, next to the existing UEFI bullet: disable Secure Boot in firmware before installing, since 03-system.sh's bootctl install writes an unsigned boot binary.
2. Update README.md's UEFI line ('This setup assumes a UEFI system.') the same way.
3. Run checks/manual.sh to confirm nothing broke.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added a Secure Boot note to docs/manual/09-installing.md's UEFI bullet and to README.md's UEFI line, both naming 03-system.sh's bootctl install as the reason an unsigned boot binary needs Secure Boot off. Verified with checks/manual.sh (8/8) and by grepping the rendered docs/manual/build/manual.html for the new text.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
docs/manual/09-installing.md and README.md's pre-install checklists now tell the reader to disable Secure Boot in firmware before installing, since 03-system.sh's bootctl install writes an unsigned boot binary that a Secure-Boot-on machine will refuse to boot afterward. Verified with checks/manual.sh (8/8) and the rendered manual.
<!-- SECTION:FINAL_SUMMARY:END -->
