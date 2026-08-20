---
id: TASK-8
title: Add CPU microcode and a fallback boot entry
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-19 18:14'
updated_date: '2026-08-20 11:09'
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
- [ ] #3 A fresh VM install boots successfully from both the default and the fallback entry
- [x] #4 DECISIONS.md records why both microcode packages are installed rather than detecting the CPU vendor
- [x] #5 Microcode is loaded early by the mkinitcpio microcode hook, and the installer fails loudly rather than silently continuing if that hook is absent
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add intel-ucode and amd-ucode to base.txt so both are present regardless of CPU vendor. The kernel loads only the image matching the running CPU, so carrying both keeps the installer vendor-agnostic. base.txt is parsed raw by 02-base.sh, so no comments or blank lines.
2. Follow current Arch practice for early microcode: the mkinitcpio microcode hook bundles it into the initramfs, and separate ucode initrd lines in the bootloader are no longer used. Do not add initrd lines to the loader entries.
3. In 03-system.sh, verify the microcode hook is present in HOOKS and insert it after autodetect if missing, then re-verify and fail loudly rather than silently producing a system without microcode.
4. Regenerate the initramfs after the hook check so the images match the final configuration.
5. Add a second loader entry template for initramfs-linux-fallback.img, which mkinitcpio already generates, and have 03-system.sh render every template in system/loader/entries rather than naming files individually.
6. Leave loader.conf defaulting to the normal entry; the fallback is there to be chosen from the menu when the default fails.
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
<!-- SECTION:NOTES:END -->
