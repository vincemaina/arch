---
id: TASK-182
title: The initrd spends 3.9s waiting on a USB card reader before it will switch root
status: To Do
assignee: []
created_date: '2026-08-26 10:10'
updated_date: '2026-08-26 10:10'
labels:
  - performance
  - boot
dependencies: []
priority: medium
type: bug
ordinal: 189000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
On the laptop, systemd-analyze reports 5.658s of initrd against 1.349s of kernel and 5.003s of userspace. The initrd is the single largest phase after firmware, and almost four seconds of it is one device probe.

MEASURED ON THIS MACHINE (vlod, Intel i5-8250U, Samsung MZNLN256HMHQ SATA SSD), from the journal of the current boot:

  2.221s  Found device SAMSUNG_MZNLN256HMHQ-000H1 primary
  2.961s  Mounted /sysroot
  2.979s  Reached target Initrd Default Target
  ...     nothing for 3.9 seconds
  6.823s  sd 2:0:0:0: [sdb] Media removed, stopped polling
  6.827s  sd 2:0:0:0: [sdb] Attached SCSI removable disk
  6.842s  systemd-udevd.service: Deactivated successfully
  6.890s  Switching root

systemd's own accounting for that unit, in the same journal:

  systemd-udevd.service: Consumed 1.637s CPU time over 4.966s wall clock time, 24.9M memory peak

So the root filesystem is mounted and the initrd has reached its default target at 2.979s. It then sits for 3.9 seconds because initrd-switch-root will not run until systemd-udevd stops, and udevd will not stop until its event queue drains. The last event in that queue is the internal USB card reader.

The device is a Realtek internal USB card reader (ID_VENDOR_ID=0bda, ID_MODEL_ID=0316, ID_VENDOR=Generic-, ID_MODEL=SD_MMC, ID_USB_DRIVER=usb-storage). With no card inserted it still enumerates as a removable SCSI disk, and the 'Media removed, stopped polling' line is the probe giving up. lsinitcpio -a /boot/initramfs-linux.img confirms usb-storage, uas, mmc_block, mmc_core and rpmb-core are all in the image - the autodetect hook includes them because the hardware is present, not because anything needs them to reach root.

WHY THIS IS WORTH A TICKET RATHER THAN A SHRUG

Nothing in the boot path needs that reader. Root is on SATA, found at 2.221s and mounted at 2.961s. The reader is being waited on purely because it happens to be in the same udev queue, and it is the slowest thing in it.

It is also invisible in the usual place to look. 'systemd-analyze blame' attributes none of it: it lists initrd-switch-root.service at 850ms and nothing else near four seconds, because the wait is udevd draining a queue rather than a unit taking a long time to start. Reading blame alone would send someone after NetworkManager (1.038s) or systemd-tmpfiles-setup-dev-early (973ms), neither of which is the problem.

It is hardware-specific, which matters for TASK-14. The reference VM has no card reader and reports 1.720s of initrd (recorded in TASK-90). This is the first measurement of the boot path on real hardware and the two are not comparable.

WHAT WOULD SETTLE IT

Establish whether the reader can be kept out of the initrd without keeping it out of the running system, since a card inserted after boot should still work. The obvious levers each need checking rather than assuming: mkinitcpio has no module-exclude, so autodetect will keep pulling usb-storage in while the hardware is present; a modprobe.blacklist on the kernel command line would apply to the booted system too, which is not wanted; and rd.driver.blacklist is a dracut option, not a mkinitcpio one. Whether any of these is the right answer is the research this ticket asks for, not a plan it should assume.

Also worth confirming: whether the wait is the reader alone. Removing it should be tested by measurement on a rebooted machine, not by reasoning from this one journal.

SEPARATE, SMALLER, FOUND AT THE SAME TIME - the ESP carries 15.3 MiB of microcode images that nothing reads. Both intel-ucode (15M) and amd-ucode (307k) are declared in packages/base.txt, which is correct so the installer works on either vendor. But mkinitcpio's 'microcode' hook embeds the right one into the initramfs (lsinitcpio reports a 6.48 MiB early CPIO, and the kernel logs 'microcode: Current revision: 0x000000f6'), and neither loader entry names a ucode initrd. So /boot/intel-ucode.img and /boot/amd-ucode.img are both dead files. Harmless at runtime; noted here so it is not rediscovered.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The 3.9s gap between Initrd Default Target and Switching root is explained by a cause confirmed on a rebooted machine, not inferred from a single journal
- [ ] #2 Whether the card reader can be kept out of the initrd without breaking a card inserted after boot is answered yes or no, with the mechanism recorded
- [ ] #3 If a change is made, initrd time is re-measured on this hardware and the before/after figures are recorded with the machine they came from
- [ ] #4 The boot figures for real hardware are recorded somewhere that does not silently read as if they came from the VM, since TASK-90's 1.720s initrd is a VM figure and is not comparable
- [ ] #5 The two unreferenced microcode images on the ESP are either removed, or a note records why they are kept
<!-- AC:END -->
