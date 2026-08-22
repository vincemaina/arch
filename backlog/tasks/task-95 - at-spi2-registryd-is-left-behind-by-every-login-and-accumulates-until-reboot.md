---
id: TASK-95
title: at-spi2-registryd is left behind by every login and accumulates until reboot
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 21:12'
updated_date: '2026-08-22 17:51'
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
- [x] #1 Whether GTK can be stopped from starting the accessibility bus in this session is answered by test, not by documentation
- [x] #2 If it can, the change is in setup/ so a rebuild reproduces it, and a fresh login shows no at-spi process at all
- [ ] #3 If it cannot, or the cost is judged not worth it, that is written down where the next reader will look rather than left as an open question
- [x] #4 Either way, tools/session-inventory.sh no longer reports session-scoped processes outliving their session on a machine that has logged in three times
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Build a harness that can OBSERVE at-spi activation: monitor the session bus for org.a11y.Bus GetAddress calls (the actual activation trigger) and the a11y bus for client connect/disconnect, around one command.
2. Prove the harness positive-direction first with an unsuppressed GTK application, and take an idle control.
3. Test GTK3 and GTK4 separately, each with nothing set, NO_AT_BRIDGE=1, GTK_A11Y=none, and both.
4. Use a real GTK4 window on the real Wayland display (started SIGSTOPped, sent to scratchpad by a runtime for_window [pid=N] rule, then continued) so nothing appears on the user's screen.
5. Also test Qt6, since qutebrowser is the declared browser and Qt has its own bridge.
6. Write the winning combination to setup/dotfiles/dot_config/environment.d/, with the measurement table in the comment.
7. Confirm through the user manager environment (daemon-reload + systemd-run), which is the closest thing to a fresh login available without logging out.
8. Update tools/session-inventory.sh so it reports whether the suppression is actually in this session, not just how many registryds are running.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
MEASURED, not read off documentation. Harness: 'busctl --user monitor org.a11y.Bus' catches the GetAddress call that activates at-spi-bus-launcher, and 'busctl --address=unix:path=/run/user/1000/at-spi/bus_0 monitor' catches the resulting connection to the a11y bus. Idle control gives 0/0; an unsuppressed GTK3 program gives 1 GetAddress and 3 a11y-bus events, so the harness demonstrably sees the thing before any negative result is trusted.

                     GTK3 (gtk-query-settings)   GTK4 (mapped window)   Qt6 (mapped window)
  nothing set        asks                        asks                   silent
  NO_AT_BRIDGE=1     silent                      STILL ASKS             -
  GTK_A11Y=none      STILL ASKS                  silent                 -
  both               silent                      silent                 -

So the ticket's warning was exactly right and each variable alone is a half fix that looks like a whole one. Both are needed.

TWO HARNESS TRAPS worth recording, both of which produced a clean-looking false negative:
  * gtk4-query-settings opens the display and calls gtk_init, and still never asks - GTK4 only sets up at-spi once it maps a window. Testing GTK4 with a windowless program reports 'suppressed' for a setting that is doing nothing.
  * GTK4 under GDK_BACKEND=broadway never asks either, with a real window. The a11y backend is display-backend dependent, so the off-screen shortcut was not a valid stand-in for the real Wayland display.
The real GTK4 test was run on the real Wayland display without disturbing the user: start it SIGSTOPped, add a runtime 'for_window [pid=N] move scratchpad', then SIGCONT. Window confirmed mapped (pid found in get_tree) and never visible.

Qt6 was checked because qutebrowser is the declared browser. A mapped PyQt6 window triggers nothing at all, so no Qt variable is being added on speculation.

CHANGE. setup/dotfiles/dot_config/environment.d/20-accessibility.conf sets NO_AT_BRIDGE=1 and GTK_A11Y=none, with the measurement table above in the comment so the next reader does not delete half of it as redundant. Applied with 'chezmoi apply' for that one path only, so no run_onchange script ran.

tools/session-inventory.sh: the 'Left behind' at-spi block now reports both halves - how many registryds are running AND whether the two variables are actually in this session's user-manager environment. Without the second half a machine that has not logged in since the change looks unfixed and a machine where the variables never arrived looks fixed. Both branches were exercised by moving the conf aside and running daemon-reload, not assumed. The block's 'grep -q' in a pipefail pipeline was replaced with 'grep -c' at the same time (scripting-traps).

VERIFIED SO FAR, without logging out: after 'systemctl --user daemon-reload' the user manager carries both variables, and a GTK3 program started through 'systemd-run --user' - i.e. with the environment a fresh login's units get - makes no GetAddress call, while the same program run from this pre-existing shell still does. That is the mechanism working end to end through environment.d.

STILL UNVERIFIED, and it belongs to the next login/reboot: that a fresh session shows NO at-spi process at all. The three registryds on this machine predate the change and only a reboot removes them, so AC2's second half and AC4 cannot be observed from here. checks/session.sh: 80 passed, 0 failed, 0 skipped.

Verified after a real reboot and fresh login (machine booted 2026-08-22 11:21, this session's user-manager environment carries NO_AT_BRIDGE=1 and GTK_A11Y=none): zero at-spi2-registryd processes running (ps aux has none, and pgrep's earlier hit was matching its own command line, not a real process). tools/session-inventory.sh's 'Left behind' section reports 'nothing left behind' - no orphaned registryds, confirming AC4. This is the first login since the suppression landed, and it shows no at-spi process at all, confirming AC2's second half.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @claude
created: 2026-08-22 00:51
---
AC2 and AC4 are deliberately left unchecked: their evidence is a fresh login and a reboot, which could not be performed while the user was working in this session. AC3's condition did not arise - the bridge can be suppressed, so nothing had to be written down as a refusal. Ready to close once the next login shows no at-spi2-registryd.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
GTK's accessibility-bus request is suppressed session-wide via setup/dotfiles/dot_config/environment.d/20-accessibility.conf (NO_AT_BRIDGE=1 + GTK_A11Y=none, both required - each alone is a half fix, measured against GTK3/GTK4/Qt6). Verified end-to-end on a fresh boot: zero at-spi2-registryd processes, and tools/session-inventory.sh confirms nothing left behind. Nothing here uses a screen reader, so the suppression is accepted with no loss.
<!-- SECTION:FINAL_SUMMARY:END -->
