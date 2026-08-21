---
id: TASK-89
title: 'zswap sits in front of zram, so the zram configuration barely does anything'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-21 20:42'
updated_date: '2026-08-21 20:56'
labels:
  - performance
  - foundation
dependencies: []
priority: high
ordinal: 91000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-9 configured zram with care - min(ram / 2, 8192), zstd, swap-priority 100, vm.swappiness 180, vm.page-cluster 0 - and every one of those settings is correctly applied and almost entirely inert. Measured on the reference VM after a day of use (TASK-66, tools/performance.sh):

  zswpout   920,911 pages compressed into zswap  (3.5 GiB)
  zswpwb      9,415 pages ever written back to zram  (1.0% of the above)
  zram mm_stat: 6.5 MiB stored now, 7.0 MiB the most it has EVER held
  /proc/swaps: 213 MiB of swap slots in use, of which zram holds 6.5 MiB

The cause is that the Arch kernel ships CONFIG_ZSWAP_DEFAULT_ON=y. /sys/module/zswap/parameters/enabled is Y, its compressor is zstd, and its pool is capped at 20% of RAM. Every page swapped out is compressed into zswap's own RAM pool first; zram only sees the writeback when that pool is full. So a zram device sized at half of RAM is standing behind a smaller pool that catches 99% of the traffic, and the whole configuration is doing something other than what it says.

Nothing here is broken - the machine swaps, compresses and has never OOMed. The problem is the same one this repository keeps finding: configuration that looks deliberate and is not doing the job it was written for. Read DECISIONS.md today and it compares zram against a disk swapfile, with no mention that a second compressed-swap layer is in front of it on every boot.

The decision to make is which layer this repository actually wants. Broadly:
  - zram only: turn zswap off (zswap.enabled=0 on the kernel command line, or the sysfs parameter), and TASK-9's configuration starts doing what it says.
  - zswap only: drop zram, give zswap a real backing device, which means a disk swapfile - which DECISIONS.md already rejected.
  - Both, deliberately: keep them, and write down why a small in-RAM pool in front of a large in-RAM device is worth having, because it is not obvious.

Whichever is chosen, DECISIONS.md needs the comparison it does not currently have, and the choice has to be applied by setup/system/apply-config.sh so it reaches both a fresh install and a sync.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The measurement is reproduced on the machine before anything is changed: zswpout, zswpwb and zram mm_stat are recorded, so the effect of the change can be compared against them
- [x] #2 A decision is made and recorded in DECISIONS.md comparing zswap against zram, in the same style as the existing zram-versus-swapfile entry
- [x] #3 Whatever is chosen is applied by setup/system/apply-config.sh so it reaches both a fresh install and a sync, not by hand on one machine
- [ ] #4 After the change, the pages are shown to be going where the decision says they should - not inferred from the config file
- [ ] #5 TASK-72's question about zram sizing is answerable afterwards, because it is clear which layer is holding the pages
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
AC1 - the before-measurement, recorded on this machine before anything changed (2026-08-21, 10.5 hours uptime):
  zswpout 920,911   zswpwb 9,415 (1.02%)   pswpin 1,862   zswpin 450,031
  pswpout 9,415 - identical to zswpwb, so every page that ever reached zram
    arrived by being evicted from zswap, none directly
  zram mm_stat: 2.2 MiB stored, 7.0 MiB mem_used_max, disksize 1,951 MiB
  /sys/module/zswap: enabled=Y, compressor=zstd, max_pool_percent=20

DECISION: zswap off, zram is the compressed swap.

The two do not stack usefully. zswap exists to avoid touching a disk - it absorbs pages in RAM so a slow device behind it is written to less often, which is a real gain against an SSD. When the device behind it is also RAM the arrangement costs instead: a page is compressed into zswap, and on writeback it is decompressed and handed to zram, which compresses it again. Two compressions and a decompression, both in RAM, per page. DECISIONS.md already rejected disk swap, which removes zswap's premise.

APPLIED THROUGH tmpfiles, AND THE REASON MATTERS. zswap.enabled=0 on the kernel command line is the usual answer and would be better if it could reach a running machine. It cannot: system/loader/ entries are rendered with the root UUID at install time and are deliberately never applied by sync, so a cmdline change would land on fresh installs and no existing machine - a change that only affects machines nobody has yet. zswap is built in rather than a module, so modprobe.d has nothing to act on. The parameter is writable through sysfs and tmpfiles is what systemd provides for writing sysfs at boot, so setup/system/tmpfiles.d/zswap.conf covers boot, apply-config.sh installs it on both paths, and --activate runs systemd-tmpfiles so a sync takes effect without a reboot. Validated with systemd-tmpfiles --dry-run, which reports it would write the intended file.

checks/session.sh now fails when zswap is enabled, and it FAILS RIGHT NOW - correctly. The kernel enables zswap on every boot, so this machine stays in the old state until ./sync.sh applies the new file, which needs a password I do not have. That red check is the accurate report, not an oversight.

AC4 IS NOT DONE and cannot be by me: showing the pages going where the decision says needs the change to be live. After ./sync.sh, /sys/module/zswap/parameters/enabled should read N, and from then on zswpout should stop climbing while zram's mm_stat starts to. Those are the numbers to compare against the block above.
<!-- SECTION:NOTES:END -->
