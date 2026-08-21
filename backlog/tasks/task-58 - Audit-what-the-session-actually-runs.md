---
id: TASK-58
title: Audit what the session actually runs
status: To Do
assignee: []
created_date: '2026-08-21 10:20'
updated_date: '2026-08-21 10:43'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
spice-vdagent investigated ahead of the rest, since it was the one named. Findings, all from the running system rather than from the manifest:

THE PACKAGE COMMENT IS WRONG. desktop.txt says the agent stops the SPICE client drawing its own pointer, "which is a second cursor on screen alongside the one sway draws". The commit that added it (3c365ae, "Add the SPICE guest agent, and rule it out as the cursor fix") says in its own message: "It was worth trying and it did not fix the ghost cursor." The comment states the theory it was tried under as though it were the outcome. The cursor was actually fixed by WLR_NO_HARDWARE_CURSORS, in the user environment and in greetd's config. Anyone reading the manifest today would conclude the agent is load-bearing for the cursor; it is not.

MOST OF WHAT IT DOES FAILS HERE. It is documented as "Spice guest agent X11 session agent" and every feature the man page lists is X11 or GNOME. On this Wayland session the journal is a wall of failures at startup: "xrandr output ID NOT FOUND", "failed to call GetCurrentState from mutter over DBUS", "card0 not found while listing DRM devices", "Unable to open file (null)", each twice. It holds zero X11 socket file descriptors and is not connected to Xwayland at all, so clipboard sharing - the main reason people install it - is not merely unused but impossible as configured.

WHAT IT DOES DO. Audio volume sync with the client, which the journal shows working: vdagent_audio_playback_sync, with per-channel levels. That is the only feature observed functioning. Whether client mouse mode works is not answerable from inside the guest: the second pointer is drawn by the SPICE client on the host, so a screenshot from here contains one cursor either way. That is the test the user has to make, and it is the only thing standing between this and removal.

AC #3 IS ANSWERED: the "harmless on real hardware" claim holds, and is now verified rather than trusted. /usr/lib/udev/rules.d/70-spice-vdagentd.rules starts spice-vdagentd.socket only on ACTION=="add" for a virtio-port whose DEVLINKS is /dev/virtio-ports/com.redhat.spice.0, and the user unit carries ConditionPathExists=/run/spice-vdagentd/spice-vdagent-sock. No virtio port means no socket, which means the condition fails and the agent never starts. So on hardware it costs a package on disk and nothing at runtime.

It is also worth recording that it is 45M resident in this VM, not the 129 KiB the commit message quotes - that figure is the package size on disk.

The user agent was stopped to test. Not yet restarted pending the pointer observation.

Confirmed by the user with the agent stopped: still one cursor, tracking normally. So nothing in this VM depended on it, and spice-vdagent is removed from packages/desktop.txt.

The lesson generalises and is now in CLAUDE.md's failure-mode section as its own named variant: a fix that did not work, kept anyway, with the hypothesis recorded as though it were the outcome. That is worse than no comment, because it reads as justification.

nm-applet remains the open item, and is the same shape - something that survived losing its reason to exist because nothing in setup/ mentions it.
<!-- SECTION:NOTES:END -->
