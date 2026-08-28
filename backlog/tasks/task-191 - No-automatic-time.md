---
id: TASK-191
title: No automatic time
status: Done
assignee:
  - '@claude'
created_date: '2026-08-28 15:57'
updated_date: '2026-08-28 20:09'
labels: []
dependencies: []
priority: medium
type: bug
ordinal: 197000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
It seems if the PC loses power for a while, the time doesn't remain up to date with reality when it turns back on.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 systemd-timesyncd is enabled by both install paths (apply-config.sh), so a fresh install and a synced machine both get it
- [x] #2 The running machine reports 'System clock synchronized: yes' and an active NTP service
- [x] #3 checks/session.sh fails when NTP is not enabled, not synchronised, or the timezone disagrees with install.conf
- [x] #4 No package is added to setup/packages/ - timesyncd ships with systemd
- [x] #5 DECISIONS.md records why timesyncd rather than chrony or ntpd
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Root cause: nothing on this system runs an NTP client. timedatectl reports 'System clock synchronized: no' and 'NTP service: inactive'; systemd-timesyncd.service is present (systemd ships it) but disabled. 03-system.sh sets the timezone and runs hwclock --systohc once at install, then nothing ever corrects the clock again - so the RTC drifts while the machine is off and boots with whatever it drifted to.
2. Enable systemd-timesyncd from setup/system/apply-config.sh (ENABLE_UNITS), the single source of truth both install paths call, so it reaches a fresh install and a running machine alike. No package: timesyncd is part of systemd. No timesyncd.conf: Arch compiles the arch NTP pool in as FallbackNTP.
3. Start it in the --activate block, alongside the other units that own no session, so sync.sh corrects the clock now rather than at next boot.
4. Timezone stays as it is - install.conf already pins TIMEZONE=Europe/London and 03-system.sh symlinks /etc/localtime from it. BST/GMT is handled by the zoneinfo database, so nothing seasonal is needed.
5. Add a checks/session.sh section: NTP enabled, clock synchronised, and /etc/localtime agreeing with install.conf's TIMEZONE.
6. Record the choice in DECISIONS.md (timesyncd over chrony/ntpd) and update the manual if it asserts anything about the clock.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause confirmed on the reference machine, not inferred: timedatectl reported 'System clock synchronized: no' and 'NTP service: inactive'. systemd-timesyncd.service was present (systemd ships it) but disabled, preset enabled - so nothing had ever turned it on. 03-system.sh's 'hwclock --systohc' writes system time TO the RTC once at install and never reads it back, which is why the drift accumulated unattended.

The drift was measured, and it was large. journalctl -u systemd-timesyncd shows the unit starting at 19:29:34 on the old clock and the very next line - 'Initial clock synchronization' - reading 21:07:25. That 1h37m51s gap IS the accumulated error the bug report described.

Implementation: one unit name in ENABLE_UNITS in setup/system/apply-config.sh, plus a systemctl start in the --activate block. No package (timesyncd is part of systemd) and no config file (Arch compiles 0..3.arch.pool.ntp.org in as FallbackNTP, which is what the stock empty [Time] section resolves to). Verified the compiled fallback with 'systemd-analyze cat-config systemd/timesyncd.conf' rather than assuming it.

The timezone needed no work: install.conf already pins TIMEZONE=Europe/London and zoneinfo owns the BST/GMT transition, so a fixed timezone over a synced UTC clock is correct all year with nothing seasonal to maintain. Geolocation was rejected in DECISIONS.md - a network dependency and a privacy question bought to answer a question whose answer never changes.

The check was written to fail first. Run against the unfixed machine it produced three FAILs (not enabled, NTP inactive, not synchronised); after apply-config.sh --activate the same five assertions all pass. It also asserts the RTC holds UTC, since a hardware clock in local time turns each seasonal change into an hour of boot-time error - the same symptom surviving the fix. That one already passed, but nothing was watching it.

The synchronised assertion is deliberately a skip rather than a fail when uptime is under two minutes, because a machine that has just booted legitimately reports 'no' for a few seconds while the first exchange happens.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Enabled systemd-timesyncd, so the clock stays right instead of being set once at install and left to drift.

Nothing on this system had ever run an NTP client. 03-system.sh set the timezone and ran 'hwclock --systohc' - which writes system time to the RTC and never reads it back - and that was the whole of the clock story, so the hardware clock drifted freely whenever the machine was off and the system booted with whatever it had drifted to. The reference machine was 1h38m slow when this was investigated.

The fix is one unit name in ENABLE_UNITS in setup/system/apply-config.sh, the single source both install paths call, plus a systemctl start in the --activate block so sync.sh corrects the clock now rather than at next boot. It costs no package (timesyncd is part of systemd) and no configuration (Arch compiles the Arch NTP pool in as FallbackNTP). The timezone is left as it is: install.conf already pins Europe/London and zoneinfo owns the BST/GMT transition, so nothing seasonal needs maintaining and no geolocation is involved.

Verified live, not by inspection. Before: timedatectl 'System clock synchronized: no', 'NTP service: inactive', and the new checks/session.sh section producing three FAILs. After apply-config.sh --activate: 'System clock synchronized: yes', 'NTP service: active', journalctl showing 'Contacted time server 178.62.68.79:123 (0.arch.pool.ntp.org)' and an initial synchronisation that jumped the clock forward by 1h37m51s. checks/session.sh 138 passed, 0 failed, 2 skipped; checks/manual.sh 8 passed; sway-commands and sway-bindings clean. checks/packages.sh reports 3 failures for hand-installed openrgb, steam and vulkan-tools - identical on main before this change and unrelated to it.

Also added: a Clock section to checks/session.sh (enabled, active, synchronised, timezone matches install.conf, RTC holds UTC), a DECISIONS.md entry recording timesyncd over chrony/ntpd and why the timezone is fixed rather than detected, and updates to the manual's chapter 7 unit and --activate lists.
<!-- SECTION:FINAL_SUMMARY:END -->
