---
id: TASK-93
title: Make XDG autostart entries visible to this repository
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 21:11'
updated_date: '2026-08-22 00:45'
labels:
  - desktop
  - repo
dependencies:
  - TASK-58
ordinal: 95000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Nothing in setup/ has ever read /etc/xdg/autostart, and that directory is how a package starts a process in this session without the repository saying so. uwsm reaches xdg-desktop-autostart.target through wayland-session-xdg-autostart@sway.target, so every entry there that survives its OnlyShowIn/NotShowIn filter becomes a running process at login.

Today there are three, established by reading the files and asking systemd what it generated:

  * nm-applet.desktop (network-manager-applet) - generated app-nm\\x2dapplet@autostart.service, active, and pointless. See TASK-92.
  * xdg-user-dirs.desktop (xdg-user-dirs) - runs xdg-user-dirs-update, a oneshot that exits. Zero runtime cost, and the package is declared for exactly this.
  * at-spi-dbus-bus.desktop (at-spi2-core) - correctly SKIPPED, because it is OnlyShowIn=GNOME;Unity and XDG_CURRENT_DESKTOP is sway. It still ends up running, by D-Bus activation from GTK, which is a different route and a different question.

The number is small and the point is that it can change without anyone noticing: a package update can add an entry, and a package added for one reason can bring an autostart entry for another. tools/session-inventory.sh now reports the directory, but a report only helps someone who runs it.

What is wanted is a check that fails when the set of entries that will actually start is not the set this repository has acknowledged - the same shape as the desktop-entry and session-unit checks already in checks/session.sh. That means a list somewhere in setup/ of the entries that are known and accepted, so a new one is a failure rather than a surprise.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 checks/session.sh fails when an XDG autostart entry that will start under sway is not one this repository has acknowledged
- [x] #2 The acknowledged set lives in setup/, so a fresh machine inherits it
- [x] #3 The check honours OnlyShowIn/NotShowIn against XDG_CURRENT_DESKTOP, so an entry that is present and correctly skipped does not fail it
- [x] #4 Adding a package that ships an autostart entry makes the check fail, demonstrated rather than argued
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Read how the real generator decides: run /usr/lib/systemd/user-generators/systemd-xdg-autostart-generator into a temp dir and read the units it emits.
2. Add setup/system/xdg-autostart.txt - the acknowledged set, one .desktop basename per line, comments carrying why each is accepted. It ships in setup/ so a fresh machine inherits it; apply-config.sh deliberately does not install it anywhere.
3. Add an 'XDG autostart' section to checks/session.sh that runs the real generator against the user manager's XDG_CONFIG_HOME/XDG_CONFIG_DIRS, evaluates each generated unit's ExecCondition (systemd-xdg-autostart-condition, the same binary systemd runs) against the manager's XDG_CURRENT_DESKTOP, and fails when an entry that will start is not acknowledged, or an acknowledged entry has vanished.
4. Demonstrate it red: drop a .desktop into ~/.config/autostart (a directory the generator genuinely scans, and writable without root), confirm FAIL; add an OnlyShowIn=GNOME one and confirm it does NOT fail; remove both and confirm green again.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Mechanism: the check does not re-implement the generator's rules, it runs them. checks/session.sh runs /usr/lib/systemd/user-generators/systemd-xdg-autostart-generator into a mktemp directory with the USER MANAGER's XDG_CONFIG_HOME / XDG_CONFIG_DIRS / XDG_CURRENT_DESKTOP (taken from 'systemctl --user show-environment', not the shell - they differ here: XDG_CURRENT_DESKTOP is 'sway:wlroots' in a terminal and 'sway' in the manager, and the latter is what a show-in filter is matched against). Every unit it emits carries SourcePath= and, for OnlyShowIn/NotShowIn, ExecCondition=/usr/lib/systemd/systemd-xdg-autostart-condition; the check executes that condition and reads its exit status. So Hidden, X-systemd-skip, TryExec, X-GNOME-Autostart-Phase and the show-in filters are all honoured by construction rather than by a second copy of the rules that could drift.

Finding worth recording: TASK-93's description says nm-applet, xdg-user-dirs and at-spi are the three entries. nm-applet.desktop is already gone (TASK-92), and BOTH survivors now carry X-systemd-skip=true, so systemd generates no unit for either - confirmed by running the generator with SYSTEMD_LOG_LEVEL=debug ('not generating unit, marked as skipped by generator'). xdg-user-dirs-update still runs, but from xdg-user-dirs.service, a user unit the package ships and enables, not from the autostart entry. Nothing in /etc/xdg/autostart starts anything on this machine today.

Evidence (all four directions run, output pasted from the terminal):

  * baseline, both real entries present and inert:
      PASS at-spi-dbus-bus.desktop (from at-spi2-core) is present but does not start: X-systemd-skip=true (acknowledged)
      PASS xdg-user-dirs.desktop (from xdg-user-dirs) is present but does not start: X-systemd-skip=true (acknowledged)
    80 passed, 0 failed, 0 skipped; exit 0.

  * AC4 - red. Dropped zz-check-demo.desktop (Exec=/usr/bin/true) into ~/.config/autostart, a directory the generator genuinely scans (its own debug output lists it first) and one that needs no root:
      FAIL zz-check-demo.desktop will start under sway - running '/usr/bin/true' - and setup/system/xdg-autostart.txt does not acknowledge it
    81 passed, 1 failed; './checks/session.sh; echo $?' printed 1.

  * AC3 - a present-but-skipped entry does not fail it. zz-check-demo-gnome.desktop with OnlyShowIn=GNOME;Unity; in the same directory:
      PASS zz-check-demo-gnome.desktop is present but does not start: OnlyShowIn=GNOME;Unity; does not match XDG_CURRENT_DESKTOP=sway (not acknowledged, and does not need to be)
    That verdict comes from actually running systemd-xdg-autostart-condition, which exits 1 for it and 0 for the plain entry.

  * green again on acknowledgement: adding the line to setup/system/xdg-autostart.txt turned the FAIL into
      PASS zz-check-demo.desktop starts under sway, and is acknowledged

  * the other drift direction: deleting the file while the acknowledgement stayed gave
      FAIL zz-check-demo.desktop is acknowledged in setup/system/xdg-autostart.txt but no autostart directory contains it any more

  Both demo files and the ~/.config/autostart directory (which did not exist before) were removed; the manifest line was removed; the check is back to 80 passed, 0 failed, 0 skipped, exit 0.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
checks/session.sh gained an 'XDG autostart (TASK-93)' section that fails when a .desktop file which will actually start under sway is not listed in the new setup/system/xdg-autostart.txt. The verdict is taken from the real implementations - the systemd-xdg-autostart-generator is run into a temp directory with the user manager's XDG_CONFIG_HOME/XDG_CONFIG_DIRS/XDG_CURRENT_DESKTOP, and each generated unit's own ExecCondition (systemd-xdg-autostart-condition) is executed - so Hidden, X-systemd-skip, TryExec, the GNOME phase key and OnlyShowIn/NotShowIn are honoured without re-implementing them. The manifest lives under setup/system/ (machine-wide session state, and setup/ is what a fresh machine inherits; setup/packages/ was impossible because both install paths glob *.txt there as package lists) and is deliberately not mapped in apply-config.sh. Verified by breaking it on purpose: a plain entry dropped into ~/.config/autostart made the check exit 1, acknowledging it turned it green, deleting an acknowledged entry failed the other way, and an OnlyShowIn=GNOME entry in the same directory correctly did not fail it. Back to 80 passed, 0 failed, 0 skipped after cleanup.
<!-- SECTION:FINAL_SUMMARY:END -->
