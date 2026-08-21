---
id: TASK-90
title: The boot menu costs more wall clock than the entire measured boot
status: To Do
assignee: []
created_date: '2026-08-21 20:42'
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
- [ ] #2 A timeout is chosen and the reason recorded, including how the fallback entry is still reachable afterwards
- [ ] #3 The change is made in setup/system/loader/ so it reaches a fresh install, and its interaction with sync is respected - loader templates are rendered at install time and must never be applied by sync
- [ ] #4 A decision is recorded on whether the 211 MiB fallback initramfs and the two unused microcode images stay on the ESP
<!-- AC:END -->
