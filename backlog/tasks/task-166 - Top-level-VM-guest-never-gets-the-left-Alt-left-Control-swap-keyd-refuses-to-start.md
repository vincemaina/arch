---
id: TASK-166
title: >-
  Top-level VM guest never gets the left-Alt/left-Control swap: keyd refuses to
  start
status: Done
assignee:
  - '@claude'
created_date: '2026-08-24 11:50'
updated_date: '2026-08-24 12:08'
labels:
  - vm
  - desktop
dependencies:
  - TASK-160
  - TASK-141
ordinal: 173000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-160's fix disables keyd inside any machine systemd-detect-virt reports as a VM, via setup/system/keyd/keyd.service.d/override.conf's ConditionVirtualization=!vm. That condition was written for one specific case: a nested guest launched by this repo's own ~/.local/bin/vm tooling from a host that already runs keyd, where a second swap inside the guest would cancel the host's. ConditionVirtualization cannot distinguish that case from a machine that IS a top-level VM running this desktop as its only OS, with no host-side keyd upstream of it at all - and the override.conf comment says outright that the second case is not supported. On such a machine (confirmed via systemd-detect-virt -> kvm, keyd.service failed with 'start condition unmet'), the left-Alt/left-Control swap TASK-40 establishes never applies at all, silently: keyd is installed and enabled, systemctl reports it enabled, and the keyboard still behaves as if none of TASK-40 happened. Needs a real signal that distinguishes 'a nested guest under this repo's own vm tooling' from 'this machine is the only OS running here', so the override only suppresses keyd in the former.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A machine that IS a top-level VM (this desktop as its only OS, no host-side keyd) gets the left-Alt/left-Control swap applied, same as bare metal
- [ ] #2 A guest launched via ~/.local/bin/vm from a host already running keyd still has keyd suppressed inside the guest, preserving TASK-160's fix
- [x] #3 checks/session.sh correctly asserts keyd's expected state (running vs suppressed) for both scenarios, not just whether systemd-detect-virt reports vm
- [x] #4 docs/manual and DECISIONS.md describe the distinction and how it is detected
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Confirm mechanism: systemd's ConditionVirtualization only reports the hypervisor class (kvm/qemu/etc), so it structurally cannot distinguish 'this machine IS a top-level VM with no host-side keyd' from 'a nested guest launched by ~/.local/bin/vm from a host that already swapped the keys' - both report the same virtualization type. Replace the detection entirely with an explicit marker instead of trying to refine the virtualization check.
2. In setup/dotfiles/dot_local/bin/executable_vm's cmd_run(), add -smbios type=1,family=arch-repo-vm-guest to the qemu args (with a comment explaining why). This tags only guests launched by this repo's own vm tool; nothing else on the machine sets DMI product_family, and it is world-readable at /sys/class/dmi/id/product_family in the guest.
3. Replace ConditionVirtualization=!vm in setup/system/keyd/keyd.service.d/override.conf with an ExecCondition= shell one-liner that reads /sys/class/dmi/id/product_family and skips starting keyd only when it equals the marker string; keyd starts normally everywhere else, including a top-level VM. Update the file's comments to describe the new mechanism and retire the old rationale that conflated the two VM meanings.
4. Update checks/session.sh's TASK-40/TASK-160 section: stop branching on systemd-detect-virt --vm; branch on whether /sys/class/dmi/id/product_family equals the marker (i.e. whether this machine IS one of this repo's own nested guests) instead. Keep the two pass/fail shapes (guard present + keyd correctly inactive vs keyd present + running + grabbed a device) but gate them on the right signal, so a top-level VM now takes the bare-metal branch.
5. Update the override.conf comment, docs/manual/03-the-keyboard.md and docs/manual/09-installing.md (wherever TASK-160's guest-side note lives) and add a DECISIONS.md entry describing the SMBIOS-marker approach and why ConditionVirtualization alone could not do this.
6. Verify: keyd check on the edited default.conf/override.conf is unaffected (override.conf isn't parsed by keyd, only by systemd) - run systemd-analyze verify against a throwaway root with the new override to confirm ExecCondition parses; on this real machine (a top-level VM with no marker set), restart keyd and confirm it now starts and the swap works; run checks/session.sh and checks/manual.sh and fix any regressions. Booting an actual nested guest via vm run to prove the marker suppresses keyd there is the same kind of gap TASK-160 already left open (no qemu guest booted in that session either) - note it explicitly rather than assume.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented the marker-based fix: executable_vm tags guests it launches with -smbios type=1,family=arch-repo-vm-guest; keyd.service.d/override.conf replaces ConditionVirtualization=!vm with ExecCondition=/usr/bin/sh -c '[ "$(cat /sys/class/dmi/id/product_family 2>/dev/null)" != "arch-repo-vm-guest" ]'; checks/session.sh's TASK-40 section now branches on that same marker instead of systemd-detect-virt --vm. Updated apply-config.sh's CONFIG_FILES comment, docs/manual/04-applications.md, and DECISIONS.md's 'Keeping a VM guest's keyboard from double-swapping the host's remap' entry (rewrote the Why/Trade-off sections for the new mechanism).

Verified live on this machine, which is a top-level VM (systemd-detect-virt -> kvm) with no arch-repo-vm-guest marker set: before the fix, keyd.service failed to start (ConditionVirtualization=!vm unmet) and the left-Alt/left-Control swap did not apply. After running sync.sh, keyd.service is active (running), and the user confirmed the swap works again. checks/session.sh: 125 passed, 0 failed, 2 skipped (the TASK-40 section took the bare-metal branch: keyd running, enabled, grabbed a device). checks/manual.sh: 8 passed, 0 failed.

AC2 (a nested guest under ~/.local/bin/vm still has keyd suppressed) is NOT verified against a real booted guest in this environment - same honest gap TASK-160 itself left open. Left unchecked. DECISIONS.md's trade-off section names this gap explicitly.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Root cause: ConditionVirtualization=!vm (TASK-160's fix) can only see the hypervisor class, which is identical for a nested guest of this repo's own ~/.local/bin/vm and a top-level VM running this desktop as its only OS with no host-side keyd. It suppressed keyd on both, so on a top-level VM the left-Alt/left-Control swap TASK-40 establishes silently never applied - keyd stayed installed and enabled, just never started.

Fix: replaced the hypervisor-class check with an explicit marker. ~/.local/bin/vm now tags every guest it launches with -smbios type=1,family=arch-repo-vm-guest; keyd.service.d/override.conf uses ExecCondition= to skip starting keyd only when that DMI field (world-readable at /sys/class/dmi/id/product_family) carries the marker. Everything else - including a top-level VM - now takes the same path as bare metal. checks/session.sh's TASK-40 section checks the same marker instead of systemd-detect-virt --vm. Documented in apply-config.sh's CONFIG_FILES comment, docs/manual/04-applications.md, and a rewritten DECISIONS.md entry.

Verified live on this machine (a top-level VM, systemd-detect-virt -> kvm, no marker set): keyd.service went from failed/start-condition-unmet to active (running) after the fix, and the user confirmed the Alt/Control swap works again. checks/session.sh 125/0 (TASK-40 section on the bare-metal branch), checks/manual.sh 8/0.

Not verified: an actual guest booted via ~/.local/bin/vm to prove the marker suppresses keyd there (AC2) - the same class of gap TASK-160 itself left open, named explicitly in DECISIONS.md's trade-off section rather than assumed.
<!-- SECTION:FINAL_SUMMARY:END -->
