---
id: TASK-69.2
title: >-
  Build the bundled Arch base image from this repository, with no ISO and no
  wizard
status: To Do
assignee: []
created_date: '2026-08-23 15:58'
labels: []
dependencies:
  - TASK-69.1
parent_task_id: TASK-69
ordinal: 161000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The batteries-included part: a base qcow2 that is already this repository's Arch setup, built on the machine, never committed, and used as the backing file every other VM clones from.

The mechanism, which is why this is smaller than it sounds: install.sh already accepts any block device, and 01-disk.sh derives partition names from a trailing digit - so /dev/nbd0 correctly becomes /dev/nbd0p1 and /dev/nbd0p2. Attaching a qcow2 with qemu-nbd therefore lets the REAL installer build the image unmodified, rather than reimplementing the install against a different target. Verified by reading both scripts; not yet run.

Two consequences worth stating up front:

  * The base image genuinely is this repo's setup, because it was built by this repo's installer rather than by a parallel code path that could drift from it.
  * Running the builder is a scripted reproducibility test of install.sh. DECISIONS.md already prefers fresh-install tests over modifying the reference VM but has no cheap way to run one. This is that way, and it is arguably worth more than the VM.

Scope:

  * A builder under tools/ - repo tooling, because it needs install.sh, which is not copied onto the built machine and must not become part of setup/.
  * Guard the target device hard. This runs as root on a live machine and install.sh mounts at /mnt on the host; one typo in the device path targets a real disk. Refusing anything that is not /dev/nbd* is the obvious floor. CLAUDE.md's "never test the installer against the current machine" applies with full force here.
  * Make the base read-only once it exists. Writing to a backing file corrupts every overlay derived from it, and that failure appears in the clones rather than in the base.
  * Passwords stay interactive. The image is built once by hand; the objection was to the ISO and the wizard, not to typing a password. Do NOT add a non-interactive password path to install.sh for this - that stance is deliberate.
  * Machine identity is baked in from install.conf, so every clone starts with the same hostname. Decide whether that is acceptable for a first version or handled at clone time, and write down which.

The guest inherits this repo's WLR_NO_HARDWARE_CURSORS handling, so the inverted-cursor problem documented in setup/system/greetd/config.toml should not recur inside it. Worth confirming rather than assuming.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A base image is built end-to-end by the repository's own installer against an nbd-attached qcow2
- [ ] #2 The builder refuses any target that is not an nbd device
- [ ] #3 The finished base image boots under qemu with UEFI firmware and reaches the login screen
- [ ] #4 The base image is read-only once built, and is ignored by git
- [ ] #5 install.sh is unchanged, or changed only in ways that do not weaken its interactive password handling
<!-- AC:END -->
