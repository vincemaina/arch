---
id: TASK-89
title: 'zswap sits in front of zram, so the zram configuration barely does anything'
status: To Do
assignee: []
created_date: '2026-08-21 20:42'
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
- [ ] #1 The measurement is reproduced on the machine before anything is changed: zswpout, zswpwb and zram mm_stat are recorded, so the effect of the change can be compared against them
- [ ] #2 A decision is made and recorded in DECISIONS.md comparing zswap against zram, in the same style as the existing zram-versus-swapfile entry
- [ ] #3 Whatever is chosen is applied by setup/system/apply-config.sh so it reaches both a fresh install and a sync, not by hand on one machine
- [ ] #4 After the change, the pages are shown to be going where the decision says they should - not inferred from the config file
- [ ] #5 TASK-72's question about zram sizing is answerable afterwards, because it is clear which layer is holding the pages
<!-- AC:END -->
