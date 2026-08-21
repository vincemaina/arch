---
id: TASK-58
title: Audit what the session actually runs
status: To Do
assignee: []
created_date: '2026-08-21 10:20'
labels:
  - desktop
  - repo
dependencies:
  - TASK-14
ordinal: 56000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Nothing has ever checked the list of processes a logged-in session leaves running. It has accumulated, and at least one entry is now provably doing nothing.

WHAT A LOOK ALREADY FOUND

nm-applet, 41M resident, started by app-nm\x2dapplet@autostart.service from an XDG autostart file shipped with networkmanager. It is a system tray applet, and this bar has no tray - the systray module was removed when waybar's native network module replaced it, because a GTK tray icon cannot be themed to match the rest of the bar. So it is drawing into nothing. Nothing in setup/ starts it; it arrives with the package and autostarts itself, which is why it survived a change that removed its only reason to exist.

Others worth a look, none yet established as waste:

  * at-spi-dbus-bus and its atspi Registry - the accessibility bus, started by GTK.
  * gvfs-daemon and gvfs-metadata - from Thunar, whose future is TASK-44.
  * Two xdg-desktop-portal processes.
  * Xwayland, which is only needed while an X11 client is running.

spice-vdagent is the one the complaint named, and it is the one that turns out to be justified. It exists so the SPICE client can coordinate the pointer with the guest - without it the client draws its own cursor, which is a second cursor on screen, and that is a bug this repository has already fixed once. The package comment says it is harmless on real hardware because the daemon finds no channel and exits. That claim should be tested rather than trusted, and if it holds, spice-vdagent is right where it is until TASK-14 brings machine profiles.

WHAT THIS IS NOT

Not an exercise in shaving megabytes. The machine has zram and earlyoom and is not short of memory. It is about the same thing the rest of this repository keeps finding: something configured that does nothing, which looks deliberate and is not. A process nobody can explain is a process nobody will question when it starts misbehaving.

The useful output is a decision per entry - needed, needed only on some machines, or not needed - and a way to notice the next one. An autostart that arrives with a package is invisible in this repository today: setup/ says nothing about it, so nothing reviews it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every process a fresh session leaves running is accounted for, with a reason recorded for each
- [ ] #2 Anything established as unnecessary is stopped in a way that survives a rebuild, not just killed on this machine
- [ ] #3 The claim that spice-vdagent exits harmlessly on hardware without a SPICE channel is tested rather than taken on trust
- [ ] #4 Anything that is needed only on some machines is identified as such, so TASK-14 has a concrete list to work from rather than a hypothesis
- [ ] #5 XDG autostart files shipped by packages are visible to this repository somehow, since that is how the dead one got in and nothing would have caught it
- [ ] #6 checks/session.sh notices if a process that was decided against comes back
<!-- AC:END -->
