---
id: TASK-8
title: Add CPU microcode and a fallback boot entry
status: To Do
assignee: []
created_date: '2026-08-19 18:14'
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
- [ ] #1 intel-ucode and amd-ucode are installed by the base install
- [ ] #2 The generated boot entry lists the microcode initrd BEFORE the main initramfs initrd
- [ ] #3 A second boot entry using initramfs-linux-fallback.img is generated alongside the default entry
- [ ] #4 A fresh VM install boots successfully from both the default and the fallback entry
- [ ] #5 DECISIONS.md records why both microcode packages are installed rather than detecting the CPU vendor
<!-- AC:END -->
