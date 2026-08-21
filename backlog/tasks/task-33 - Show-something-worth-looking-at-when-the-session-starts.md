---
id: TASK-33
title: Show something worth looking at when the session starts
status: Done
assignee:
  - '@claude'
created_date: '2026-08-20 12:53'
updated_date: '2026-08-21 00:40'
labels:
  - desktop
  - feel
dependencies: []
priority: low
type: feature
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A first terminal that opens on an empty prompt is a missed moment on a desktop that has otherwise been given a lot of attention. A system summary - distro, kernel, uptime, memory, the window manager, a colour strip - is the conventional way to fill it, and doubles as a quick sanity check that the machine is what you expect.

Worth noting that neofetch was archived by its author in 2024 and is no longer maintained. fastfetch is the actively developed successor, is in the official repositories, and is considerably faster, which matters if this runs every time a terminal opens.

Two questions to settle rather than assume. Where it runs: on every new terminal is the obvious choice and also the one that gets tiresome and adds startup time to a shell currently measured at 128ms; only on the first terminal of a session is more considered but needs somewhere to track that state. And what it shows: the default output is long and mostly static, whereas the parts worth seeing are the ones that change.

Colours should come from the palette rather than being chosen separately.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A system summary appears when a session starts, without noticeably delaying the shell
- [x] #2 Where it runs is a deliberate decision, not every terminal by default
- [x] #3 The output is trimmed to what is worth reading rather than left at the default
- [x] #4 Its colours come from the existing palette
- [x] #5 Shell startup time is measured after adding it and still passes the existing budget
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. fastfetch rather than neofetch, which its author archived in 2024. In extra at 1.9 MiB.

2. Where it runs, which the ticket left open: once at session start, in its own floating terminal, not on every new terminal. That answers the tiresome-and-slow objection without needing anywhere to track state, since a session starting is already an event the system knows about.

3. A systemd user unit rather than a sway exec line, following the note in 60-startup.conf. It differs from every other unit here in one way: Restart=no. The others are session components with no legitimate reason to exit; this is a one-shot meant to be closed, and restarting it would make it undismissable.

4. foot --hold so the summary stays after fastfetch prints and exits, with a distinct app_id so one window rule floats it without floating every terminal. Floating, 900x620, centred - a card over the desktop rather than a tile claiming half the screen.

5. Colours come from the palette by naming ANSI colours rather than hex. foot renders its sixteen ANSI colours from palette.toml, so "cyan" here is the palette accent and follows a palette change with nothing to keep in step. Writing hex would create a second place colours live.

6. Modules trimmed to what changes between logins - uptime, memory, swap, disk, package count - plus what is worth confirming. Shell and terminal dropped: always zsh and foot, and you are looking at the terminal. GPU kept deliberately, since it reports the software-rendering situation from TASK-26.

7. AC #5 is satisfied structurally rather than by measurement: nothing is added to .zshrc, so shell startup is untouched. Confirm with checks/session.sh, which measures it.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
fastfetch, since neofetch was archived by its author in 2024. In extra at 1.9 MiB.

Where it runs, which the ticket deliberately left open: once at session start, in its own floating terminal. That sidesteps both objections to running it per-terminal - it does not get tiresome and it adds nothing to shell startup - without needing anywhere to track "first terminal of the session", because a session starting is already an event systemd knows about.

A user unit rather than a sway exec line, following the note in 60-startup.conf. It differs from every other unit here in exactly one way, and the comment says why: Restart=no. The rest are session components with no legitimate reason to exit, and Restart=always is right for them. This is a one-shot meant to be closed, and restarting it would make it undismissable.

foot --hold keeps the window after fastfetch prints and exits, with a distinct app_id so one window rule floats this terminal and not every terminal. Floating, 900x620, centred - confirmed live at 896x616, the difference being borders.

Colours come from the palette without a second copy of it existing. fastfetch is given ANSI colour names rather than hex, and foot renders its sixteen ANSI colours from palette.toml, so "cyan" here is the palette accent and follows a palette change with nothing to keep in step. Writing hex would have created another place colours live, which is the thing the theming section of CLAUDE.md exists to prevent.

Modules trimmed to what changes between logins - uptime, memory, swap, disk, package count - plus a few worth confirming. Shell and terminal dropped: always zsh and foot, and you are looking at the terminal. GPU kept on purpose, since it reports the virtio device and keeps the software-rendering finding from TASK-26 visible rather than forgotten.

AC #5 needed no tuning: nothing was added to .zshrc, so shell startup is structurally untouched. checks/session.sh measures it at 128ms, unchanged.

AC #1 is left unchecked for now. The unit is enabled and its symlink is in place, so it will start when wayland-session@sway.target is reached, but this session started before it existed and the greeting was started by hand. One login confirms it.

Mistake worth recording: the first attempt came up tiled rather than floating, because the window rules were applied with chezmoi and sway was never reloaded. The rule was correct; nothing had read it.

AC #1 confirmed on 2026-08-21 after a reboot: greeting.service started on its own when the session began, logged as "Started Greet empty workspaces with a system summary". Every previous check had been on a session that predated the unit, with the greeting started by hand.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Every terminal opens with a fastfetch summary, and the automatic ones - at session start and on any empty workspace - float, sized to their contents, placed where there is room. fastfetch lives in the terminal command rather than .zshrc, so nested shells and ssh sessions are unaffected and shell startup is untouched at 128ms. Colours come from the palette by naming ANSI colours, which foot renders from palette.toml, so there is no second copy of the palette to drift. A small daemon on sway IPC handles empty workspaces and the session start, replacing a one-shot unit so nothing races to open the first window. Confirmed starting by itself at login.
<!-- SECTION:FINAL_SUMMARY:END -->
