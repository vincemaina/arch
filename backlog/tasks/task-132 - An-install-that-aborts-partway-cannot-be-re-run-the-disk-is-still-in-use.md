---
id: TASK-132
title: 'An install that aborts partway cannot be re-run: the disk is still in use'
status: Done
assignee:
  - '@vincemaina'
created_date: '2026-08-22 23:10'
updated_date: '2026-08-22 23:14'
labels: []
dependencies: []
type: bug
ordinal: 136000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When `install.sh` aborts after `01-disk.sh` has run - a mistyped password in stage 3 is the easiest way to get there, but any failure in stages 2 to 5 does it - the target filesystems are left mounted under /mnt. `install.sh` only ever calls `umount -R /mnt` on the success path, at the very end.

Re-running the installer then fails at the disk stage. `01-disk.sh` goes straight from the ERASE prompt to `parted -s` and `mkfs`, and both refuse to touch a disk whose partitions are in use, with an error about the partitions being used. Read at that moment - right after typing ERASE, on the second attempt at a fresh install - it looks like something is wrong with the chosen device, rather than being the residue of the previous run. Rebooting the ISO clears it, but nothing says so.

This is the invisible-failure shape this repository keeps hitting: the message names the disk, and the disk is fine.

The fix belongs at the top of `01-disk.sh`, after the ERASE confirmation and before anything is written: tear down whatever the last run left mounted, then verify the disk really is free and say so clearly if it is not.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Re-running install.sh after an aborted run gets past the disk stage without a reboot
- [x] #2 Any teardown happens only after the ERASE confirmation, so nothing is unmounted on a run the operator aborts at the prompt
- [x] #3 If the target disk is still in use for a reason the script cannot clear, it fails with a message naming what is still mounted rather than passing a confusing error up from parted
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. After the ERASE confirmation in 01-disk.sh, umount -R /mnt if anything is mounted there.
2. Then verify nothing on the target disk is still mounted; if it is, fail naming what, rather than letting parted emit a confusing error.
3. Verify the detection logic against a scratch mount, without touching a real disk.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added a teardown-and-verify block to 01-disk.sh, placed after the ERASE confirmation and before parted: umount -R /mnt when anything is mounted there, then a findmnt check that fails with the offending mounts listed if the target disk is still in use.

The match is on the device name with a leading whitespace class against `findmnt -rno TARGET,SOURCE`, which covers both vda2 and nvme0n1p2 partition-naming forms and btrfs subvolume sources (which findmnt renders as /dev/vda2[/@]).

Verified with fake findmnt/umount on PATH so no real disk was touched: (1) clean ISO with the target free - guard passes; (2) the reported bug, target mounted at /mnt with btrfs subvolume rows - the guard unmounts and then passes, so the re-run proceeds with no reboot; (3) same under nvme naming - detected; (4) a different disk mounted while the target is free - no false positive; (5) target held by something outside /mnt (/media/rescue) - blocked with the mount named, instead of a confusing parted error. checks/wizard.sh 91/91, checks/session.sh 92/92, checks/manual.sh 8/8.

Could not run a real loopback reproduction: this session has no non-interactive sudo, and reproducing against a real disk was not appropriate. The causal chain is established from the code and matches the reported symptom exactly.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
01-disk.sh now clears what an aborted run left behind: after the ERASE confirmation and before anything is written, it unmounts /mnt if it is still mounted, then fails with the offending mounts named if the target disk is somehow still in use. Re-running install.sh after an abort now gets past the disk stage with no reboot. Verified with fake findmnt/umount across five mount-table scenarios covering vda and nvme naming, btrfs subvolume sources, a clean disk, an unrelated mounted disk, and a disk held outside /mnt.
<!-- SECTION:FINAL_SUMMARY:END -->
