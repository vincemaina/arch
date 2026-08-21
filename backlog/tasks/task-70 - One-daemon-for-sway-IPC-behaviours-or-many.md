---
id: TASK-70
title: 'One daemon for sway IPC behaviours, or many?'
status: To Do
assignee: []
created_date: '2026-08-21 11:18'
labels:
  - desktop
  - repo
dependencies: []
type: spike
ordinal: 72000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two processes already sit on sway's IPC socket doing small event-driven jobs, and every feature of this kind proposed since would add a third and a fourth. Before that happens it is worth deciding whether they should be one process with a dispatch or a process each - and having somewhere that records what they all are, because at the moment that list exists only in people's heads.

THE INVENTORY

Built, and ours:

  * sway-workspace-greeter, as greeting.service. Subscribes to workspace events
    and opens a greeting terminal whenever an empty workspace is focused. Also
    checks the workspace it starts on, so it covers session start too.

Built, and not ours - same job, third-party package:

  * autotiling, as autotiling.service. Subscribes to window events and sets the
    split direction from the focused window's dimensions. Chosen over writing
    one in TASK-36. It cannot be folded into a shared daemon without
    reimplementing it, which is a real constraint on how far consolidation can
    go and is the first thing to weigh.

Discussed, would need one:

  * TASK-56, alternating between two windows and pinning one. Needs a focus
    history, so it subscribes to window::focus. Parked today precisely because
    a daemon of its own was not worth it, which is what prompted this ticket.
  * TASK-50, recovering the session after a crash or restart. To restore
    windows to workspaces something has to know the layout continuously, which
    is an IPC subscriber by another name.
  * TASK-21, handling displays automatically. Docking and undocking is an
    output event, so the reacting half is IPC; the colour temperature half is
    not, and wlsunset or gammastep already exist as packages.

Discussed, but NOT this shape - listed so they are not swept in by accident:

  * TASK-61.4, reminders before calendar events. Time-driven, not event-driven.
    A systemd timer is the right mechanism and sharing a daemon with the sway
    watchers would couple two things that have nothing in common.
  * TASK-35, hiding the bar. A keybinding and a signal to waybar, with no
    ongoing process needed.

Not candidates at all, for completeness: mako, swayidle, waybar, the polkit
agent, pipewire and wireplumber, playerctld. Established software doing its own
job, supervised as units, and nothing to do with this.

THE ACTUAL QUESTION

One process handling several subscriptions is fewer moving parts, one connection
to the socket, and one place to add the next behaviour. Against that, systemd
currently supervises each of these independently with Restart=always, so one
crashing does not take the others with it - and a shared daemon converts several
small independent failures into one large correlated one. That trade is the
decision, and it should be made on which failure mode is preferable rather than
on tidiness.

Worth settling at the same time: whether a shared daemon would be a plugin
arrangement where behaviours are separate files, or one script that grows. The
first keeps the current readability and gets the shared connection; the second
gets smaller but is the thing that becomes unmaintainable.

And whether this is worth doing at two subscribers at all. It may be that the
right answer is to write it down, keep making separate units, and revisit when
there are four.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The inventory above is kept current - anything built or proposed that watches sway IPC is listed, so this is the one place that knows
- [ ] #2 One shared daemon versus one per behaviour is decided on failure modes, not on tidiness, given systemd supervises each separately today
- [ ] #3 The fact that autotiling is a third-party package and cannot be absorbed without reimplementing it is weighed rather than ignored
- [ ] #4 Time-driven work is explicitly kept out, so reminders do not end up coupled to a window-event watcher
- [ ] #5 If the answer is 'not yet', the trigger for revisiting is stated rather than left to whoever notices
- [ ] #6 The decision is recorded in DECISIONS.md, since it governs how every future feature of this kind gets built
<!-- AC:END -->
