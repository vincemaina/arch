---
id: TASK-95
title: at-spi2-registryd is left behind by every login and accumulates until reboot
status: To Do
assignee: []
created_date: '2026-08-21 21:12'
labels:
  - desktop
dependencies:
  - TASK-58
ordinal: 97000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Three at-spi2-registryd processes are running on the reference VM. There have been three graphical logins since boot, and the three processes started at 10:58, 12:57 and 16:10 - one per login, to the second.

The two older ones are orphans, and that is checkable rather than assumed. Each was activated by a session-bus connection (:1.15, :1.231) and 'busctl --user status :1.15' now reports 'No such device or address' - the client that asked for them is gone. Only one at-spi-bus-launcher is running, the current session's. So the older registryds are holding a connection to an accessibility bus that no longer exists.

WHY IT HAPPENS. The registry is D-Bus activated into a transient unit under app.slice. app.slice is not bound to wayland-session@sway.target, so ending the graphical session does not stop it. This repository's own components are bound correctly - that is the rule CLAUDE.md states - but a D-Bus activation from a package obeys the package's own arrangement, not ours.

WHAT IT COSTS, honestly. About 6.2 MiB RSS each but under 0.5 MiB PSS: they are almost entirely shared library pages. So this is a process leak rather than a memory one, and the description of TASK-58 already says the point is not shaving megabytes. It is that the count grows with every login and nobody can explain it.

WHAT STARTS IT AT ALL. at-spi2-core is not declared in setup/packages/ - it arrives as a dependency of GTK - and its /etc/xdg/autostart entry is correctly skipped (OnlyShowIn=GNOME;Unity). It comes up by D-Bus activation from the GTK applications in this session: waybar, polkit-gnome, xdg-desktop-portal-gtk, and nm-applet until TASK-92 removes it. Nothing here uses a screen reader.

Two directions worth weighing, neither yet tested: suppress the atk bridge in the session environment so GTK never asks for the a11y bus at all, or leave it and accept the leak. The first is a one-line environment.d change and is easy to get wrong - GTK3 and GTK4 read different variables - and a change that fails to suppress it looks identical to one that works unless the check is done properly. Prove the mechanism in the positive direction before trusting a negative result.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Whether GTK can be stopped from starting the accessibility bus in this session is answered by test, not by documentation
- [ ] #2 If it can, the change is in setup/ so a rebuild reproduces it, and a fresh login shows no at-spi process at all
- [ ] #3 If it cannot, or the cost is judged not worth it, that is written down where the next reader will look rather than left as an open question
- [ ] #4 Either way, tools/session-inventory.sh no longer reports session-scoped processes outliving their session on a machine that has logged in three times
<!-- AC:END -->
