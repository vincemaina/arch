---
id: TASK-72
title: best size for zram?
status: To Do
assignee: []
created_date: '2026-08-21 11:47'
updated_date: '2026-08-21 20:43'
labels: []
dependencies: []
priority: low
type: enhancement
ordinal: 74000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
currently its set of half or ram. but in a previous installation one place recommended setting it to 100% of ram, 150% or even 200%. I don't fully understand but this is perhaps worth looking in to. Perhaps it should also consider how much ram there is first before prescribing zram. i.e. if the user already has 64gb ram, would having zram set to twice that, eat up 128gb of their ssd/hdd storage? or is that not how swaps work, can space reserved for swapped pages still be used for file storage?
<!-- SECTION:DESCRIPTION:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @claude
created: 2026-08-21 20:43
---
Numbers from TASK-66, offered as input rather than an answer - this task is not settled by them.

Before sizing zram, note that on this machine zram is barely used at all, because zswap is in front of it. The Arch kernel ships CONFIG_ZSWAP_DEFAULT_ON=y, so every page swapped out is compressed into zswap's own RAM pool (zstd, capped at 20% of RAM) and zram only sees what zswap writes back. Measured after a day: 920,911 pages went into zswap and 9,415 of them - 1.0% - reached zram. The zram device is sized at 1.9 GiB and has never held more than 7.0 MiB at any point since boot. That is now TASK-89.

So the question 'how big should zram be' currently has a hidden premise. Whichever layer ends up holding the pages is the one whose size matters.

On the part of the question that is independent of that: zram costs no disk at all. It is a block device backed by RAM, so a 1.9 GiB zram device occupies zero bytes of the SSD - it occupies only as much RAM as the compressed pages it is actually holding, which is why the device here reports 1.9G disksize and 2.2M of RAM used. That is the answer to 'would zram at twice the RAM eat 128 GB of storage': no, it eats nothing until pages arrive, and then it eats RAM. The reason to cap it is that swapping into RAM cannot create memory, so an oversized device mostly changes how far the machine will thrash before something is killed.

For the machine as it stands: 3.9 GiB RAM, compression measured at 1.87x in zswap and 6.16x in zram (the zram figure is on a tiny sample and not trustworthy). earlyoom has never fired - /proc/vmstat oom_kill is 0 - although kswapd has used 19 CPU-seconds and reclaimed 11 GiB of page cache since boot, so the machine is under real pressure without ever reaching the OOM thresholds.
---
<!-- COMMENTS:END -->
