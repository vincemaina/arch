---
id: TASK-160
title: VM guest keyboard modifiers fight the host's left-Alt/left-Control swap
status: Done
assignee:
  - '@claude'
created_date: '2026-08-24 09:05'
updated_date: '2026-08-24 09:25'
labels:
  - vm
  - desktop
dependencies:
  - TASK-69.1
priority: medium
ordinal: 169000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-40 swapped left Alt and left Control across the bare-metal session (sway, console, greeter). Inside a virtual machine launched via the vm tooling from TASK-69.1/TASK-69.3, the guest OS has its own independent keyboard configuration, which is not swapped - so keys land back in their normal positions once focus is inside the guest, and the host and guest disagree with each other. Make the guest's keymap match the host's swap so muscle memory does not have to change when switching between them.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Typing inside a running VM guest produces the same left-Alt/left-Control behaviour as the bare-metal sway session
- [x] #2 The fix is applied to the base image or VM provisioning path from TASK-69.2, not patched by hand into a running instance, so it survives cloning a fresh VM
- [x] #3 Document where the guest-side swap is configured, alongside the host-side one referenced from TASK-40
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Confirm the mechanism by reading tools/build-vm-image.sh, apply-config.sh and executable_vm: the base image is built by running this repo's own unmodified 03-system.sh/04-desktop.sh in a chroot, so apply-config.sh unconditionally installs+enables keyd inside the guest with the identical swapped default.conf. The guest's virtio-keyboard device receives keycodes QEMU derives from the host's own already-swapped input (keyd sits below the Wayland compositor, and QEMU is just another Wayland client), so the guest's own keyd swaps a second time and cancels the host's swap - the reported bug.
2. Fix at the provisioning layer, not by hand in a running guest: ship a systemd drop-in setup/system/keyd/keyd.service.d/override.conf with ConditionVirtualization=!vm, wired into apply-config.sh's CONFIG_FILES the same way every other machine-wide file is. keyd stays installed and enabled identically everywhere (single source of truth preserved); the condition is evaluated at every unit start, so it self-corrects on sync.sh re-runs inside a guest and is inert on real hardware / a non-nested VM host.
3. Update checks/session.sh's TASK-40 section to be virtualization-aware: on a VM guest, assert keyd is correctly NOT active and that the override drop-in is present, instead of failing 'keyd is not running'; on bare metal, keep the existing assertions unchanged.
4. Document the guest-side half of the swap alongside TASK-40's host-side one: docs/manual/03-the-keyboard.md and 04-applications.md (Virtual machines section), plus a new DECISIONS.md entry.
5. Verify: systemd-analyze verify --root=... against a throwaway root proves the drop-in parses and merges with keyd.service with no error from the override itself; a standalone harness reproduces the exact checks/session.sh branch logic against faked systemd-detect-virt/systemctl and shows it going both red and green correctly; the real checks/session.sh and checks/manual.sh were run on this real (non-VM) machine and pass, proving no regression on bare metal. Explicit gap: no real qemu guest was booted in this environment, so the actual guest-side keypress was not observed end to end - flagged rather than assumed.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause confirmed by reading tools/build-vm-image.sh, apply-config.sh and executable_vm: TASK-69.2's builder runs the real, unmodified 04-desktop.sh in a chroot, so apply-config.sh installs+enables the same swapped /etc/keyd/default.conf inside the guest as on the host. keyd sits below the compositor, so by the time a keypress reaches Sway - and therefore QEMU, itself just a Wayland client - it is already host-swapped; QEMU forwards that already-swapped keycode into the guest's virtio-keyboard unchanged, and the guest's own keyd swaps it a second time, cancelling the host's swap.

Fix: setup/system/keyd/keyd.service.d/override.conf (ConditionVirtualization=!vm), wired into apply-config.sh's CONFIG_FILES map exactly like every other machine-wide file - so it is installed/enabled identically on bare metal, sync.sh, and the VM base image build, and only whether keyd's unit actually STARTS differs, re-evaluated on every start (including sync.sh's systemctl restart keyd under --activate). checks/session.sh's TASK-40 section is now virtualization-aware: on a VM guest it asserts the override is present and keyd is correctly inactive; on bare metal the pre-existing assertions (running, enabled, grabbed a device) are unchanged.

Verification, and honest limits of it (no real qemu guest was booted in this environment): (1) systemd-analyze verify --root=<throwaway root with only keyd.service + this drop-in> parses cleanly - it gets past the override entirely and only complains about the throwaway root's missing sysinit.target/binary, proving the ConditionVirtualization directive and drop-in merge are syntactically valid. (2) A standalone bash harness reproduced the exact checks/session.sh branch logic against faked systemd-detect-virt/systemctl for 4 scenarios (VM+correct override, VM+missing override, VM+keyd still active, not-a-VM) and it went PASS/FAIL exactly as intended in each - not a check that would pass by luck. (3) checks/session.sh and checks/manual.sh were run for real on this development machine (real hardware, systemd-detect-virt reports 'none'): session.sh 124/0 passed, with the TASK-40 section taking the unchanged bare-metal branch (keyd running/enabled/grabbed-a-device, same as before this change) - proving no regression outside the VM scenario. manual.sh 8/0, confirming the new manual cross-references resolve. checks/packages.sh shows 5 pre-existing failures (ffmpeg, arch-install-scripts, dosfstools, nbd, spotify-player) already called out as known drift in TASK-69.1/69.2's notes and untouched by this change.  NOT verified: an actual VM guest booted via ~/.local/bin/vm from a host with keyd active, with a real physical keypress observed inside it (e.g. via keyd monitor/listen in the guest) - the end-to-end behavioural claim in AC1 rests on the evdev-layer mechanism (documented in DECISIONS.md) and the syntactic/logic checks above, not on a live guest observation. Left explicitly open for a human at a real machine, same as several TASK-40/TASK-69.x verifications before it that needed a human at the keyboard.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Root cause: TASK-69.2's VM base-image builder runs this repo's real, unmodified 04-desktop.sh in a chroot, so apply-config.sh installs and enables the identical swapped keyd config inside the guest as on the host. Because keyd remaps below the compositor, QEMU (a Wayland client of the host's Sway) only ever sees already-swapped keycodes and forwards them unchanged into the guest's virtio-keyboard - so the guest's own keyd swaps a second time and cancels the host's TASK-40 remap, which reads as the keyboard being unswapped inside the guest.

Fix lives entirely in the provisioning path: setup/system/keyd/keyd.service.d/override.conf (ConditionVirtualization=!vm) is wired into apply-config.sh's CONFIG_FILES map the same way every other machine-wide file is, so it reaches the VM base image build, a fresh install and sync.sh identically. keyd stays installed/enabled everywhere - the single source of truth TASK-40 established is unchanged - only whether the unit actually starts differs, decided fresh on every start, so it self-corrects if sync.sh is re-run inside a guest built from an older image. checks/session.sh's TASK-40 section is now virtualization-aware, asserting the opposite of 'keyd running' on a VM guest instead of misreporting it as a failure. Documented in docs/manual/03-the-keyboard.md, docs/manual/04-applications.md, and a new DECISIONS.md entry alongside the existing TASK-40/TASK-69.2 material.

Verified: systemd-analyze verify against a throwaway root confirms the drop-in parses and merges cleanly; a standalone harness proves the new session.sh branch logic goes both PASS and FAIL correctly across 4 scenarios; the real checks/session.sh (124/0) and checks/manual.sh (8/0) pass on this real, non-VM machine with the TASK-40 section taking its unchanged bare-metal path - no regression. NOT verified: an actual VM guest booted via ~/.local/bin/vm with a real keypress observed inside it - no qemu guest was booted in this environment, so AC1's end-to-end behavioural claim rests on the documented evdev-layer mechanism and the logic/syntax verification above, not a live observation. Left open for a human at a real machine; AC1 is intentionally left unchecked for that reason, AC2 and AC3 are checked.
<!-- SECTION:FINAL_SUMMARY:END -->
