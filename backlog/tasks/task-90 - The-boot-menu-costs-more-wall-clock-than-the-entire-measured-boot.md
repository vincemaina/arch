---
id: TASK-90
title: The boot menu costs more wall clock than the entire measured boot
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 20:42'
updated_date: '2026-08-22 00:42'
labels:
  - performance
  - boot
dependencies: []
priority: low
ordinal: 92000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
systemd-analyze reports 866ms kernel + 1.720s initrd + 2.066s userspace = 4.653s, and that figure is quoted as the boot time. It leaves out the part in front of it.

/boot/loader/loader.conf sets timeout 3, across two entries (default and the fallback added by TASK-8). systemd-analyze normally reports firmware and loader time as well, but only when the bootloader has exported LoaderTimeInitUSec and LoaderTimeExecUSec into EFI variables. Checked on this machine: those variables are absent - this is EDK II / OVMF - so systemd-analyze silently starts its accounting at the kernel and the 3 seconds spent looking at a menu are counted nowhere at all.

So the real wait from power-on to a greeter is about 7.7 seconds, of which roughly 39% is a menu nobody reads. On real hardware with a slower firmware the proportion changes but the 3 seconds do not.

The question is what the timeout is buying. It exists so the fallback entry can be selected. systemd-boot will show the menu when a key is held during boot even with timeout 0, and 'bootctl set-timeout-oneshot' can arm it from a running system for the case where you already know the next boot needs the fallback. Either would keep the escape hatch and give the 3 seconds back.

Two smaller things found in the same place, worth deciding at the same time:
  - initramfs-linux-fallback.img is 211.6 MiB of the 258 MiB used on a 1 GiB ESP, because the fallback preset drops autodetect and includes every module. That is not a boot cost, it is an ESP cost and a mkinitcpio -P cost.
  - Both intel-ucode.img (14.6 MiB) and amd-ucode.img (0.3 MiB) sit on the ESP, and neither is loaded: the microcode hook embeds the right one into the image, and /proc/cmdline and both loader entries name only initramfs-linux.img.

Also measured, and deliberately not proposed as a change: greetd waits on NetworkManager. systemd-user-sessions.service carries After=network.target upstream, so the critical chain runs graphical.target <- greetd <- systemd-user-sessions <- network.target <- NetworkManager (+273ms). NetworkManager-wait-online is already disabled. 273ms of 2.066s is real but small, and the ordering is upstream's, not this repository's.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The wall clock from power-on to a greeter is measured with a stopwatch, not inferred from systemd-analyze, so the change has a before and after that includes the part systemd-analyze cannot see
- [x] #2 A timeout is chosen and the reason recorded, including how the fallback entry is still reachable afterwards
- [x] #3 The change is made in setup/system/loader/ so it reaches a fresh install, and its interaction with sync is respected - loader templates are rendered at install time and must never be applied by sync
- [x] #4 A decision is recorded on whether the 211 MiB fallback initramfs and the two unused microcode images stay on the ESP
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
TIMEOUT 3 -> 1, in setup/system/loader/loader.conf.

Not zero, and the reason is in systemd-boot(7) itself. It confirms the menu is still reachable with timeout 0 by holding space, then adds: 'depending on the firmware implementation the time window where key presses are accepted before the boot loader initializes might be short. If the window is missed, reboot and try again, possibly repeatedly.' This menu exists to reach the fallback entry, which is wanted on the boot where something has already gone wrong - a recovery path needing several attempts is the wrong thing to economise on. One second is deterministic and returns two of the three, and bootctl set-timeout-oneshot arms the menu for a single planned boot from a working system.

AC4, both ESP items examined and both deliberately LEFT:
- initramfs-linux-fallback.img at 211.6 MiB is the recovery image, and being built without autodetect is the entire point of it. An ESP cost, not a boot cost, on a 1 GiB partition with 765 MiB free.
- intel-ucode.img (14.6 MiB) and amd-ucode.img (0.3 MiB) are confirmed unloaded - no loader entry and no /proc/cmdline names them, and the microcode hook embeds the right one into initramfs-linux.img (verified by listing it). But they are pacman-owned files: deleting them is undone by the next package update. Both packages stay declared so one repository builds an Intel or an AMD machine. 14.9 MiB is cheaper than fighting the package manager over files that cost nothing at boot.

AC1 IS NOT CHECKED, and cannot be by me. It asks for a stopwatch figure from power-on to greeter, before and after, and taking it means rebooting the machine this session is running in. The before figure is on record from TASK-66 - systemd-analyze 4.653s, which excludes the menu because OVMF exports no LoaderTimeInitUSec, so the real wait was about 7.7s. The after figure belongs to the next reboot and should be about two seconds shorter.

AC3 respected: the change is only in setup/system/loader/, which install.sh renders with the root UUID and sync deliberately never applies. This machine therefore still has timeout 3 until either a rebuild or 'sudo bootctl set-timeout 1'.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Boot menu timeout cut from 3s to 1s in setup/system/loader/loader.conf, recovering two seconds of a wait that systemd-analyze could not see at all - OVMF exports no LoaderTimeInitUSec, so its 4.653s figure started at the kernel while the real wait was nearer 7.7s. Not zero, because systemd-boot's own manual says the key window for reaching the menu may then be missed and need repeated reboots, and this menu exists for the boot where something has already gone wrong. The 211 MiB fallback initramfs and the two unloaded microcode images stay, both with reasons recorded. The stopwatch before/after belongs to the next reboot, since taking it means restarting the machine this session runs in.
<!-- SECTION:FINAL_SUMMARY:END -->
