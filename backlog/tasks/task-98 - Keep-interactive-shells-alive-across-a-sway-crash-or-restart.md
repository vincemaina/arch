---
id: TASK-98
title: Keep interactive shells alive across a sway crash or restart
status: To Do
assignee: []
created_date: '2026-08-22 00:57'
labels:
  - desktop
  - foundation
dependencies:
  - TASK-50
priority: low
ordinal: 100000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-50 (spike) concluded that shells are the one piece of session state worth
persisting across a sway crash or an in-session restart, and that abduco
(36.75 KiB, official extra repo) is the right tool: it only does
detach/reattach, with no panes/tabs/prefix-key surface to reconcile against
the existing Ctrl-heavy scheme (readline emacs bindings, fzf) the way tmux or
zellij would need.

The design constraint is concrete, not speculative - verified against the
actual TASK-48 crash log. systemd --user (the per-user manager) survives a
sway crash intact; but a process launched the ordinary way, via a sway `exec`
line or nested under wayland-wm@sway.service's own cgroup, does not - the log
shows systemd SIGKILLing a process in that cgroup ~10 seconds after the
crash, as normal unit-stop cleanup. So the abduco daemon holding each shell's
pty must run as its own systemd --user unit, independent of
wayland-session@sway.target (no PartOf/BindsTo on it), the mirror image of
how mako/waybar/swayidle are deliberately bound to that target.

Scope is a sway crash or a deliberate in-session restart (logout/relogin
without power-cycling), not a full machine reboot - no userspace process
survives that.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Opening a terminal attaches to (or creates) a per-shell abduco session, rather than a bare shell
- [ ] #2 The abduco daemon for each shell runs as its own systemd --user unit with no PartOf/BindsTo on wayland-session@sway.target, confirmed by inspecting its cgroup rather than assumed
- [ ] #3 Killing sway (swaymsg exit, or simulating a crash) leaves the abduco-held shells running, verified by reattaching after sway restarts and finding the shell mid-state
- [ ] #4 A normally-closed terminal does not leave an orphaned abduco session behind - the detach/exit distinction is deliberate, not a side effect
- [ ] #5 abduco is declared in packages/desktop.txt and reaches both a fresh install and sync.sh
- [ ] #6 The detach keybinding is confirmed against tools/shortcuts.sh and dot_zshrc to collide with nothing (readline emacs bindings, fzf Ctrl+R/Ctrl+T)
- [ ] #7 The decision and design are recorded in DECISIONS.md
<!-- AC:END -->
