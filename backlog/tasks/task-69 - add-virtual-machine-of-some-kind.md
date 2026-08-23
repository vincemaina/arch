---
id: TASK-69
title: add virtual machine of some kind
status: To Do
assignee: []
created_date: '2026-08-21 11:17'
updated_date: '2026-08-23 15:57'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 71000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A batteries-included Arch VM that this setup ships with, plus the ability to run other VMs alongside it.

Not literal self-replication. The value is being able to spin up a VM that is already this repository's Arch setup - for dangerous work, or to isolate a project - without downloading an ISO or sitting through the install wizard every time.

The shape that follows from that: build a base image ONCE, then clone it per VM as a qcow2 overlay, so a new machine costs a few hundred KB and appears instantly. Resetting a VM is deleting its overlay. The bundled image is the easy default; running an unrelated VM must stay possible.

A second part, and the reason this became concrete: offer the VM at the LOGIN SCREEN, next to Sway. Picking it boots straight into the guest with no desktop session behind it.

MEASURED, so the rationale is honest rather than assumed:

  * Not running the sway session saves ~165 MB PSS (sway ~70, waybar 31, autotiling 20, polkit agent 17, portals 15, mako 8). On 7.5 GB that is ~2%. The resource saving is NOT the reason to do this.
  * The reasons that do hold: key passthrough (sway grabs every $mod combo, so a guest desktop never sees Super+Enter; cage grabs almost nothing), starting clean with nothing else resident, and not competing with a loaded desktop for earlyoom headroom.
  * qemu+cage vs libvirt+virt-manager is ~100-300 MB of host overhead, against a 2-4 GB guest. Chosen for fewer moving parts and for skipping the SPICE round trip, not for the memory.

FEASIBILITY, checked on this machine:

  * Real hardware, Intel VT-x, /dev/kvm present at mode 0666 (no group membership needed), nested enabled, 231 GB free.
  * install.sh already takes any block device, and 01-disk.sh derives partition names from a trailing digit - so /dev/nbd0 becomes /dev/nbd0p1 correctly. A qcow2 attached with qemu-nbd can therefore be installed into by the REAL installer, unmodified. The base image is then genuinely this repo's setup, and building it doubles as the scripted reproducibility test for install.sh that DECISIONS.md ("Prefer fresh-install tests over modifying the reference VM") currently has no cheap way to run.
  * Interactive passwords are not a blocker: the base image is built once, by hand. The objection was to the ISO and the wizard, not to typing a password once.

CONSTRAINTS worth carrying into the subtasks:

  * No image may be committed. Same rule as wallpapers; checks/session.sh already refuses anything image-shaped under setup/dotfiles/. The base image is generated on the machine.
  * A qcow2 on Btrfs needs nodatacow or it fragments badly, and chattr +C only takes effect on a DIRECTORY before the files are created.
  * The base image must become read-only once overlays exist. Writing to a backing file corrupts every overlay derived from it.
  * earlyoom must not kill a running guest - that is a power cut to the guest, not a lost browser tab. qemu-system-x86_64 has comm "qemu-system-x86", exactly the 15 bytes earlyoom matches on, so it fits --avoid. Safe only if the guest's RAM is capped with -m, which bounds the runaway case the avoid-list would otherwise create.
  * The image BUILDER is repo tooling (it needs install.sh) and stays out of setup/. The day-to-day vm command ships as a dotfile.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A base Arch image is built from this repository without an ISO or the install wizard
- [ ] #2 A new VM is created by cloning that base, costs near-zero disk, and appears instantly
- [ ] #3 Unrelated VMs can still be run alongside the bundled one
- [ ] #4 The bundled VM is selectable at the login screen and boots with no desktop session behind it
- [ ] #5 No image file is committed to the repository
<!-- AC:END -->
