---
id: TASK-9
title: Prevent memory-pressure freezes with zram and an OOM handler
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-19 18:15'
updated_date: '2026-08-19 21:03'
labels:
  - foundation
  - performance
dependencies: []
references:
  - 'https://wiki.archlinux.org/title/Zram'
  - 'https://wiki.archlinux.org/title/Systemd#systemd-oomd'
priority: high
type: feature
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The install creates no swap of any kind: 01-disk.sh makes only an ESP and a Btrfs root, and nothing configures zram. Under memory pressure Linux will thrash and the desktop locks up long before the kernel OOM killer intervenes. This is the most likely cause of the whole-system freezes we want to eliminate, and it also affects how much headroom the 550-650 MiB idle footprint really has.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A compressed swap device is configured and active after a fresh install
- [x] #2 A userspace OOM handler is enabled so a runaway process is killed before the desktop stops responding
- [ ] #3 A deliberate memory-stress test on a VM keeps the session interactive and kills the hog rather than freezing
- [x] #4 Swap and OOM configuration live under setup/ and are applied by the installer, not by hand
- [x] #5 DECISIONS.md compares zram against a disk swapfile, and compares the OOM handler options considered
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add zram-generator and earlyoom to base.txt. Memory pressure handling is not desktop-specific, so it belongs in the base system rather than the desktop manifest.
2. Size zram as min(ram / 2, 8192) so it scales: 8 GB on the 16 GB machine, half of whatever a small VM has. Never a fixed figure, since the same repository has to work on both.
3. Compress with zstd and give the device swap-priority 100 so it is always preferred over any disk swap added later.
4. Add the two sysctl settings that matter for a zram-only system: swappiness raised well above the disk-swap default because compressed swap is cheap, and page-cluster set to 0 because reading ahead makes no sense without seek costs.
5. Configure earlyoom with explicit thresholds rather than relying on its defaults, and with avoid and prefer lists so the session survives and the browser is what gets killed.
6. Install all three config files from setup/system/ in 03-system.sh and enable earlyoom there. zram-generator needs no enabling; it is a generator that reads its config at boot.
7. Record in DECISIONS.md why zram over a disk swapfile, why earlyoom over systemd-oomd, and how earlyoom requiring both memory and swap to be low interacts with zram being near-full as a matter of course.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added zram-generator and earlyoom to base.txt, with config in setup/system/ installed by 03-system.sh: zram-generator.conf, sysctl.d/99-zram.conf and earlyoom.conf. zram-generator needs no enabling since it is a generator; earlyoom is enabled in the same step.

zram is sized min(ram / 2, 8192) so it scales from a small VM to the 16 GB machine, with zstd and swap-priority 100 so it stays preferred if a disk swapfile is ever added. Accompanying sysctls raise swappiness, since the default assumes swapping means touching a disk, and set page-cluster to 0, since swap read-ahead only exists to amortise seeks.

Two bugs found and fixed while writing the earlyoom config, both of which would have failed silently:

First, earlyoom.service is ExecStart=...earlyoom $EARLYOOM_ARGS with no shell. systemd splits that on whitespace but does not remove quotes, so the single-quoted regexes in upstream own example file would have reached earlyoom with literal quote characters in the pattern and never matched anything. The regexes contain no whitespace, so they are now unquoted and survive the split intact.

Second, --avoid and --prefer match comm, which is the first 15 bytes of the process name and contains no path. Upstream example anchors with (^|/), which is meaningless against comm. Patterns are now plainly anchored and every name checked to fit within 15 characters.

Verified: 03-system.sh passes bash -n; zram sizing computed across 1-32 GB showing half of RAM up to the 8 GB cap; EARLYOOM_ARGS split into the exact 10-argument vector systemd will produce; and both regexes checked against every name they are meant to match plus near-misses like swaybg and node_modules, which correctly do not match.

AC #3 needs the VM: whether a deliberate memory hog actually gets killed with the session staying interactive.

Verified on the VM after sync applied the system configuration: zram active as swap at 1.9G with zstd, which is min(ram / 2, 8192) on that machine and confirms the sizing expression scales rather than being pinned to the 16 GB target. vm.swappiness 180 and vm.page-cluster 0 both applied. earlyoom running.

The check initially reported earlyoom running without its avoid/prefer patterns. That was a defect in the check, not the configuration: systemctl show --property=ExecStart reports the command line as written in the unit, where the arguments are still the literal string $EARLYOOM_ARGS, so the patterns could never appear there. Fixed to inspect the running process instead.
<!-- SECTION:NOTES:END -->
