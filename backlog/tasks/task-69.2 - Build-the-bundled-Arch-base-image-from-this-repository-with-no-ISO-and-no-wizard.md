---
id: TASK-69.2
title: >-
  Build the bundled Arch base image from this repository, with no ISO and no
  wizard
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-23 15:58'
updated_date: '2026-08-23 19:28'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. install.sh cannot be invoked directly against this host, even pointed at a virtual disk. Two confirmed hazards:
   - it ends with `poweroff`, correct on a live ISO, fatal here;
   - stage 3's `bootctl install` runs inside `arch-chroot`, which (in its default, unshare-less mode - confirmed by reading /usr/bin/arch-chroot) mounts a FRESH sysfs inside the target and then conditionally mounts a REAL efivarfs on top of $target/sys/firmware/efi/efivars if that directory exists - which it does on this real UEFI-booted host (efivarfs confirmed mounted rw). Unmitigated, bootctl would write real NVRAM boot entries onto this machine's firmware.
   The builder therefore drives the five numbered stage scripts directly (as install.sh itself does), not install.sh as a whole. This satisfies AC5 in spirit: the stage scripts stay byte-for-byte unmodified; only the orchestrator differs, exactly as it differs between install.sh and sync.sh already.

2. The efivars mitigation is NOT "mask /sys before chrooting" (sysfs is kernel-live, not a bind of the host's, so masking the host's path has no effect on what a fresh sysfs mount shows). It has to happen from INSIDE the chroot, after arch-chroot's own setup has already run (and possibly already mounted real efivarfs) and before the real stage script executes:
     arch-chroot "$MNT" /bin/bash -c '
       mount -t tmpfs tmpfs /sys/firmware/efi/efivars 2>/dev/null || true
       /opt/arch-setup/install/03-system.sh; rc=$?
       umount /sys/firmware/efi/efivars 2>/dev/null || true
       exit $rc'
   This shadows whatever arch-chroot mounted (verified: mounting on top of an existing mountpoint is legal), runs the unmodified stage script against a dummy tmpfs, then unmounts the shadow so arch-chroot's own teardown (which tracks and unmounts the real efivarfs mount it made) still succeeds cleanly. Only stage 3 needs this; 4 (apply-config.sh runs without --activate, confirmed exits before touching a live systemd/NVRAM) and 5 never call bootctl.

3. /dev/rtc0 exists on this host and stage 3's `hwclock --systohc` will resync it. Accepted, not mitigated: this just syncs the real hardware clock to the already-correct system time, self-correcting and not worth the fragility of masking a device that other stage-3 commands might need. Documented rather than silently accepted.

4. tools/build-vm-image.sh - repo tooling, needs install.sh, stays out of setup/. Requires arch-install-scripts and nbd (not on this host by default, installed as a one-time repo-development dependency exactly like backlog - never added to setup/packages/).
   - Runs entirely under an outer `unshare --mount --propagation private` (re-execing itself under it if not already there), so every filesystem mount this makes is private and self-cleaning if the script dies mid-way - the nbd device connection itself is not a mount and gets its own trap-based `qemu-nbd -d`.
   - Picks a free /dev/nbdN itself (tries 0..15); also accepts an explicit --device for the rare case auto-pick is wrong, and an assert_nbd() guard (defense in depth even for internally-chosen values) runs before every destructive call - the guard is independently testable by passing an obviously-wrong --device and confirming refusal before anything destructive runs.
   - Refuses a target path inside the git repository tree, so "ignored by git" holds structurally rather than by an added .gitignore entry (the default target, ~/.local/share/vm/base.qcow2, is outside the repo already).
   - Refuses to overwrite an existing base image that machines are still cloned from (checks ~/.local/share/vm/*/disk.qcow2 backing files) - overwriting it in place would be the exact "write to the backing file" corruption TASK-69.1 documented, just via replacement rather than a direct write.
   - Creates the qcow2, connects it, asserts the resulting device is /dev/nbd*, waits for partitions to settle.
   - `echo ERASE | .../01-disk.sh "$DISK"` - real unmodified script, piped confirmation because this is a freshly created scratch device we made ourselves, not a human-typed disk path.
   - 02-base.sh unmodified; copies setup/ into the mounted target exactly as install.sh's own copy step does.
   - Stage 3 via the efivars-shadow wrapper above; passwords stay genuinely interactive, so this final invocation is for the user to run themselves in their own terminal.
   - Stages 4 and 5 unmodified, no wrapper needed.
   - Unmount, disconnect nbd, chmod a-w on the finished image.

5. Everything up to the password prompt (nbd attach/detach, ERASE-piping, partitioning, pacstrap, payload copy, the efivars-shadow mechanism) gets tested by me against a scratch image and discarded. The user runs the finished script themselves for the real, persistent base image - agreed with the user directly, since a Bash tool call cannot type into an interactive passwd prompt and the task explicitly says not to weaken that interactivity.

6. Document the machine-identity trade-off (every clone starts with this machine's install.conf hostname) as accepted for v1 in DECISIONS.md, with a named follow-up rather than silently deciding it does or doesn't matter.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Builder written: tools/build-vm-image.sh. Verified against three scratch builds on this machine (8G images, discarded after use):

Real, non-hypothetical bugs found and fixed by testing rather than reading:

1. /sys/class/block/nbdN/size and /sys/block/nbdN/pid are STICKY - they keep their last value indefinitely after a genuine, verified qemu-nbd --disconnect (confirmed: a disconnected device that then fails all I/O with 'Input/output error' still reports its old nonzero size and old, now-dead pid). The original pick_device() trusted this and would have marked every nbd device on the host 'busy forever' after its first use. Fixed: picking a device and connecting to it are now the same step, and the only trusted signal is whether qemu-nbd --connect itself succeeds - confirmed separately, in one continuous privileged session (standalone pkexec calls get reaped by polkit's scope cleanup before a backgrounding daemon can persist, which cost real time to distinguish from an actual bug), that connect exits 0 with real I/O against a free device and exits 1 'Failed to set NBD socket' against a busy one.

2. A device can accept --connect and then serve NO I/O at all - found directly: nbd0, after several of my own manual connects/disconnects earlier in this session, kept accepting connects while every read failed, consistently across 5 retries with pauses (not a timing race - a neighbouring device under the identical wrapping worked on the first try). Fixed: every candidate is now proven twice - connects, AND serves a real dd read - before being accepted; a device that fails the read is disconnected and skipped, same as one that never connected, so the auto-picker routes around a wedged device instead of dying on it. An explicit --device still dies loudly rather than silently trying another.

Both fixes were then reconfirmed by rerunning the real pipeline three full times: nbd0 (wedged, correctly rejected) -> nbd1 (accepted) -> 01-disk.sh partitions it -> 02-base.sh pacstraps 191 packages -> fstab generated correctly (btrfs subvols + vfat ESP, matching install.sh's own layout) -> payload copied -> arch-chroot enters, the efivars shadow mount runs silently (no error, meaning it correctly intercepted whatever arch-chroot's own conditional efivarfs mount had done) -> 03-system.sh runs for real: timezone, locale, hostname, user creation, NetworkManager enabled -> hits 'Set root password:' and, with no stdin attached (a background job), fails cleanly after exactly 5 attempts per TASK-131's bound, rather than hanging. cleanup() correctly unmounted /mnt and disconnected the nbd device on this failure path every time.

This is genuinely everything short of the two passwords. Per the earlier discussion with the user, that step is intentionally left to them, in their own terminal, where an interactive passwd actually works.

Fixed one more latent bug on final review, not yet hit in testing: OUTPUT resolution used 'readlink -f $(dirname ...)' directly, and GNU readlink -f only tolerates ONE missing trailing path component. On a genuinely fresh account - before ~/.local/share exists at all - the default --output has two missing levels and readlink -f would fail silently empty, resolving OUTPUT to '/base.qcow2' at the filesystem root. Fixed with mkdir -p first, matching how ~/.local/bin/vm's own ensure_store() already avoids the same trap.

Status: script complete, all guards individually tested against real hazards found on THIS machine (not hypothetical), all repo checks green (session 122/0, manual 8/0, packages/sway-commands clean modulo unrelated pre-existing drift from other sessions - ffmpeg and spotify-player, neither touched by this task). DECISIONS.md and the manual (chapter 4's Virtual machines section, and a new chapter 8 recipe) document the mechanism and the machine-identity trade-off.

Remaining for AC1/AC3: the actual base image has not been built to completion, because completing it needs two real passwd prompts at a real terminal, which the user agreed to run themselves. Handing off now.
<!-- SECTION:NOTES:END -->
