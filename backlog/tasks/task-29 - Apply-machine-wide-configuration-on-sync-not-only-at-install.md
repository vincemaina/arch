---
id: TASK-29
title: 'Apply machine-wide configuration on sync, not only at install'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-19 20:44'
updated_date: '2026-08-19 21:03'
labels:
  - repo
  - workflow
dependencies: []
priority: high
type: bug
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
sync.sh reconciles packages and dotfiles but nothing under setup/system/, so machine-wide configuration can only ever reach a machine during a fresh install. Running checks/session.sh on the reference VM after a sync showed the consequence: zram absent, vm.swappiness still 60, vm.page-cluster still 3, earlyoom not running - all of TASK-9 delivered to the repository and none of it to the machine.

This is a gap in TASK-12 rather than a new feature. Its acceptance criteria excluded partitioning, the bootloader and user creation, all of which are genuinely install-time. System configuration is not: sysctl settings, zram and the OOM handler are ordinary files that are safe to rewrite on a running machine, and they are exactly the kind of thing that will be tuned repeatedly.

The install path and the sync path must not drift, so the list of what gets installed where should exist once and be used by both rather than being duplicated.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A change under setup/system/ reaches an already-installed machine through the normal sync command
- [x] #2 The mapping from repository file to system destination is defined once and used by both the installer and sync
- [x] #3 Bootloader configuration remains install-time only and is not applied by sync
- [x] #4 Re-running sync leaves an already-correct machine unchanged
- [x] #5 Configuration that needs a service restart or reboot to take effect either takes effect or is reported, never silently deferred
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Extracted setup/system/apply-config.sh as the single owner of the repository-file to /etc-destination mapping. 03-system.sh now calls it during install, and sync.sh calls it with --activate, so a new system config file is added in one place and reaches both paths.

--activate exists because the two contexts genuinely differ: inside the installer chroot units can be enabled but not started, while on a running machine the point is for the change to take effect now. It runs sysctl --system, reloads systemd, restarts earlyoom and starts the zram device, reporting rather than failing if any of that does not work, since the configuration is already written by then.

An in-use zram device cannot be resized, which is correct as it holds swapped-out pages, so a size change is reported as needing a reboot rather than attempted.

Bootloader templates stay install-time only and are deliberately not in the mapping.

Verified: both scripts pass bash -n; the root guard rejects a non-root run; the mapping parses to the three intended destinations and every file under setup/system is accounted for as mapped, an install-time template, or the script itself; sync.sh dry run reports the step without acting and the real run invokes it through sudo with --activate; and no code path in either script touches the bootloader.

Verified end to end on the VM. Before the fix the same check reported no zram, swappiness 60, page-cluster 3 and earlyoom not running, with all of that configuration present in the repository. After sync.sh applied setup/system/ through apply-config.sh --activate, every one of those is correct on the running machine, and the settings took effect immediately rather than waiting for a reboot.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Extracted setup/system/apply-config.sh as the single owner of the repository-file to /etc-destination mapping, called by 03-system.sh during install and by sync.sh with --activate on a running machine. Fixes a gap in TASK-12 where machine-wide configuration could only ever reach a machine during a fresh install, leaving all of the zram and earlyoom work inert. Bootloader templates stay install-time only since they are rendered with the machine root UUID. Verified on the VM: configuration that was previously absent is now applied and active immediately, confirmed by checks/session.sh going from four failures in that area to none.
<!-- SECTION:FINAL_SUMMARY:END -->
