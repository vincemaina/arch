---
id: TASK-11
title: 'Start the desktop session reproducibly (waybar, notifications, idle)'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-19 18:15'
updated_date: '2026-08-19 19:22'
labels:
  - foundation
  - session
dependencies:
  - TASK-17
references:
  - 'https://wiki.archlinux.org/title/Universal_Wayland_Session_Manager'
priority: high
type: bug
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Waybar is never launched by anything in the repository. The only exec line in the sway config is swayidle at line 36, the bar block is commented out at lines 229-241, and no exec waybar exists anywhere under setup/. Confirmed with the user: on the reference VM Waybar is started by hand after logging in, so the committed configuration does not reproduce the desktop that is actually in use, and a fresh install comes up with no bar at all.

Rather than patching in an exec line, decide how the session should be supervised: plain exec entries, sway-systemd, or uwsm, which wraps a compositor in systemd units and provides a real graphical-session.target that waybar, mako and swayidle can order against, with restart-on-failure and clean shutdown. The same mechanism should own every session component, so this is the last time a piece of the desktop is started by hand.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A fresh install reaches a complete desktop - bar, notifications and idle handling - with no manual startup step
- [ ] #2 A crashed bar or notification daemon is restarted automatically rather than leaving the session degraded
- [x] #3 Session components are declared in one obvious place under setup/
- [x] #4 DECISIONS.md records the comparison between plain exec, sway-systemd and uwsm, and why the chosen option won
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Adopt uwsm, chosen by the user over plain exec lines and hand-rolled units. It is in the official extra repository, so no AUR support is needed, and it starts a real graphical-session.target.
2. Add uwsm to desktop.txt and change the documented launch from sway to uwsm start -- sway. Automatic launch on login stays with TASK-15.
3. Waybar already ships usr/lib/systemd/user/waybar.service with Restart=on-failure and WantedBy=graphical-session.target, so it needs enabling rather than writing.
4. Write matching user units for mako and swayidle in the dotfiles, following the same PartOf/After/Requisite=graphical-session.target pattern so the whole session stops and starts as one unit.
5. Enable everything declaratively with chezmoi-managed symlinks in graphical-session.target.wants, rather than running systemctl --user enable from inside the chroot where there is no user session to talk to.
6. Move the swayidle invocation out of the sway config into a small script under ~/.local/bin, and have the unit call that. systemd ExecStart quoting cannot be verified in this container, but a shell script can be, and the idle policy becomes easier to tune later.
7. Leave a clear note that components only start when the session is launched through uwsm, since a plain sway launch will not reach graphical-session.target.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented with uwsm. Added uwsm to desktop.txt; documented launch is now uwsm start -- sway.

Waybar needed no unit written - the package ships usr/lib/systemd/user/waybar.service with Restart=on-failure and WantedBy=graphical-session.target - so it is only enabled. mako and swayidle got units following the same PartOf/After/Requisite=graphical-session.target pattern, so the session starts, restarts and stops as a whole.

Units are enabled by committed symlinks in graphical-session.target.wants rather than systemctl --user enable, which cannot run in the installer chroot with no user session. Relative targets for our own units, absolute for the package-supplied waybar one.

The swayidle invocation moved out of the sway config into ~/.local/bin/sway-idle. systemd ExecStart quoting cannot be verified in this container but a shell script can be: running the script against a stub swayidle confirmed the exact 11-argument vector, matching the original inline command including the nested quoting in the power off and resume commands.

60-startup.conf is now deliberately empty, kept as a signpost saying components are units and warning that a plain sway launch reaches no session target so nothing starts.

Verified: sway directive comparison before and after shows the swayidle exec as the only removal and nothing else changed; symlink targets and unit ExecStart paths checked; sway-idle passes bash -n.

AC #1 and #2 need the VM: whether a fresh session brings everything up, and whether killing waybar or mako actually gets them restarted.
<!-- SECTION:NOTES:END -->
