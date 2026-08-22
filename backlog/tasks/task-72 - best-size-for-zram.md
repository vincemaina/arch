---
id: TASK-72
title: best size for zram?
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 11:47'
updated_date: '2026-08-22 00:56'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Read TASK-89's before/after numbers now that zswap is off and zram holds the pages.
2. Measure current real state: mm_stat, /proc/swaps, compression ratio under natural (unforced) usage.
3. Induce bounded swap pressure (well clear of earlyoom's 10%/5% thresholds), measure zram mm_stat/ratio/peak under load, then release and confirm clean recovery.
4. Weigh the worst-case-RAM-ceiling argument (mem_limit is unset, so disksize bounds RAM usage in the pathological incompressible case) against the measured ratio and peak usage to decide whether min(ram/2, 8192) is still the right fraction.
5. Record findings; leave zram-generator.conf unchanged if the fraction is validated, or adjust it with evidence if not.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Baseline (natural usage, zswap off per TASK-89, ~15h since last boot/sync): /proc/swaps used 769 MiB of 1951 MiB (39%). zram mm_stat: orig 564.1 MiB, compr 292.7 MiB, mem_used_total 299.8 MiB, mem_used_max (this boot) 368.8 MiB. Ratio orig/compr = 1.93x. zswap confirmed off: /sys/module/zswap/parameters/enabled = N.

Induced pressure test: allocated 1200 MiB of semi-realistic content (tiled real /usr/bin and /usr/lib file bytes, not zeros/pure-random) via a background python process, held it, measured, then killed it. Monitored available memory throughout to stay clear of earlyoom (warn 10%, kill 5% of BOTH mem and swap). Available memory never dropped below ~1.18 GiB (30%+ of 3.9 GiB total) - comfortably clear of the ~390 MiB (10%) warn line. Swap did fill hard: /proc/swaps used rose to 1942/1951 MiB (99.5%), i.e. the device's logical capacity (not RAM) was the binding constraint - earlyoom's own log shows swap free bottoming at 3.15% at the peak, while mem avail stayed at 49% throughout, so a kill was never close (earlyoom requires both thresholds crossed).

Peak zram mm_stat during the test: orig 1765.6 MiB, compr 835.6 MiB, mem_used_total 855.1 MiB, mem_used_max 855.4 MiB (22% of total 3.9 GiB RAM). Ratio orig/compr = 2.11x. Caveat: this ratio is likely a slight overestimate versus fully organic data, because the synthetic pool tiles real file bytes with a repeat, adding some redundancy beyond what independent application pages would have; treat 1.9-2.1x as the working range rather than 2.1x specifically.

Released the allocation: process killed, memory recovered cleanly within seconds (available back to 2045 MiB, swap used back down near the 867 MiB baseline). /proc/vmstat oom_kill stayed 0 throughout; systemctl status earlyoom shows no kill action; all session units unaffected.

Sizing conclusion: min(ram/2, 8192) is validated, not just carried over. Two independent reasons: (1) worst-case ceiling - mem_limit is unset (0/unlimited) on this device, so zram's actual RAM ceiling in the pathological all-incompressible case is bounded only by disksize. Capping disksize at ram/2 is what keeps that worst case at half of RAM rather than more; raising the fraction toward 100-200% (as the task description's 'previous installation' recommended) directly raises that worst-case ceiling with no compensating benefit on THIS machine. (2) measured ratio - real/near-real data compresses 1.9-2.1x here, so even loaded to 99.5% of logical capacity, zram used only ~22% of total RAM (855 MiB of 3.9 GiB) - the fraction already leaves a large safety margin in the common case, it is the worst case that the /2 divisor is actually defending against. The thing that filled first under pressure was the device's logical swap-slot capacity, not RAM - and that is backstopped by page-cache reclaim (kswapd already reclaims ~11 GiB/day per TASK-66/TASK-72#1), not a hard failure. No evidence surfaced that half-of-RAM is too small in practice, and clear evidence (the worst-case bound) that larger fractions would be a real safety trade-off on a small-RAM machine. zram-generator.conf left unchanged.
<!-- SECTION:NOTES:END -->

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

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Measured zram with real evidence now that TASK-89 turned zswap off. Natural 15h usage: 769/1951 MiB swap used, 1.93x compression. Induced a bounded 1.2 GiB memory-pressure test (real file bytes, not synthetic zeros), kept available memory above 30% throughout (earlyoom warns at 10%, kills at 5% of both mem and swap) - it never got close. The device's logical capacity filled to 99.5% under that load while actual RAM used for zram peaked at only 855 MiB (22% of the 3.9 GiB machine), at a 2.11x ratio. Recovered cleanly with zero OOM kills. Conclusion: min(ram/2, 8192) is validated rather than just carried over - it bounds zram's worst-case RAM ceiling (mem_limit is unset, so an all-incompressible workload could otherwise consume up to the full disksize) at half of RAM, and the measured 1.9-2.1x ratio shows the common case uses far less than that ceiling. Sizing at 100-200% of RAM, as the task's motivating anecdote suggested, would raise that worst-case ceiling on a small-RAM machine with no evidence of benefit - the thing that actually filled under pressure was logical swap-slot capacity, which is backstopped by page-cache reclaim, not RAM. setup/system/zram-generator.conf left unchanged. checks/session.sh: 81 passed, 0 failed before and after (no regression; investigation was read-only plus a released memory allocation).
<!-- SECTION:FINAL_SUMMARY:END -->
