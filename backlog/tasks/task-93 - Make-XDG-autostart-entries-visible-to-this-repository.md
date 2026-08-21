---
id: TASK-93
title: Make XDG autostart entries visible to this repository
status: To Do
assignee: []
created_date: '2026-08-21 21:11'
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
- [ ] #1 checks/session.sh fails when an XDG autostart entry that will start under sway is not one this repository has acknowledged
- [ ] #2 The acknowledged set lives in setup/, so a fresh machine inherits it
- [ ] #3 The check honours OnlyShowIn/NotShowIn against XDG_CURRENT_DESKTOP, so an entry that is present and correctly skipped does not fail it
- [ ] #4 Adding a package that ships an autostart entry makes the check fail, demonstrated rather than argued
<!-- AC:END -->
