---
id: TASK-8
title: Add CPU microcode and a fallback boot entry
status: Done
assignee:
  - '@claude'
created_date: '2026-08-19 18:14'
updated_date: '2026-08-20 15:14'
labels:
  - foundation
  - boot
dependencies: []
references:
  - 'https://wiki.archlinux.org/title/Microcode'
  - 'https://wiki.archlinux.org/title/Systemd-boot'
priority: high
type: bug
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The bootloader is currently a single point of failure. setup/packages/base.txt installs no microcode package, and setup/system/loader/arch.conf has no ucode initrd line - Arch treats microcode as required for CPU stability and errata fixes. There is also only one boot entry, built from initramfs-linux.img, so a bad kernel or initramfs update leaves the machine unbootable with no way back in short of the install media.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 intel-ucode and amd-ucode are installed by the base install
- [x] #2 A second boot entry using initramfs-linux-fallback.img is generated alongside the default entry
- [x] #3 A fresh VM install boots successfully from both the default and the fallback entry
- [x] #4 DECISIONS.md records why both microcode packages are installed rather than detecting the CPU vendor
- [x] #5 Microcode is loaded early by the mkinitcpio microcode hook, and the installer fails loudly rather than silently continuing if that hook is absent
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Diagnosis confirmed on the running machine. apply-config.sh flips PRESETS to include fallback, but mkinitcpio v40 also ships fallback_image and fallback_options commented out. mkinitcpio.d line 713 warns "No image or UKI specified. Skipping image" and continues, so mkinitcpio -P exits 0 and the fallback image is never built while every visible signal - the preset, the boot entry, the script output - says it was.

2. Extend the preset loop in apply-config.sh to uncomment fallback_image and fallback_options alongside PRESETS, each guarded to rewrite only the exact commented stock form so an already-correct or hand-customised preset is left alone, matching how the PRESETS rewrite already behaves.

3. fallback_options="-S autodetect" matters as much as the image path. Without it the fallback is built with autodetect and contains only modules for hardware present at build time, which is exactly the hardware that may have stopped working. A fallback that is a copy of the default is not a recovery path.

4. Make the failure loud. mkinitcpio only warns when a preset has no destination, so after regeneration verify every expected image exists and exit non-zero naming the missing one, rather than reporting success.

5. Strengthen checks/session.sh to assert the preset resolves - fallback listed in PRESETS and an active fallback_image - not merely that a file exists. The current check passes on configuration that cannot produce an image.

6. Apply with sync.sh, then confirm the image exists and is meaningfully larger than the default, which is the observable signature of a build without autodetect.

7. Remaining for AC #3: reboot, choose the fallback entry, confirm it boots. Only a human at the machine can do that.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added intel-ucode and amd-ucode to base.txt. Loaded through the mkinitcpio microcode hook rather than a separate initrd line, which is current Arch practice and keeps the boot entries free of any vendor-specific detail.

03-system.sh now verifies the hook is in HOOKS, inserts it after autodetect when missing, re-checks, and exits non-zero with the offending HOOKS line if it still is not there. Initramfs is regenerated afterwards so the images match the final configuration.

Boot entry templates moved to system/loader/entries/ and 03-system.sh renders every .conf in that directory instead of naming arch.conf explicitly, so the fallback entry needed no installer change beyond the loop and a future entry is just a file.

Verified: bash -n on 03-system.sh; the hook logic exercised against four HOOKS variants - already present (no-op), missing with parentheses, missing with the older quoted style, and missing autodetect entirely, which correctly falls through to the loud failure; and the entry rendering loop run against a temporary boot directory, producing both entries with __ROOT_UUID__ fully substituted and no placeholder left behind.

AC #4 not verified here: booting both entries needs the VM, since nothing in this container can run bootctl or mkinitcpio.

Original AC #2 asked for a microcode initrd line ordered before the main initramfs in the boot entry. That was written from the older documented method, before establishing that Arch now bundles microcode through the mkinitcpio hook and explicitly says the initrd lines can be dropped. The criterion was replaced rather than checked, since satisfying it as written would mean deliberately using the superseded approach.

Microcode half confirmed live on the VM: the hook is present in HOOKS and both ucode packages are installed. The fallback boot entry cannot be confirmed there, since boot entries are rendered at install time and sync deliberately never touches the bootloader; it needs a machine built by the current install.sh.

Fresh VM built from the current installer and booted successfully, so the default entry is confirmed and the microcode work is confirmed end to end on a machine built into that state rather than converted. Booting from the fallback entry has not been separately observed - that needs choosing it explicitly at the boot menu.

Fallback entry confirmed present in the boot menu on the fresh VM, which verifies generation. Booting from it is still unobserved.

Added a check that both initramfs images exist and are non-empty. That covers the failure this would otherwise hide - an entry referencing an image mkinitcpio never produced looks correct in the menu and fails only when chosen. What remains unverified is narrow: that the fallback image itself boots, which needs selecting it at the menu once.

checks/session.sh on the fresh VM found /boot/initramfs-linux-fallback.img missing, so the fallback boot entry pointed at an image that does not exist. It would have looked like a working recovery path right up to the moment it was needed.

Cause: mkinitcpio v40 stopped building the fallback image by default, shipping PRESETS=(default) where it previously included fallback. The entry was added on the assumption the image was still generated.

Fixed by enabling the fallback preset. The initramfs logic - microcode hook, preset, regeneration - moved out of 03-system.sh into apply-config.sh so it reaches machines that already exist rather than only freshly installed ones, following the same reasoning as TASK-29. Regeneration is conditional, since it is slow: it runs when the hook or preset was changed, or when an expected image is missing, which is also what repairs a machine installed before this fix.

The preset rewrite was tested against three shapes and only rewrites the exact default-only form, leaving an already-correct or customised preset alone.

Also fixed an unbound REPO_ROOT in the dotfile references section of checks/session.sh, which aborted the check before it finished.

Reopened on the physical machine: checks/session.sh reported the fallback image missing, so the earlier fix was incomplete rather than merely unverified.

Cause. mkinitcpio v40 comments out three lines, not one: PRESETS, fallback_image and fallback_options. apply-config.sh only restored PRESETS. mkinitcpio takes the destination from ${preset}_image and, finding none, prints "No image or UKI specified. Skipping image" at mkinitcpio line 713 and continues - a warning, not an error. mkinitcpio -P therefore exited 0 and the script reported "Regenerating initramfs" while producing nothing. The preset said fallback, the boot entry referenced the image, the script claimed success, and the file had never existed. Same failure mode as the original bug, one level further down.

fallback_options was the more damaging omission of the two. "-S autodetect" is what makes a fallback a fallback: without it the image is built with autodetect and carries modules only for hardware present at build time, which is the hardware that may be why the fallback is needed. It would have been a 15M copy of the default wearing a recovery entry name.

Fix. apply-config.sh now uncomments fallback_image and fallback_options alongside PRESETS, each guarded to the exact stock commented form so an already-correct or hand-customised preset is untouched, and errors out if a preset lists the fallback with no destination. After mkinitcpio -P it verifies every expected image exists on disk and exits non-zero naming any that is missing, because mkinitcpio exit codes say nothing about which images were produced.

checks/session.sh now asserts the preset can produce the fallback - destination set, autodetect skipped - rather than only that a file exists. The previous check passed on configuration incapable of ever rebuilding the image.

Tested against five preset shapes: stock v40 (all three lines corrected), already correct (no-op, no needless regeneration), hand-customised path and options (untouched), UKI-style (no false failure), and fallback listed with no destination (exits 1 loudly).

Verified live: initramfs-linux-fallback.img now exists at 212M against the 15M default, the size difference being the observable signature of a build without autodetect. checks/session.sh went from 31 passed 1 failed to 34 passed 0 failed.

AC #3 still open and needs a human: reboot, choose "Arch Linux (fallback initramfs)" at the menu, confirm it boots.

Fallback entry booted and confirmed on the physical machine. /proc/cmdline reports initrd=\initramfs-linux-fallback.img and the EFI variable LoaderEntrySelected reads arch-fallback.conf. An earlier attempt looked successful but both values read arch.conf, so the default had booted - the 3 second menu had elapsed. Worth recording, because a fallback boot is indistinguishable from a normal one by eye: it is the same kernel, root and userspace, and only the initramfs differs. Checking cmdline is the only way to tell.

checks/session.sh reports 40 passed 0 failed while running on the fallback image.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Microcode is installed for both vendors and loaded through the mkinitcpio hook, and a second boot entry using the fallback initramfs is generated alongside the default. The fallback image is now actually built: enabling the preset was not enough, because mkinitcpio v40 also comments out fallback_image and fallback_options, and without a destination it skips the image with a warning and exits 0. fallback_options mattered as much as the path - "-S autodetect" is what makes the image a recovery image rather than a copy of the default carrying only the modules for hardware that was present at build time. apply-config.sh now restores all three, refuses to enable a fallback with no destination, and verifies the images exist after regenerating, since mkinitcpio exit codes say nothing about what was produced. Verified end to end: the image builds at 212M against the 15M default, and the machine has now booted from the fallback entry, confirmed by /proc/cmdline and LoaderEntrySelected rather than by appearance.
<!-- SECTION:FINAL_SUMMARY:END -->
