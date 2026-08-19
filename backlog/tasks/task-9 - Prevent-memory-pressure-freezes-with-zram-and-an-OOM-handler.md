---
id: TASK-9
title: Prevent memory-pressure freezes with zram and an OOM handler
status: To Do
assignee: []
created_date: '2026-08-19 18:15'
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
- [ ] #1 A compressed swap device is configured and active after a fresh install
- [ ] #2 A userspace OOM handler is enabled so a runaway process is killed before the desktop stops responding
- [ ] #3 A deliberate memory-stress test on a VM keeps the session interactive and kills the hog rather than freezing
- [ ] #4 Swap and OOM configuration live under setup/ and are applied by the installer, not by hand
- [ ] #5 DECISIONS.md compares zram against a disk swapfile, and compares the OOM handler options considered
<!-- AC:END -->
